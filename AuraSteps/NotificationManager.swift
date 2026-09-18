import Foundation
import UserNotifications
import Combine

/// Gestor de notificaciones locales para recordatorios de actividad y progreso sin servidores externos (100% privado local).
@MainActor
public final class NotificationManager: ObservableObject {
    @Published public var isAuthorized: Bool = false
    @Published public var isDailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDailyReminderEnabled, forKey: "is_daily_reminder_enabled")
            scheduleNotificationsIfNeeded()
        }
    }
    @Published public var dailyReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyReminderTime.timeIntervalSince1970, forKey: "daily_reminder_time")
            scheduleNotificationsIfNeeded()
        }
    }
    
    public init() {
        let savedDaily = UserDefaults.standard.bool(forKey: "is_daily_reminder_enabled")
        let savedTimeInterval = UserDefaults.standard.double(forKey: "daily_reminder_time")
        
        self.isDailyReminderEnabled = savedDaily
        
        if savedTimeInterval > 0 {
            self.dailyReminderTime = Date(timeIntervalSince1970: savedTimeInterval)
        } else {
            // Hora por defecto: 20:00 (8 PM)
            var components = DateComponents()
            components.hour = 20
            components.minute = 0
            self.dailyReminderTime = Calendar.current.date(from: components) ?? Date()
        }
        
        checkAuthorizationStatus()
    }
    
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            if granted {
                scheduleNotificationsIfNeeded()
            }
            return granted
        } catch {
            print("Error solicitando permisos de notificación: \(error.localizedDescription)")
            self.isAuthorized = false
            return false
        }
    }
    
    public func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private var lastKnownSteps: Int = 0
    private var lastKnownGoal: Int = 10000
    
    private let motivationalMessages: [(title: String, body: String)] = [
        ("👟 ¡Momento de caminar!", "Cada paso cuenta para tu bienestar y energía. ¿Cuánto te falta hoy para tu objetivo?"),
        ("🔥 ¡Mantén tu racha activa!", "Consulta tus pasos de hoy en AuraSteps y no dejes que se apague tu racha."),
        ("🚶‍♂️ Desconecta y camina", "Un paseo de unos minutos te ayuda a despejar la mente y sumar actividad a tu día."),
        ("💪 ¡A por tu meta diaria!", "Revisa tu progreso en AuraSteps. ¡Un último paseo antes de que termine el día!"),
        ("🌟 Activa tu cuerpo", "Una breve caminata al aire libre o por casa te llenará de vitalidad. ¡A por ello!"),
        ("⚡ ¡Ponte en marcha!", "Levántate, estira las piernas y suma unos cuantos pasos más a tu total de hoy."),
        ("🎯 ¿Cómo va tu objetivo?", "Abre AuraSteps y comprueba lo cerca que estás de cumplir tu meta de pasos de hoy.")
    ]
    
    public func scheduleNotificationsIfNeeded(currentSteps: Int? = nil, goalSteps: Int? = nil) {
        if let steps = currentSteps { self.lastKnownSteps = steps }
        if let goal = goalSteps { self.lastKnownGoal = goal }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard isAuthorized else { return }
        
        if isDailyReminderEnabled {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: dailyReminderTime)
            guard let hour = timeComponents.hour, let minute = timeComponents.minute else { return }
            
            // Programar una notificación para cada día de la semana (1 = domingo, ..., 7 = sábado)
            // de modo que cada día muestre un mensaje motivacional rotativo distinto a la hora configurada.
            for weekday in 1...7 {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                
                let messageIndex = (weekday - 1) % motivationalMessages.count
                let message = motivationalMessages[messageIndex]
                
                let content = UNMutableNotificationContent()
                content.title = message.title
                content.body = message.body
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "aurasteps_daily_reminder_weekday_\(weekday)",
                    content: content,
                    trigger: trigger
                )
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    public func sendAchievementNotification(title: String, body: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
