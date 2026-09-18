import Foundation
import Combine
import SwiftUI
import UserNotifications

/// Gestor principal de conexión con el backend PocketBase (rutinas, fotos/vídeos de progreso y autenticación de usuarios).
@MainActor
public final class PocketBaseManager: ObservableObject {
    public let serverURL: String = "https://pb-gymapp-1.davidrus.dev"
    
    private var tokenObserver: Any?
    
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
    @Published public var clientNotes: [GymClientNote] = []
    @Published public var streak: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var mustChangePassword: Bool = false
    
    // Propiedades exclusivas de Entrenador (Admin)
    @Published public var trainerClients: [GymUser] = []
    @Published public var trainerRoutines: [GymRoutine] = []
    @Published public var trainerUploads: [GymProgressUpload] = []
    
    public var pendingReviewsCount: Int {
        trainerUploads.filter { $0.seen_by_admin != true }.count
    }
    
    public var isLoggedIn: Bool {
        return authToken != nil && currentUser != nil
    }
    
    public init() {
        let savedToken = UserDefaults.standard.string(forKey: "pocketbase_auth_token")
        self.authToken = savedToken
        
        if let userData = UserDefaults.standard.data(forKey: "pocketbase_user_data"),
           let user = try? JSONDecoder().decode(GymUser.self, from: userData) {
            self.currentUser = user
            self.mustChangePassword = user.needsPasswordChange
        }
        
        // Escuchar si llega el token de APNs desde el AppDelegate
        self.tokenObserver = NotificationCenter.default.addObserver(forName: .didReceiveAPNsToken, object: nil, queue: .main) { [weak self] notif in
            if let token = notif.object as? String {
                Task { @MainActor in
                    _ = await self?.updateDeviceToken(token)
                }
            }
        }
        
        if isLoggedIn {
            Task { @MainActor in
                await refreshAllGymData()
                await syncAPNsDeviceToken()
            }
        }
    }
    
    deinit {
        if let observer = tokenObserver {
            NotificationCenter.default.removeObserver(observer)
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
                
                // Bloquear acceso si la cuenta está inactiva
                if !user.isActive {
                    errorMessage = "Tu cuenta ha sido desactivada. Contacta con tu entrenador."
                    return false
                }
                
                self.authToken = token
                self.currentUser = user
                self.mustChangePassword = user.needsPasswordChange
                
                await refreshAllGymData()
                await syncAPNsDeviceToken()
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
        self.clientNotes = []
        self.trainerClients = []
        self.trainerRoutines = []
        self.trainerUploads = []
        self.streak = 0
        self.mustChangePassword = false
        // Nota: NO borramos errorMessage aquí para que los auto-logouts
        // puedan mostrar el motivo en la pantalla de login.
        // Las vistas llaman a pbManager.errorMessage = nil manualmente al abrir login.
    }
    
    /// Cierra la sesión limpiando también el mensaje de error (logout manual).
    public func logoutManual() {
        self.errorMessage = nil
        logout()
    }
    
    // MARK: - Carga de Datos de Gimnasio
    
    public func refreshAuthSession() async -> Bool {
        guard let token = authToken, let url = URL(string: "\(normalizedBaseURL)/api/collections/users/auth-refresh") else {
            return false
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newToken = json["token"] as? String,
               let recordDict = json["record"] as? [String: Any],
               let recordData = try? JSONSerialization.data(withJSONObject: recordDict),
               let updatedUser = try? JSONDecoder().decode(GymUser.self, from: recordData) {
                
                // Si el admin ha desactivado la cuenta, cerrar sesión automáticamente
                if !updatedUser.isActive {
                    logout()
                    // Asignar después de logout para que no se borre
                    errorMessage = "Tu cuenta ha sido desactivada por el entrenador."
                    return false
                }

                self.authToken = newToken
                self.currentUser = updatedUser
                self.mustChangePassword = updatedUser.needsPasswordChange
                return true
            }
        } catch {
            print("Error en auth-refresh: \(error.localizedDescription)")
        }
        return false
    }

    public func fetchFileToken() async {
        guard let token = authToken, let url = URL(string: "\(normalizedBaseURL)/api/files/token") else { return }
        
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
        
        _ = await refreshAuthSession()
        await fetchFileToken()
        
        if user.isAdmin {
            await fetchTrainerAllData()
        } else {
            await fetchActiveRoutine(forUserId: user.id)
            await fetchProgressUploads(forUserId: user.id)
            await fetchClientNotes(forUserId: user.id)
        }
    }
    
    public func fetchActiveRoutine(forUserId userId: String) async {
        guard let token = authToken else { return }
        
        // Exactamente como en la web: client = "id" && active = true con expand = routine
        let filterStr = "client = \"\(userId)\" && active = true".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records?filter=\(filterStr)&expand=routine") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                if let httpResp = response as? HTTPURLResponse {
                    print("PocketBase fetchActiveRoutine HTTP Error: \(httpResp.statusCode)")
                }
                return
            }
            
            if let listResp = try? JSONDecoder().decode(PocketBaseListResponse<ClientRoutineRecord>.self, from: data),
               let firstAssignment = listResp.items.first {
                
                if let routine = firstAssignment.expand?.routine {
                    self.activeRoutine = routine
                    await fetchRoutineDays(routineId: routine.id)
                } else {
                    let routineId = firstAssignment.routine
                    await fetchSingleRoutine(routineId: routineId)
                    await fetchRoutineDays(routineId: routineId)
                }
            } else {
                self.activeRoutine = nil
                self.routineDays = []
            }
        } catch {
            print("Error obteniendo rutina activa: \(error.localizedDescription)")
        }
    }
    
    public func fetchSingleRoutine(routineId: String) async {
        guard let token = authToken else { return }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records/\(routineId)") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let routine = try? JSONDecoder().decode(GymRoutine.self, from: data) {
                self.activeRoutine = routine
            }
        }
    }
    
    private func fetchRoutineDays(routineId: String) async {
        guard let token = authToken else { return }
        
        // En la web: pb.collection('routine_days').getFullList({ filter: `routine = "${r.id}"` })
        // IMPORTANTE: NO pasar &sort=created ya que routine_days no tiene dicho campo.
        let filterStr = "routine = \"\(routineId)\"".pocketBaseQueryEncoded
        if let url = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records?filter=\(filterStr)") {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                do {
                    let listResp = try JSONDecoder().decode(PocketBaseListResponse<GymRoutineDay>.self, from: data)
                    self.routineDays = listResp.items
                } catch {
                    self.errorMessage = "Error decodificando días de rutina: \(error)"
                    print("Decode error PocketBaseListResponse<GymRoutineDay>: \(error)")
                }
            }
        }
        
        await fetchCompletions()
    }
    
    public func fetchCompletions() async {
        guard let token = authToken, let user = currentUser else { return }
        
        // En la web: pb.collection('workout_completions').getFullList({ filter: `client = "${profile.id}"`, sort: '-completed_date' })
        let filterStr = "client = \"\(user.id)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records?filter=\(filterStr)&sort=-completed_date") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            do {
                let listResp = try JSONDecoder().decode(PocketBaseListResponse<GymWorkoutCompletion>.self, from: data)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let todayStr = formatter.string(from: Date())
                
                let todayCompletions = listResp.items.filter { item in
                    guard let cDate = item.completed_date else { return false }
                    return cDate.hasPrefix(todayStr) || cDate.contains(todayStr)
                }
                
                self.completedDayIds = Set(todayCompletions.map { $0.routine_day })
                self.streak = calculateStreak(from: listResp.items)
            } catch {
                print("Decode error PocketBaseListResponse<GymWorkoutCompletion>: \(error)")
            }
        }
    }
    
    private func calculateStreak(from completions: [GymWorkoutCompletion]) -> Int {
        guard !completions.isEmpty else { return 0 }
        
        // Extraer fechas únicas en formato YYYY-MM-DD
        let datesSet = Set(completions.compactMap { comp -> String? in
            guard let raw = comp.completed_date else { return nil }
            let clean = raw.replacingOccurrences(of: "T", with: " ")
            let parts = clean.split(separator: " ")
            return parts.first.map(String.init)
        })
        let sortedDates = datesSet.sorted(by: >)
        guard let latest = sortedDates.first else { return 0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let todayStr = formatter.string(from: Date())
        let yesterdayStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        
        guard latest == todayStr || latest == yesterdayStr else { return 0 }
        
        var currentExpectedDate = latest
        var streakCount = 0
        
        for dateStr in sortedDates {
            if dateStr == currentExpectedDate {
                streakCount += 1
                if let dateObj = formatter.date(from: currentExpectedDate),
                   let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: dateObj) {
                    currentExpectedDate = formatter.string(from: prevDay)
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streakCount
    }
    
    public func toggleDayCompletion(dayId: String) async {
        guard let token = authToken, let user = currentUser else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayStr = formatter.string(from: Date())
        
        if completedDayIds.contains(dayId) {
            completedDayIds.remove(dayId)
            let filterStr = "client = \"\(user.id)\" && routine_day = \"\(dayId)\"".pocketBaseQueryEncoded
            if let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records?filter=\(filterStr)") {
                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if let (data, _) = try? await URLSession.shared.data(for: req),
                   let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutCompletion>.self, from: data) {
                    
                    if let target = listResp.items.first(where: { $0.completed_date?.contains(todayStr) == true }) ?? listResp.items.first {
                        if let delURL = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records/\(target.id)") {
                            var delReq = URLRequest(url: delURL)
                            delReq.httpMethod = "DELETE"
                            delReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            _ = try? await URLSession.shared.data(for: delReq)
                        }
                    }
                }
            }
        } else {
            completedDayIds.insert(dayId)
            guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_completions/records") else { return }
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
    
    // MARK: - Registro de Cargas (Workout Logs con log_date)
    
    public func fetchTodayLog(routineDayId: String) async -> GymWorkoutLog? {
        guard let token = authToken, let user = currentUser else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayStr = formatter.string(from: Date())
        
        let filterStr = "client = \"\(user.id)\" && routine_day = \"\(routineDayId)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_logs/records?filter=\(filterStr)&sort=-log_date") else { return nil }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutLog>.self, from: data) {
            return listResp.items.first { item in
                guard let lDate = item.log_date else { return false }
                return lDate.contains(todayStr)
            }
        }
        return nil
    }
    
    public func fetchAllLogs(routineDayId: String? = nil) async -> [GymWorkoutLog] {
        guard let token = authToken, let user = currentUser else { return [] }
        
        var filter = "client = \"\(user.id)\""
        if let rId = routineDayId {
            filter += " && routine_day = \"\(rId)\""
        }
        let filterStr = filter.pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/workout_logs/records?filter=\(filterStr)&sort=-log_date") else { return [] }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymWorkoutLog>.self, from: data) {
            return listResp.items
        }
        return []
    }
    
    public func saveWorkoutLog(routineDayId: String, content: String) async -> Bool {
        guard let token = authToken, let user = currentUser else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayStr = formatter.string(from: Date())
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingToday = await fetchTodayLog(routineDayId: routineDayId)
        
        if trimmed.isEmpty {
            if let existing = existingToday, let delURL = URL(string: "\(normalizedBaseURL)/api/collections/workout_logs/records/\(existing.id)") {
                var delReq = URLRequest(url: delURL)
                delReq.httpMethod = "DELETE"
                delReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: delReq)
            }
            return true
        }
        
        if let existing = existingToday, let updateURL = URL(string: "\(normalizedBaseURL)/api/collections/workout_logs/records/\(existing.id)") {
            var req = URLRequest(url: updateURL)
            req.httpMethod = "PATCH"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["content": trimmed]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, resp) = (try? await URLSession.shared.data(for: req)) ?? (Data(), nil)
            return (resp as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } else {
            guard let createURL = URL(string: "\(normalizedBaseURL)/api/collections/workout_logs/records") else { return false }
            var req = URLRequest(url: createURL)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "client": user.id,
                "routine_day": routineDayId,
                "log_date": todayStr,
                "content": trimmed
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, resp) = (try? await URLSession.shared.data(for: req)) ?? (Data(), nil)
            return (resp as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        }
    }
    
    // MARK: - Subida de Archivos y Galería
    
    public func fetchProgressUploads(forUserId userId: String) async {
        guard let token = authToken else { return }
        
        // En la web: pb.collection('progress_uploads').getFullList({ filter: `client = "${profile.id}"` })
        // IMPORTANTE: NO pasar &sort=-created porque progress_uploads no tiene dicho campo.
        let filterStr = "client = \"\(userId)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records?filter=\(filterStr)") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                do {
                    let listResp = try JSONDecoder().decode(PocketBaseListResponse<GymProgressUpload>.self, from: data)
                    // Ordenamos de más reciente a más antiguo en memoria de forma segura
                    self.progressUploads = listResp.items.sorted {
                        if let d1 = $0.uploaded_at, let d2 = $1.uploaded_at, !d1.isEmpty, !d2.isEmpty {
                            return d1 > d2
                        }
                        return $0.id > $1.id
                    }
                } catch {
                    self.errorMessage = "Error decodificando archivos: \(error)"
                    print("Decode error PocketBaseListResponse<GymProgressUpload>: \(error)")
                }
            } else if let httpResp = response as? HTTPURLResponse {
                print("PocketBase fetchProgressUploads HTTP Error: \(httpResp.statusCode)")
            }
        } catch {
            print("Error cargando progress_uploads: \(error.localizedDescription)")
        }
    }
    
    public func uploadProgressMedia(fileData: Data?, fileName: String, mimeType: String, notes: String) async -> Bool {
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
        
        // Campo seen_by_admin (igual que GymApp.jsx)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"seen_by_admin\"\r\n\r\n".data(using: .utf8)!)
        body.append("false\r\n".data(using: .utf8)!)
        
        // Campo uploaded_at (igual que GymApp.jsx)
        let isoFormatter = ISO8601DateFormatter()
        let nowISO = isoFormatter.string(from: Date())
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploaded_at\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(nowISO)\r\n".data(using: .utf8)!)
        
        // Campo note (en el backend es 'note', NO 'notes')
        let trimmedNote = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"note\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(trimmedNote)\r\n".data(using: .utf8)!)
        }
        
        // Campo file_type y file binario
        if let data = fileData {
            let isVideo = mimeType.lowercased().contains("video")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file_type\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(isVideo ? "video" : "image")\r\n".data(using: .utf8)!)
            
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
    
    // MARK: - Notas del Entrenador (client_notes)
    
    public func fetchClientNotes(forUserId userId: String) async {
        guard let token = authToken else { return }
        let filterStr = "client = \"\(userId)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_notes/records?filter=\(filterStr)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                do {
                    let listResp = try JSONDecoder().decode(PocketBaseListResponse<GymClientNote>.self, from: data)
                    self.clientNotes = listResp.items
                } catch {
                    print("Decode error GymClientNote: \(error)")
                }
            } else if let httpResp = response as? HTTPURLResponse {
                print("PocketBase fetchClientNotes HTTP Error: \(httpResp.statusCode)")
            }
        } catch {
            print("Error cargando client_notes: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Eliminación de Archivos de Progreso
    
    public func deleteProgressUpload(id: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records/\(id)") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                self.progressUploads.removeAll { $0.id == id }
                return true
            }
        } catch {
            print("Error eliminando progress_upload \(id): \(error.localizedDescription)")
        }
        return false
    }
    
    public func deleteMultipleProgressUploads(ids: Set<String>) async -> Int {
        var count = 0
        for id in ids {
            let success = await deleteProgressUpload(id: id)
            if success { count += 1 }
        }
        return count
    }
    
    public func getFileURL(recordId: String, collectionName: String = "progress_uploads", fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return URL(string: "\(normalizedBaseURL)/api/files/\(collectionName)/\(recordId)/\(fileName)")
    }
    
    // MARK: - APNs Device Token Sync
    
    public func updateDeviceToken(_ token: String) async -> Bool {
        guard let user = currentUser, let authToken = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records/\(user.id)") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "apns_token": token,
            "device_token": token
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                print("✅ Token APNs sincronizado con PocketBase para usuario \(user.id)")
                return true
            }
        } catch {
            print("⚠️ Error sincronizando token APNs con PocketBase: \(error.localizedDescription)")
        }
        return false
    }
    
    public func syncAPNsDeviceToken() async {
        if let token = UserDefaults.standard.string(forKey: "apns_device_token"), isLoggedIn {
            _ = await updateDeviceToken(token)
        }
    }
    
    // MARK: - Comprobación Periódica de Cambios del Entrenador
    
    /// Comprueba si han habido nuevas notas, cambios en la rutina o respuestas a entregas desde la última revisión y notifica.
    public func checkTrainerUpdatesAndNotify() async {
        guard isLoggedIn, let user = currentUser else { return }
        
        let lastCheckTime = UserDefaults.standard.double(forKey: "last_trainer_check_timestamp")
        let currentTimestamp = Date().timeIntervalSince1970
        // Guardamos el nuevo timestamp para futuras comprobaciones
        UserDefaults.standard.set(currentTimestamp, forKey: "last_trainer_check_timestamp")
        
        // Si es la primera vez que se ejecuta, simplemente refrescamos sin spam de notificaciones
        if lastCheckTime == 0 {
            await refreshAllGymData()
            return
        }
        
        let lastCheckDate = Date(timeIntervalSince1970: lastCheckTime)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let lastCheckISO = isoFormatter.string(from: lastCheckDate)
        
        // 1. Revisar nuevas notas del entrenador creadas o modificadas tras lastCheckDate
        await checkForNewNotes(userId: user.id, afterISO: lastCheckISO)
        
        // 2. Revisar si la rutina activa cambió tras lastCheckDate
        await checkForRoutineUpdates(userId: user.id, afterISO: lastCheckISO)
        
        // 3. Revisar si alguna entrega de progreso fue comentada o revisada
        await checkForProgressReviews(userId: user.id, afterISO: lastCheckISO)
    }
    
    private func checkForNewNotes(userId: String, afterISO: String) async {
        guard let token = authToken else { return }
        let filterStr = "client = \"\(userId)\" && updated > \"\(afterISO)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_notes/records?filter=\(filterStr)&limit=1") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
           let list = try? JSONDecoder().decode(PocketBaseListResponse<GymClientNote>.self, from: data),
           let latestNote = list.items.first {
            
            await fetchClientNotes(forUserId: userId)
            let noteContent = latestNote.content ?? "Tienes una nueva nota de tu entrenador."
            showLocalNotification(
                title: "💬 Nueva Nota del Entrenador",
                body: noteContent
            )
        }
    }
    
    private func checkForRoutineUpdates(userId: String, afterISO: String) async {
        guard let token = authToken else { return }
        let filterStr = "client = \"\(userId)\" && active = true && updated > \"\(afterISO)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records?filter=\(filterStr)&limit=1") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
           let list = try? JSONDecoder().decode(PocketBaseListResponse<ClientRoutineRecord>.self, from: data),
           !list.items.isEmpty {
            
            await fetchActiveRoutine(forUserId: userId)
            showLocalNotification(
                title: "🏋️ Rutina Actualizada",
                body: "Tu entrenador ha modificado tu plan de entrenamiento."
            )
        }
    }
    
    private func checkForProgressReviews(userId: String, afterISO: String) async {
        guard let token = authToken else { return }
        let filterStr = "user = \"\(userId)\" && updated > \"\(afterISO)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records?filter=\(filterStr)&sort=-updated&limit=1") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
           let list = try? JSONDecoder().decode(PocketBaseListResponse<GymProgressUpload>.self, from: data),
           let upload = list.items.first,
           (upload.admin_response != nil || upload.seen_by_admin == true) {
            
            await fetchProgressUploads(forUserId: userId)
            let bodyMsg = (upload.admin_response != nil && !upload.admin_response!.isEmpty)
                ? "Feedback: \(upload.admin_response!)"
                : "Tu entrega multimedia ha sido visualizada."
            showLocalNotification(
                title: "✅ Entrega Revisada",
                body: bodyMsg
            )
        }
    }
    
    private func showLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - API Funciones del Entrenador (Multi-Tenant & Aislamiento)
    
    public func fetchTrainerAllData() async {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return }
        
        await fetchTrainerClients()
        await fetchTrainerRoutines()
        await fetchTrainerUploads()
    }
    
    public func fetchTrainerClients() async {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return }
        
        // Clientes asignados exclusivamente a este entrenador
        let filterStr = "trainer = \"\(user.id)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records?filter=\(filterStr)&sort=-created") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymUser>.self, from: data) {
            self.trainerClients = listResp.items.filter { $0.id != user.id }
        }
    }
    
    public func fetchTrainerRoutines() async {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return }
        
        // Rutinas de este entrenador o rutinas globales sin entrenador
        let filterStr = "trainer = \"\(user.id)\" || trainer = \"\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records?filter=\(filterStr)") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymRoutine>.self, from: data) {
            
            var routinesWithDays = listResp.items
            // Cargar conteo de días para cada rutina
            for i in 0..<routinesWithDays.count {
                let rId = routinesWithDays[i].id
                let daysFilter = "routine = \"\(rId)\"".pocketBaseQueryEncoded
                if let daysURL = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records?filter=\(daysFilter)&fields=id") {
                    var dReq = URLRequest(url: daysURL)
                    dReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    if let (dData, _) = try? await URLSession.shared.data(for: dReq),
                       let dList = try? JSONDecoder().decode(PocketBaseListResponse<GymRoutineDay>.self, from: dData) {
                        routinesWithDays[i].daysCount = dList.totalItems
                    }
                }
            }
            self.trainerRoutines = routinesWithDays
        }
    }
    
    public func fetchTrainerUploads() async {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return }
        
        // Asegurar que solo vemos entregas de clientes asignados a este entrenador
        // expand=client para tener el nombre, avatar y detalles del cliente
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records?expand=client&sort=-uploaded_at") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymProgressUpload>.self, from: data) {
            
            // Filtro local estricto de seguridad multi-tenant:
            // Solo incluir si el cliente tiene trainer = user.id, o si es de un cliente sin entrenador
            let myClientIds = Set(self.trainerClients.map { $0.id })
            self.trainerUploads = listResp.items.filter { item in
                guard let clientId = item.client else { return false }
                if let clientObj = item.expand?.client {
                    if let cTrainer = clientObj.trainer, !cTrainer.isEmpty {
                        return cTrainer == user.id
                    }
                }
                return myClientIds.contains(clientId) || myClientIds.isEmpty
            }
        }
    }
    
    public func markUploadAsSeen(uploadId: String, seen: Bool = true) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records/\(uploadId)") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["seen_by_admin": seen]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let idx = trainerUploads.firstIndex(where: { $0.id == uploadId }) {
                trainerUploads[idx].seen_by_admin = seen
            }
            return true
        }
        return false
    }
    
    public func createClient(email: String, name: String, password: String) async -> Bool {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "passwordConfirm": password,
            "name": name,
            "role": "client",
            "trainer": user.id,
            "status": "activo",
            "must_change_password": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let newClient = try? JSONDecoder().decode(GymUser.self, from: data) {
            self.trainerClients.insert(newClient, at: 0)
            return true
        }
        return false
    }
    
    public func changeOwnPassword(oldPassword: String, newPassword: String) async -> (success: Bool, message: String) {
        guard let token = authToken, let user = currentUser else {
            return (false, "No hay sesión activa.")
        }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records/\(user.id)") else {
            return (false, "URL no válida.")
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "oldPassword": oldPassword,
            "password": newPassword,
            "passwordConfirm": newPassword,
            "must_change_password": false
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse else {
                return (false, "Error de red.")
            }
            if (200...299).contains(httpResp.statusCode) {
                if var updated = try? JSONDecoder().decode(GymUser.self, from: data) {
                    updated.must_change_password = false
                    self.currentUser = updated
                } else if var cur = self.currentUser {
                    cur.must_change_password = false
                    self.currentUser = cur
                }
                self.mustChangePassword = false
                return (true, "Contraseña actualizada con éxito.")
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    return (false, message)
                }
                return (false, "Error al cambiar la contraseña. Revisa que la contraseña actual sea correcta.")
            }
        } catch {
            return (false, "Error de conexión: \(error.localizedDescription)")
        }
    }
    
    public func changeClientPassword(clientId: String, newPassword: String) async -> (success: Bool, message: String) {
        guard let token = authToken, let user = currentUser, user.isAdmin else {
            return (false, "No tienes permisos de entrenador.")
        }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records/\(clientId)") else {
            return (false, "URL no válida.")
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "password": newPassword,
            "passwordConfirm": newPassword,
            "must_change_password": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse else {
                return (false, "Error de red.")
            }
            if (200...299).contains(httpResp.statusCode) {
                if let updatedClient = try? JSONDecoder().decode(GymUser.self, from: data),
                   let idx = trainerClients.firstIndex(where: { $0.id == clientId }) {
                    trainerClients[idx] = updatedClient
                }
                return (true, "Contraseña modificada correctamente.")
            } else {
                return (false, "Error al modificar la contraseña del cliente.")
            }
        } catch {
            return (false, "Error de conexión: \(error.localizedDescription)")
        }
    }
    
    public func setClientStatus(clientId: String, status: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/users/records/\(clientId)") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["status": status]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let idx = trainerClients.firstIndex(where: { $0.id == clientId }) {
                trainerClients[idx].status = status
            }
            return true
        }
        return false
    }
    
    public func createRoutine(name: String, description: String, level: String) async -> Bool {
        guard let token = authToken, let user = currentUser, user.isAdmin else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "level": level,
            "trainer": user.id
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           var newRoutine = try? JSONDecoder().decode(GymRoutine.self, from: data) {
            newRoutine.daysCount = 0
            self.trainerRoutines.insert(newRoutine, at: 0)
            return true
        }
        return false
    }
    
    public func deleteRoutine(routineId: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routines/records/\(routineId)") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            self.trainerRoutines.removeAll { $0.id == routineId }
            return true
        }
        return false
    }
    
    public func fetchRoutineDaysForRoutine(routineId: String) async -> [GymRoutineDay] {
        guard let token = authToken else { return [] }
        let filterStr = "routine = \"\(routineId)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records?filter=\(filterStr)") else { return [] }
        
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymRoutineDay>.self, from: data) {
            return listResp.items
        }
        return []
    }
    
    public func addRoutineDay(routineId: String, dayName: String, content: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "routine": routineId,
            "day_name": dayName,
            "content": content
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let idx = trainerRoutines.firstIndex(where: { $0.id == routineId }) {
                trainerRoutines[idx].daysCount = (trainerRoutines[idx].daysCount ?? 0) + 1
            }
            return true
        }
        return false
    }
    
    public func updateRoutineDay(dayId: String, dayName: String, content: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/routine_days/records/\(dayId)") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "day_name": dayName,
            "content": content
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            return true
        }
        return false
    }
    
    public func sendNoteToClient(clientId: String, content: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_notes/records") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client": clientId,
            "content": content
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            return true
        }
        return false
    }
    
    public func assignRoutineToClient(clientId: String, routineId: String) async -> Bool {
        guard let token = authToken else { return false }
        
        // 1. Desactivar asignaciones previas si existen
        let filterStr = "client = \"\(clientId)\" && active = true".pocketBaseQueryEncoded
        if let listURL = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records?filter=\(filterStr)") {
            var getReq = URLRequest(url: listURL)
            getReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: getReq),
               let list = try? JSONDecoder().decode(PocketBaseListResponse<ClientRoutineRecord>.self, from: data) {
                for item in list.items {
                    if let patchURL = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records/\(item.id)") {
                        var pReq = URLRequest(url: patchURL)
                        pReq.httpMethod = "PATCH"
                        pReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        pReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        pReq.httpBody = try? JSONSerialization.data(withJSONObject: ["active": false])
                        _ = try? await URLSession.shared.data(for: pReq)
                    }
                }
            }
        }
        
        // 2. Crear nueva asignación activa
        guard let createURL = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records") else { return false }
        var req = URLRequest(url: createURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client": clientId,
            "routine": routineId,
            "active": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            return true
        }
        return false
    }
    
    public func sendAdminFeedback(uploadId: String, responseText: String) async -> Bool {
        guard let token = authToken else { return false }
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/progress_uploads/records/\(uploadId)") else { return false }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let nowISO = formatter.string(from: Date())
        
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "seen_by_admin": true,
            "admin_response": responseText,
            "admin_response_at": nowISO
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
            if let idx = trainerUploads.firstIndex(where: { $0.id == uploadId }) {
                trainerUploads[idx].seen_by_admin = true
                trainerUploads[idx].admin_response = responseText
                trainerUploads[idx].admin_response_at = nowISO
            }
            return true
        }
        return false
    }
    
    public func fetchNotesForClient(clientId: String) async -> [GymClientNote] {
        guard let token = authToken else { return [] }
        let filterStr = "client = \"\(clientId)\"".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_notes/records?filter=\(filterStr)") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: request),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<GymClientNote>.self, from: data) {
            return listResp.items
        }
        return []
    }
    
    public func fetchActiveRoutineForClient(clientId: String) async -> GymRoutine? {
        guard let token = authToken else { return nil }
        let filterStr = "client = \"\(clientId)\" && active = true".pocketBaseQueryEncoded
        guard let url = URL(string: "\(normalizedBaseURL)/api/collections/client_routines/records?filter=\(filterStr)&expand=routine") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let (data, resp) = try? await URLSession.shared.data(for: request),
           let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
           let listResp = try? JSONDecoder().decode(PocketBaseListResponse<ClientRoutineRecord>.self, from: data),
           let first = listResp.items.first {
            if let routine = first.expand?.routine {
                return routine
            } else {
                let rId = first.routine
                guard let rUrl = URL(string: "\(normalizedBaseURL)/api/collections/routines/records/\(rId)") else { return nil }
                var rReq = URLRequest(url: rUrl)
                rReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if let (rData, rResp) = try? await URLSession.shared.data(for: rReq),
                   let rHttpResp = rResp as? HTTPURLResponse, (200...299).contains(rHttpResp.statusCode),
                   let routine = try? JSONDecoder().decode(GymRoutine.self, from: rData) {
                    return routine
                }
            }
        }
        return nil
    }
}

// MARK: - Extensiones de Apoyo

extension String {
    /// Codifica exactamente igual a `encodeURIComponent` de JavaScript
    var pocketBaseQueryEncoded: String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()")
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

