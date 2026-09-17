import Foundation
import Security
import Observation

/// Errores posibles durante el análisis y la validación de un Deep Link.
public enum DeepLinkError: LocalizedError, Sendable {
    case invalidScheme
    case invalidHost
    case missingEndpoint
    case insecureEndpointHTTP
    case missingToken
    case keychainError(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .invalidScheme:
            return "El esquema del enlace no es válido. Debe ser 'aurasteps://'."
        case .invalidHost:
            return "La acción solicitada no es válida. Debe ser 'connect'."
        case .missingEndpoint:
            return "No se ha proporcionado una URL de destino (endpoint)."
        case .insecureEndpointHTTP:
            return "Rechazado por seguridad: El endpoint debe utilizar obligatoriamente el protocolo HTTPS."
        case .missingToken:
            return "Falta el token de autorización en el enlace de vinculación."
        case .keychainError(let status):
            return "Error de Keychain al guardar credenciales (código: \(status))."
        }
    }
}

/// Configuración de la plataforma externa vinculada.
public struct ConnectionConfig: Codable, Equatable, Sendable {
    public let endpoint: URL
    public let token: String
    public let appName: String
    public let dateConnected: Date
    
    public init(endpoint: URL, token: String, appName: String, dateConnected: Date = Date()) {
        self.endpoint = endpoint
        self.token = token
        self.appName = appName
        self.dateConnected = dateConnected
    }
}

/// Gestor principal para el procesamiento de Deep Links y el almacenamiento seguro de credenciales en Keychain.
@Observable
@MainActor
public final class DeepLinkManager {
    public var activeConfig: ConnectionConfig?
    public var pendingConfig: ConnectionConfig?
    public var isShowingConsentModal: Bool = false
    public var lastError: DeepLinkError?
    
    private let keychainService = "com.aurasteps.keychain"
    private let keychainAccount = "webhook_credentials"
    
    public init() {
        self.activeConfig = loadConfigFromKeychain()
    }
    
    /// Procesa una URL entrante (ej. aurasteps://connect?endpoint=https://gym.com/api&token=usr_98af21&app_name=GymPower)
    @discardableResult
    public func handleURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            self.lastError = .invalidScheme
            return false
        }
        
        guard components.scheme?.lowercased() == "aurasteps" else {
            self.lastError = .invalidScheme
            return false
        }
        
        guard components.host?.lowercased() == "connect" else {
            self.lastError = .invalidHost
            return false
        }
        
        let queryItems = components.queryItems ?? []
        
        guard let endpointString = queryItems.first(where: { $0.name == "endpoint" })?.value,
              let endpointURL = URL(string: endpointString) else {
            self.lastError = .missingEndpoint
            return false
        }
        
        // Verificación estricta ATS: Rechazo expreso de HTTP inseguro
        guard endpointURL.scheme?.lowercased() == "https" else {
            self.lastError = .insecureEndpointHTTP
            return false
        }
        
        guard let token = queryItems.first(where: { $0.name == "token" })?.value, !token.isEmpty else {
            self.lastError = .missingToken
            return false
        }
        
        let appName = queryItems.first(where: { $0.name == "app_name" })?.value ?? "Servidor Externo"
        
        let config = ConnectionConfig(endpoint: endpointURL, token: token, appName: appName)
        self.pendingConfig = config
        self.isShowingConsentModal = true
        self.lastError = nil
        return true
    }
    
    /// Aprueba la configuración pendiente presentada en el modal de consentimiento.
    public func confirmPendingConfig() {
        guard let config = pendingConfig else { return }
        if saveConfigToKeychain(config) {
            self.activeConfig = config
        }
        self.pendingConfig = nil
        self.isShowingConsentModal = false
    }
    
    /// Rechaza la vinculación pendiente.
    public func rejectPendingConfig() {
        self.pendingConfig = nil
        self.isShowingConsentModal = false
    }
    
    // MARK: - Operaciones de Keychain (Cifrado local sin servidor intermediario)
    
    private func saveConfigToKeychain(_ config: ConnectionConfig) -> Bool {
        guard let data = try? JSONEncoder().encode(config) else { return false }
        
        // Elimina cualquier credencial existente previa
        deleteKeychainConfig()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            // Guideline / Seguridad: Accesible solo tras el primer desbloqueo de este dispositivo
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            self.lastError = .keychainError(status)
            return false
        }
        return true
    }
    
    public func loadConfigFromKeychain() -> ConnectionConfig? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        return try? JSONDecoder().decode(ConnectionConfig.self, from: data)
    }
    
    /// Purga atómicamente las credenciales del Keychain (Guideline 5.1.1(v) - Derecho de Supresión).
    public func deleteKeychainConfig() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        self.activeConfig = nil
    }
}
