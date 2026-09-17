import Foundation
import Observation

/// Payload público estandarizado para la exportación directa iPhone -> Servidor Tercero.
public struct WebhookPayload: Codable, Sendable {
    public let event: String
    public let clientToken: String
    public let deviceTimestamp: String
    public let timezone: String
    public let today: TodayMetricsPayload
    public let weeklySummary: [WeeklyDayPayload]
    
    enum CodingKeys: String, CodingKey {
        case event
        case clientToken = "client_token"
        case deviceTimestamp = "device_timestamp"
        case timezone
        case today
        case weeklySummary = "weekly_summary"
    }
}

public struct TodayMetricsPayload: Codable, Sendable {
    public let date: String
    public let steps: Int
    public let goal: Int
    public let distanceKm: Double
    public let caloriesBurnedKcal: Int
    public let floorsClimbed: Int
    public let activeMinutes: Int
    public let hourlySteps: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case goal
        case distanceKm = "distance_km"
        case caloriesBurnedKcal = "calories_burned_kcal"
        case floorsClimbed = "floors_climbed"
        case activeMinutes = "active_minutes"
        case hourlySteps = "hourly_steps"
    }
}

public struct WeeklyDayPayload: Codable, Sendable {
    public let date: String
    public let steps: Int
    public let distanceKm: Double
    
    enum CodingKeys: String, CodingKey {
        case date
        case steps
        case distanceKm = "distance_km"
    }
}

/// Estado de la última sincronización.
public enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success(Date)
    case failed(String)
}

/// Despachador de webhook descentralizado con rate limiting de cliente y manejo de errores HTTP.
@Observable
@MainActor
public final class WebhookDispatcher {
    public var status: SyncStatus = .idle
    public var lastSyncDate: Date?
    public var lastHttpStatusCode: Int?
    public var isSyncing: Bool = false
    
    private let minimumIntervalSeconds: TimeInterval = 900 // 15 minutos mínimo entre ráfagas automáticas
    private var backoffFactor: Double = 1.0
    
    public init() {}
    
    /// Ejecuta el despacho de métricas respetando el rate limit a menos que sea una prueba manual (ping).
    public func dispatchMetrics(
        config: ConnectionConfig,
        motionManager: StepMotionManager,
        isManualPing: Bool = false
    ) async -> Bool {
        // Verificar Rate Limiting si es un despacho automático
        if !isManualPing, let lastSync = lastSyncDate {
            let elapsed = Date().timeIntervalSince(lastSync)
            let requiredInterval = minimumIntervalSeconds * backoffFactor
            if elapsed < requiredInterval {
                print("WebhookDispatcher: Rate limit activo. Próxima transmisión permitida en \(Int(requiredInterval - elapsed)) segundos.")
                return false
            }
        }
        
        self.isSyncing = true
        self.status = .syncing
        
        // Construir Payload
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let timestamp = isoFormatter.string(from: Date())
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let todayDateString = dayFormatter.string(from: Date())
        
        let todayPayload = TodayMetricsPayload(
            date: todayDateString,
            steps: motionManager.todaySteps,
            goal: motionManager.todayGoal,
            distanceKm: motionManager.todayDistanceKm,
            caloriesBurnedKcal: motionManager.todayCaloriesKcal,
            floorsClimbed: motionManager.todayFloors,
            activeMinutes: motionManager.todayActiveMinutes,
            hourlySteps: motionManager.hourlySteps
        )
        
        let weeklyPayload = motionManager.weeklySummary.map { summary in
            WeeklyDayPayload(
                date: summary.dateString,
                steps: summary.steps,
                distanceKm: summary.distanceKm
            )
        }
        
        let payload = WebhookPayload(
            event: "aurasteps_sync",
            clientToken: config.token,
            deviceTimestamp: timestamp,
            timezone: TimeZone.current.identifier,
            today: todayPayload,
            weeklySummary: weeklyPayload
        )
        
        guard let jsonData = try? JSONEncoder().encode(payload) else {
            self.status = .failed("Error codificando payload JSON")
            self.isSyncing = false
            return false
        }
        
        // Preparar Solicitud HTTP POST
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AuraSteps-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = jsonData
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                self.status = .failed("Respuesta no válida del servidor")
                self.isSyncing = false
                return false
            }
            
            self.lastHttpStatusCode = httpResponse.statusCode
            
            if (200...299).contains(httpResponse.statusCode) {
                // Éxito: Restablecer el factor de backoff
                self.backoffFactor = 1.0
                let syncTime = Date()
                self.lastSyncDate = syncTime
                self.status = .success(syncTime)
                self.isSyncing = false
                return true
            } else if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                // Error de Rate Limit o Servidor: Retroceso Exponencial (hasta 4x)
                self.backoffFactor = min(self.backoffFactor * 2.0, 4.0)
                let errorMsg = "Servidor devolvió código HTTP \(httpResponse.statusCode). Retroceso incremental aplicado."
                self.status = .failed(errorMsg)
                self.isSyncing = false
                return false
            } else {
                let errorMsg = "Error HTTP \(httpResponse.statusCode)"
                self.status = .failed(errorMsg)
                self.isSyncing = false
                return false
            }
        } catch {
            self.status = .failed("Error de red: \(error.localizedDescription)")
            self.isSyncing = false
            return false
        }
    }
}
