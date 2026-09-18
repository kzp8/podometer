import Foundation

/// Modelo que representa un usuario de PocketBase (Cliente o Entrenador Admin).
public struct GymUser: Identifiable, Codable, Sendable {
    public let id: String
    public let email: String
    public var name: String?
    public var full_name: String?
    public let role: String // "admin" o "client"
    public var avatar: String?
    public var created: String?
    
    public var displayName: String {
        if let full = full_name, !full.isEmpty { return full }
        if let n = name, !n.isEmpty { return n }
        return email
    }
    
    public var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2, let first = parts[0].first, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        } else if let first = displayName.first {
            return "\(first)".uppercased()
        }
        return "U"
    }
    
    public var formattedJoinedDate: String {
        guard let dateStr = created else { return "" }
        let clean = dateStr.replacingOccurrences(of: " ", with: "T")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: clean) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "es_ES")
            out.dateFormat = "d MMM yyyy"
            return out.string(from: date)
        }
        return String(dateStr.prefix(10))
    }
    
    public var isAdmin: Bool { role == "admin" }
    
    public init(id: String, email: String, name: String? = nil, full_name: String? = nil, role: String = "client", avatar: String? = nil, created: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.full_name = full_name
        self.role = role
        self.avatar = avatar
        self.created = created
    }
}

/// Modelo que representa una rutina de entrenamiento.
public struct GymRoutine: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let level: String?
    
    public init(id: String, name: String, description: String? = nil, level: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.level = level
    }
}

/// Modelo que representa un día dentro de una rutina de entrenamiento.
public struct GymRoutineDay: Identifiable, Codable, Sendable {
    public let id: String
    public let routine: String
    public let day_name: String
    public let content: String?
    
    public init(id: String, routine: String, day_name: String, content: String? = nil) {
        self.id = id
        self.routine = routine
        self.day_name = day_name
        self.content = content
    }
}

/// Modelo que representa un registro de día completado.
public struct GymWorkoutCompletion: Identifiable, Codable, Sendable {
    public let id: String
    public let client: String
    public let routine_day: String
    public let completed_date: String?
    
    public init(id: String, client: String, routine_day: String, completed_date: String? = nil) {
        self.id = id
        self.client = client
        self.routine_day = routine_day
        self.completed_date = completed_date
    }
}

/// Modelo que representa la subida de un vídeo o foto de progreso entregado al entrenador.
public struct GymProgressUpload: Identifiable, Codable, Sendable {
    public let id: String
    public let client: String
    public let file: String?
    public let file_type: String? // "image" o "video"
    public let notes: String?
    public var seen_by_admin: Bool?
    public var admin_response: String?
    public var response_seen: Bool?
    public let created: String?
    
    public var isVideo: Bool {
        if let type = file_type, type.lowercased().contains("video") { return true }
        if let filename = file, filename.lowercased().hasSuffix(".mp4") || filename.lowercased().hasSuffix(".mov") { return true }
        return false
    }
    
    public init(id: String, client: String, file: String? = nil, file_type: String? = nil, notes: String? = nil, seen_by_admin: Bool? = false, admin_response: String? = nil, response_seen: Bool? = false, created: String? = nil) {
        self.id = id
        self.client = client
        self.file = file
        self.file_type = file_type
        self.notes = notes
        self.seen_by_admin = seen_by_admin
        self.admin_response = admin_response
        self.response_seen = response_seen
        self.created = created
    }
}

/// Respuesta paginada de PocketBase.
public struct PocketBaseListResponse<T: Codable & Sendable>: Codable, Sendable {
    public let page: Int
    public let perPage: Int
    public let totalItems: Int
    public let totalPages: Int
    public let items: [T]
}
