import Foundation
import Combine

/// Gestor principal de conexión con el backend PocketBase (rutinas, fotos/vídeos de progreso y autenticación de usuarios).
@MainActor
public final class PocketBaseManager: ObservableObject {
    @Published public var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "pocketbase_server_url")
        }
    }
    @Published public var authToken: String? {
        didSet {
            if let token = authToken {
                UserDefaults.standard.set(token, forKey: "pocketbase_auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "pocketbase_auth_token")
            }
        }
    }
    @Published public var currentUser: GymUser? {
        didSet {
            if let user = currentUser, let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: "pocketbase_user_data")
            } else {
                UserDefaults.standard.removeObject(forKey: "pocketbase_user_data")
            }
        }
    }
    
    @Published public var activeRoutine: GymRoutine?
    @Published public var routineDays: [GymRoutineDay] = []
    @Published public var completedDayIds: Set<String> = []
    @Published public var progressUploads: [GymProgressUpload] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    public var isLoggedIn: Bool {
        return authToken != nil && currentUser != nil
    }
    
    public init() {
        let savedURL = UserDefaults.standard.string(forKey: "pocketbase_server_url") ?? "http://127.0.0.1:8090"
        let savedToken = UserDefaults.standard.string(forKey: "pocketbase_auth_token")
        
        self.serverURL = savedURL
        self.authToken = savedToken
        
        if let userData = UserDefaults.standard.data(forKey: "pocketbase_user_data"),
           let user = try? JSONDecoder().decode(GymUser.self, from: userData) {
            self.currentUser = user
        }
        
        if isLoggedIn {
            Task { @MainActor in
                await refreshAllGymData()
            }
        }
    }
    
    /// Normaliza la URL formateando la barra final si no está.
    private var normalizedBaseURL: String {
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url.removeLast()
        }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        return url
    }
    
    // MARK: - Autenticación
    
    public func login(identity: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/auth-with-password") else {
            errorMessage = "URL de servidor no válida"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["identity": identity, "password": password]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Error formateando credenciales"
            return false
        }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                errorMessage = "Credenciales incorrectas o servidor no disponible"
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String,
               let recordDict = json["record"] as? [String: Any],
               let recordData = try? JSONSerialization.data(withJSONObject: recordDict),
               let user = try? JSONDecoder().decode(GymUser.self, from: recordData) {
                
                self.authToken = token
                self.currentUser = user
                
                await refreshAllGymData()
                return true
            } else {
                errorMessage = "Error al procesar la respuesta del servidor"
                return false
            }
        } catch {
            errorMessage = "Error de red: \(error.localizedDescription)"
            return false
        }
    }
    
    public func logout() {
        self.authToken = nil
        self.currentUser = nil
        self.activeRoutine = nil
        self.routineDays = []
        self.completedDayIds = []
        self.progressUploads = []
    }
    
    // MARK: - Carga de Datos de Gimnasio
    
    public func refreshAllGymData() async {
        guard isLoggedIn, let user = currentUser else { return }
        
        await fetchActiveRoutine(forUserId: user.id)
        await fetchProgressUploads(forUserId: user.id)
    }
    
    public func fetchActiveRoutine(forUserId userId: String) async {
        guard let token = authToken else { return }
        
        // 1. Obtener la asignación de rutina activa (client_routines)
        let filterStr = "(client=\"\(userId)\" && active=true)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records?filter=\(filterStr)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let firstAssignment = items.first,
               let routineId = firstAssignment["routine"] as? String {
                
                await fetchRoutineDetails(routineId: routineId)
            } else {
                // Si no hay asignación activa explícita, intentar obtener la primera rutina disponible
                await fetchFirstAvailableRoutine()
            }
        } catch {
            print("Error obteniendo rutina activa: \(error.localizedDescription)")
        }
    }
    
    private func fetchFirstAvailableRoutine() async {
        guard let token = authToken,
              let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records?perPage=1") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PocketBaseListResponse<GymRoutine>.self, from: data)
            if let firstRoutine = response.items.first {
                await fetchRoutineDetails(routineId: firstRoutine.id)
            }
        } catch {
            print("Error obteniendo rutina por defecto: \(error.localizedDescription)")
        }
    }
    
    private func fetchRoutineDetails(routineId: String) async {
        guard let token = authToken else { return }
        
        // Cargar modelo de Rutina
        if let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records/\(routineId)") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let routine = try? JSONDecoder().decode(GymRoutine.self, from: data) {
                self.activeRoutine = routine
            }
        }
        
        // Cargar Días de la Rutina
        let filterStr = "(routine=\"\(routineId)\")".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records?filter=\(filterStr)&sort=day_number") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymRoutineDay>.self, from: data) {
                self.routineDays = listResp.items
            }
        }
        
        await fetchCompletions()
    }
    
    public func fetchCompletions() async {
        guard let token = authToken, let user = currentUser else { return }
        let filterStr = "(client=\"\(user.id)\")".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records?filter=\(filterStr)") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutCompletion>.self, from: data) {
            self.completedDayIds = Set(listResp.items.map { $0.routine_day })
        }
    }
    
    public func toggleDayCompletion(dayId: String) async {
        guard let token = authToken, let user = currentUser else { return }
        
        if completedDayIds.contains(dayId) {
            completedDayIds.remove(dayId)
            // Opcionalmente eliminar del servidor
        } else {
            completedDayIds.insert(dayId)
            // Guardar completado en PocketBase
            guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "client": user.id,
                "routine_day": dayId,
                "completed_at": Date().formatted(.iso8601)
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    // MARK: - Subida de Archivos y Galería
    
    public func fetchProgressUploads(forUserId userId: String) async {
        guard let token = authToken else { return }
        let filterStr = "(client=\"\(userId)\")".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records?filter=\(filterStr)&sort=-created") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymProgressUpload>.self, from: data) {
            self.progressUploads = listResp.items
        }
    }
    
    public func uploadProgressMedia(fileData: Data, fileName: String, mimeType: String, notes: String) async -> Bool {
        guard let token = authToken, let user = currentUser else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records") else { return false }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Campo client
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"client\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(user.id)\r\n".data(using: .utf8)!)
        
        // Campo notes
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"notes\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(notes)\r\n".data(using: .utf8)!)
        
        // Campo file_type
        let isVideo = mimeType.contains("video")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(isVideo ? "video" : "image")\r\n".data(using: .utf8)!)
        
        // Campo file (binario)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                await fetchProgressUploads(forUserId: user.id)
                return true
            }
        } catch {
            print("Error en subida de progreso: \(error.localizedDescription)")
        }
        return false
    }
    
    public func getFileURL(recordId: String, collectionName: String = "progress_uploads", fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return URL(string: "\(normalizedBaseURL)/api/files/\(collectionName)/\(recordId)/\(fileName)")
    }
}
