import Foundation
import Combine

/// Gestor principal de conexión con el backend PocketBase (rutinas, fotos/vídeos de progreso y autenticación de usuarios).
@MainActor
public final class PocketBaseManager: ObservableObject {
    public let serverURL: String = "https://pb-gymapp-1.davidrus.dev"
    
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
    
    @Published public var fileToken: String?
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
        let savedToken = UserDefaults.standard.string(forKey: "pocketbase_auth_token")
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
    
    /// Normaliza la URL del servidor base.
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
        self.fileToken = nil
        self.currentUser = nil
        self.activeRoutine = nil
        self.routineDays = []
        self.completedDayIds = []
        self.progressUploads = []
    }
    
    /// Construye una URL con parámetros de consulta codificados correctamente (evita errores con '&&', comillas, espacios, etc.).
    private func makeURL(path: String, queryItems: [URLQueryItem] = []) -> URL? {
        var components = URLComponents(string: "\(normalizedBaseURL)\(path)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
    
    // MARK: - Carga de Datos de Gimnasio
    
    public func fetchFileToken() async {
        guard let token = authToken, let url = makeURL(path: "/api/files/token") else { return }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fToken = json["token"] as? String {
                self.fileToken = fToken
            }
        } catch {
            print("Error obteniendo token de archivos: \(error.localizedDescription)")
        }
    }
    
    public func refreshAllGymData() async {
        guard isLoggedIn, let user = currentUser else { return }
        
        await fetchFileToken()
        await fetchActiveRoutine(forUserId: user.id)
        await fetchProgressUploads(forUserId: user.id)
    }
    
    public func fetchActiveRoutine(forUserId userId: String) async {
        guard let token = authToken else { return }
        
        guard let url = makeURL(
            path: "/api/collections/client_routines/records",
            queryItems: [
                URLQueryItem(name: "filter", value: "client = \"\(userId)\" && active = true"),
                URLQueryItem(name: "expand", value: "routine")
            ]
        ) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {
                print("PocketBase fetchActiveRoutine HTTP Error: \(httpResp.statusCode)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let firstAssignment = items.first {
                
                var targetRoutineId: String? = firstAssignment["routine"] as? String
                
                // Extraer el objeto de rutina expandido
                if let expand = firstAssignment["expand"] as? [String: Any],
                   let routineDict = expand["routine"] as? [String: Any],
                   let routineData = try? JSONSerialization.data(withJSONObject: routineDict),
                   let routine = try? JSONDecoder().decode(GymRoutine.self, from: routineData) {
                    
                    self.activeRoutine = routine
                    targetRoutineId = routine.id
                }
                
                if let rId = targetRoutineId {
                    await fetchRoutineDays(routineId: rId)
                }
            } else {
                self.activeRoutine = nil
                self.routineDays = []
            }
        } catch {
            print("Error obteniendo rutina activa: \(error.localizedDescription)")
            self.activeRoutine = nil
            self.routineDays = []
        }
    }
    
    private func fetchRoutineDays(routineId: String) async {
        guard let token = authToken else { return }
        
        // Si no teníamos los datos completos de la rutina, cargarlos directamente
        if self.activeRoutine == nil || self.activeRoutine?.id != routineId {
            if let url = makeURL(path: "/api/collections/routines/records/\(routineId)") {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if let (data, _) = try? await URLSession.shared.data(for: req),
                   let routine = try? JSONDecoder().decode(GymRoutine.self, from: data) {
                    self.activeRoutine = routine
                }
            }
        }
        
        if let url = makeURL(
            path: "/api/collections/routine_days/records",
            queryItems: [
                URLQueryItem(name: "filter", value: "routine = \"\(routineId)\""),
                URLQueryItem(name: "sort", value: "created")
            ]
        ) {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, response) = try? await URLSession.shared.data(for: req) {
                if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {
                    print("PocketBase fetchRoutineDays HTTP Error: \(httpResp.statusCode)")
                }
                if let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymRoutineDay>.self, from: data) {
                    self.routineDays = listResp.items
                }
            }
        }
        
        await fetchCompletions()
    }
    
    public func fetchCompletions() async {
        guard let token = authToken, let user = currentUser else { return }
        let today = String(Date().formatted(.iso8601).prefix(10))
        
        guard let url = makeURL(
            path: "/api/collections/workout_completions/records",
            queryItems: [
                URLQueryItem(name: "filter", value: "client = \"\(user.id)\" && completed_date = \"\(today)\"")
            ]
        ) else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutCompletion>.self, from: data) {
            self.completedDayIds = Set(listResp.items.map { $0.routine_day })
        }
    }
    
    public func toggleDayCompletion(dayId: String) async {
        guard let token = authToken, let user = currentUser else { return }
        let todayStr = String(Date().formatted(.iso8601).prefix(10))
        
        if completedDayIds.contains(dayId) {
            completedDayIds.remove(dayId)
            if let url = makeURL(
                path: "/api/collections/workout_completions/records",
                queryItems: [
                    URLQueryItem(name: "filter", value: "client = \"\(user.id)\" && routine_day = \"\(dayId)\" && completed_date = \"\(todayStr)\"")
                ]
            ) {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if let (data, _) = try? await URLSession.shared.data(for: req),
                   let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutCompletion>.self, from: data),
                   let firstItem = listResp.items.first {
                    
                    if let delURL = makeURL(path: "/api/collections/workout_completions/records/\(firstItem.id)") {
                        var delReq = URLRequest(url: delURL)
                        delReq.httpMethod = "DELETE"
                        delReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        _ = try? await URLSession.shared.data(for: delReq)
                    }
                }
            }
        } else {
            completedDayIds.insert(dayId)
            guard let url = makeURL(path: "/api/collections/workout_completions/records") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "client": user.id,
                "routine_day": dayId,
                "completed_date": todayStr
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    // MARK: - Subida de Archivos y Galería
    
    public func fetchProgressUploads(forUserId userId: String) async {
        guard let token = authToken else { return }
        
        guard let url = makeURL(
            path: "/api/collections/progress_uploads/records",
            queryItems: [
                URLQueryItem(name: "filter", value: "client = \"\(userId)\""),
                URLQueryItem(name: "sort", value: "-created")
            ]
        ) else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {
                print("PocketBase fetchProgressUploads HTTP Error: \(httpResp.statusCode)")
            }
            if let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymProgressUpload>.self, from: data) {
                self.progressUploads = listResp.items
            }
        } catch {
            print("Error cargando progress_uploads: \(error.localizedDescription)")
        }
    }
    
    public func uploadProgressMedia(fileData: Data?, fileName: String, mimeType: String, notes: String) async -> Bool {
        guard let token = authToken, let user = currentUser else { return false }
        guard let url = makeURL(path: "/api/collections/progress_uploads/records") else { return false }
        
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
        if let data = fileData {
            let isVideo = mimeType.contains("video")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(isVideo ? "video" : "image")\r\n".data(using: .utf8)!)
            
            // Campo file (binario)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
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
        let tokenToUse = fileToken ?? authToken
        var queryItems: [URLQueryItem] = []
        if let token = tokenToUse, !token.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        return makeURL(path: "/api/files/\(collectionName)/\(recordId)/\(fileName)", queryItems: queryItems)
    }
}
