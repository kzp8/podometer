import Foundation

/// Modelo que representa un usuario de PocketBase (Cliente o Entrenador Admin).
public struct GymUser: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let email: String
    public var name: String?
    public var full_name: String?
    public var role: String? // "admin" o "client"
    public var avatar: String?
    public var trainer: String?
    public var status: String? // "activo", "inactivo" o nil
    public var created: String?
    
    public var userRole: String {
        return role ?? "client"
    }
    
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
    
    public var isAdmin: Bool { userRole == "admin" }
    public var isActive: Bool { status?.lowercased() != "inactivo" }
    
    public init(id: String, email: String, name: String? = nil, full_name: String? = nil, role: String? = "client", avatar: String? = nil, trainer: String? = nil, status: String? = "activo", created: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.full_name = full_name
        self.role = role
        self.avatar = avatar
        self.trainer = trainer
        self.status = status
        self.created = created
    }
}

/// Modelo que representa una rutina de entrenamiento.
public struct GymRoutine: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var description: String?
    public var level: String?
    public var trainer: String?
    
    // Conteo local o expand opcional para días
    public var daysCount: Int?
    
    public init(id: String, name: String, description: String? = nil, level: String? = nil, trainer: String? = nil, daysCount: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.level = level
        self.trainer = trainer
        self.daysCount = daysCount
    }
}

/// Modelo que representa un día dentro de una rutina de entrenamiento.
public struct GymRoutineDay: Identifiable, Codable, Sendable {
    public let id: String
    public var routine: String?
    public var day_name: String?
    public var content: String?
    
    public var title: String {
        day_name ?? "Día de entrenamiento"
    }
    
    public init(id: String, routine: String? = nil, day_name: String? = nil, content: String? = nil) {
        self.id = id
        self.routine = routine
        self.day_name = day_name
        self.content = content
    }
}

/// Modelo que representa un registro de día completado.
public struct GymWorkoutCompletion: Identifiable, Codable, Sendable {
    public let id: String
    public let client: String?
    public let routine_day: String
    public let completed_date: String?
    
    public init(id: String, client: String? = nil, routine_day: String, completed_date: String? = nil) {
        self.id = id
        self.client = client
        self.routine_day = routine_day
        self.completed_date = completed_date
    }
}

/// Modelo que representa las notas o registro de cargas de un día de entrenamiento (workout_logs).
public struct GymWorkoutLog: Identifiable, Codable, Sendable {
    public let id: String
    public let client: String?
    public let routine_day: String?
    public let log_date: String?
    public let content: String?
    
    public init(id: String, client: String? = nil, routine_day: String? = nil, log_date: String? = nil, content: String? = nil) {
        self.id = id
        self.client = client
        self.routine_day = routine_day
        self.log_date = log_date
        self.content = content
    }
}

/// Expansión para incluir datos del cliente en GymProgressUpload
public struct GymProgressUploadExpand: Codable, Sendable, Hashable {
    public let client: GymUser?
}

/// Modelo que representa la subida de un vídeo o foto de progreso entregado al entrenador.
public struct GymProgressUpload: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let client: String?
    public let file: String?
    public let file_type: String? // "image" o "video"
    public let note: String?
    public var seen_by_admin: Bool?
    public var admin_response: String?
    public var admin_response_at: String?
    public var response_seen: Bool?
    public let uploaded_at: String?
    public let created: String?
    public let expand: GymProgressUploadExpand?
    
    /// Alias para compatibilidad con vistas existentes
    public var notes: String? {
        if let n = note, !n.isEmpty { return n }
        return nil
    }
    
    public var isVideo: Bool {
        if let type = file_type, type.lowercased().contains("video") { return true }
        if let filename = file, filename.lowercased().hasSuffix(".mp4") || filename.lowercased().hasSuffix(".mov") { return true }
        return false
    }
    
    public var clientDisplayName: String {
        if let cl = expand?.client {
            return cl.displayName
        }
        return "Cliente"
    }
    
    public var clientInitials: String {
        if let cl = expand?.client {
            return cl.initials
        }
        return "C"
    }
    
    public var formattedUploadDate: String {
        let raw = uploaded_at ?? created ?? ""
        if raw.isEmpty { return "" }
        let clean = raw.replacingOccurrences(of: " ", with: "T")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: clean) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "es_ES")
            out.dateFormat = "d MMM, HH:mm"
            return out.string(from: date)
        }
        return String(raw.prefix(16))
    }
    
    public init(id: String, client: String? = nil, file: String? = nil, file_type: String? = nil, note: String? = nil, notes: String? = nil, seen_by_admin: Bool? = false, admin_response: String? = nil, admin_response_at: String? = nil, response_seen: Bool? = false, uploaded_at: String? = nil, created: String? = nil, expand: GymProgressUploadExpand? = nil) {
        self.id = id
        self.client = client
        self.file = file
        self.file_type = file_type
        self.note = note ?? notes
        self.seen_by_admin = seen_by_admin
        self.admin_response = admin_response
        self.admin_response_at = admin_response_at
        self.response_seen = response_seen
        self.uploaded_at = uploaded_at
        self.created = created
        self.expand = expand
    }
}

/// Modelo de relación de rutina de cliente con expansión
public struct ClientRoutineRecord: Identifiable, Codable, Sendable {
    public let id: String
    public let client: String
    public let routine: String
    public let active: Bool?
    public let expand: ClientRoutineExpand?
}

public struct ClientRoutineExpand: Codable, Sendable {
    public let routine: GymRoutine?
}

/// Modelo que representa una nota dejada por el entrenador para el cliente (client_notes).
public struct GymClientNote: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let client: String?
    public let content: String?
    public let seen: Bool?
    public let created: String?
    
    public var formattedCreatedDate: String {
        guard let raw = created, !raw.isEmpty else { return "" }
        let clean = raw.replacingOccurrences(of: " ", with: "T")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: clean) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "es_ES")
            out.dateFormat = "d MMM, HH:mm"
            return out.string(from: date)
        }
        return String(raw.prefix(16))
    }
    
    public init(id: String, client: String? = nil, content: String? = nil, seen: Bool? = nil, created: String? = nil) {
        self.id = id
        self.client = client
        self.content = content
        self.seen = seen
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


