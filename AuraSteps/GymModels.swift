import Foundation

/// Modelo que representa un usuario de PocketBase (Cliente o Entrenador Admin).
public struct GymUser: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var email: String
    public var name: String?
    public var full_name: String?
    public var role: String? // "admin" o "client"
    public var avatar: String?
    public var trainer: String?
    public var status: String? // "activo", "inactivo" o nil
    public var created: String?
    public var must_change_password: Bool?
    public var color: String?
    public var avatar_initials: String?
    
    public var userRole: String {
        return role ?? "client"
    }
    
    public var displayName: String {
        if let full = full_name, !full.isEmpty { return full }
        if let n = name, !n.isEmpty { return n }
        if !email.isEmpty { return email }
        return "Cliente"
    }
    
    public var initials: String {
        if let ai = avatar_initials, !ai.isEmpty {
            return ai.uppercased()
        }
        let parts = displayName.split(separator: " ")
        if parts.count >= 2, let first = parts[0].first, let second = parts[1].first {
            return "\(first)\(second)".uppercased()
        } else if let first = displayName.first {
            return "\(first)".uppercased()
        }
        return "C"
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
    public var needsPasswordChange: Bool { must_change_password == true }
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, full_name, role, avatar, trainer, status, created, must_change_password, color, avatar_initials
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.email = (try? container.decodeIfPresent(String.self, forKey: .email)) ?? ""
        self.name = try? container.decodeIfPresent(String.self, forKey: .name)
        self.full_name = try? container.decodeIfPresent(String.self, forKey: .full_name)
        self.role = try? container.decodeIfPresent(String.self, forKey: .role)
        self.avatar = try? container.decodeIfPresent(String.self, forKey: .avatar)
        self.trainer = try? container.decodeIfPresent(String.self, forKey: .trainer)
        self.status = try? container.decodeIfPresent(String.self, forKey: .status)
        self.created = try? container.decodeIfPresent(String.self, forKey: .created)
        self.must_change_password = try? container.decodeIfPresent(Bool.self, forKey: .must_change_password)
        self.color = try? container.decodeIfPresent(String.self, forKey: .color)
        self.avatar_initials = try? container.decodeIfPresent(String.self, forKey: .avatar_initials)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(full_name, forKey: .full_name)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(trainer, forKey: .trainer)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(created, forKey: .created)
        try container.encodeIfPresent(must_change_password, forKey: .must_change_password)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(avatar_initials, forKey: .avatar_initials)
    }
    
    public init(id: String, email: String, name: String? = nil, full_name: String? = nil, role: String? = "client", avatar: String? = nil, trainer: String? = nil, status: String? = "activo", created: String? = nil, must_change_password: Bool? = nil, color: String? = nil, avatar_initials: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.full_name = full_name
        self.role = role
        self.avatar = avatar
        self.trainer = trainer
        self.status = status
        self.created = created
        self.must_change_password = must_change_password
        self.color = color
        self.avatar_initials = avatar_initials
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, level, trainer, daysCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Rutina de entrenamiento"
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.level = try? container.decodeIfPresent(String.self, forKey: .level)
        self.trainer = try? container.decodeIfPresent(String.self, forKey: .trainer)
        self.daysCount = try? container.decodeIfPresent(Int.self, forKey: .daysCount)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encodeIfPresent(trainer, forKey: .trainer)
        try container.encodeIfPresent(daysCount, forKey: .daysCount)
    }
    
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
    
    enum CodingKeys: String, CodingKey {
        case id, routine, day_name, content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.routine = try? container.decodeIfPresent(String.self, forKey: .routine)
        self.day_name = try? container.decodeIfPresent(String.self, forKey: .day_name)
        self.content = try? container.decodeIfPresent(String.self, forKey: .content)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(routine, forKey: .routine)
        try container.encodeIfPresent(day_name, forKey: .day_name)
        try container.encodeIfPresent(content, forKey: .content)
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
    
    enum CodingKeys: String, CodingKey {
        case id, client, routine, active, expand
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.client = (try? container.decodeIfPresent(String.self, forKey: .client)) ?? ""
        self.routine = (try? container.decodeIfPresent(String.self, forKey: .routine)) ?? ""
        self.active = try? container.decodeIfPresent(Bool.self, forKey: .active)
        self.expand = try? container.decodeIfPresent(ClientRoutineExpand.self, forKey: .expand)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(client, forKey: .client)
        try container.encode(routine, forKey: .routine)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(expand, forKey: .expand)
    }
    
    public init(id: String, client: String, routine: String, active: Bool? = true, expand: ClientRoutineExpand? = nil) {
        self.id = id
        self.client = client
        self.routine = routine
        self.active = active
        self.expand = expand
    }
}

public struct ClientRoutineExpand: Codable, Sendable {
    public let routine: GymRoutine?
    
    enum CodingKeys: String, CodingKey {
        case routine
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.routine = try? container.decodeIfPresent(GymRoutine.self, forKey: .routine)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(routine, forKey: .routine)
    }
    
    public init(routine: GymRoutine? = nil) {
        self.routine = routine
    }
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


