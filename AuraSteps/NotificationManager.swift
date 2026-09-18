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
    @Published public var isInactivityReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isInactivityReminderEnabled, forKey: "is_inactivity_reminder_enabled")
            scheduleNotificationsIfNeeded()
        }
    }
    
    public init() {
        let savedDaily = UserDefaults.standard.bool(forKey: "is_daily_reminder_enabled")
        let savedInactivity = UserDefaults.standard.bool(forKey: "is_inactivity_reminder_enabled")
        let savedTimeInterval = UserDefaults.standard.double(forKey: "daily_reminder_time")
        
        self.isDailyReminderEnabled = savedDaily
        self.isInactivityReminderEnabled = savedInactivity
        
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
    
    public func scheduleNotificationsIfNeeded(currentSteps: Int? = nil, goalSteps: Int? = nil) {
        if let steps = currentSteps { self.lastKnownSteps = steps }
        if let goal = goalSteps { self.lastKnownGoal = goal }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard isAuthorized else { return }
        
        let stepsText = "\(lastKnownSteps) de \(lastKnownGoal)"
        
        if isDailyReminderEnabled {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: dailyReminderTime)
            
            let content = UNMutableNotificationContent()
            content.title = "👟 Resumen de Pasos AuraSteps"
            if lastKnownSteps >= lastKnownGoal {
                content.body = "¡Enhorabuena! Has alcanzado tu objetivo con \(stepsText) pasos hoy 🎉"
            } else {
                content.body = "Llevas \(stepsText) pasos hoy. ¡Sigue así para alcanzar tu meta!"
            }
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "aurasteps_daily_reminder", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
        
        if isInactivityReminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "🚶‍♂️ ¡Hora de Moverse!"
            content.body = "Llevas \(stepsText) pasos hoy. ¡Da un paseo de 5 minutos para seguir sumando!"
            content.sound = .default
            
            // Recordatorios de inactividad programados exclusivamente en horario diurno (de 10:00 a 22:00 cada 2 horas)
            let activeHours = [10, 12, 14, 16, 18, 20, 22]
            for hour in activeHours {
                var components = DateComponents()
                components.hour = hour
                components.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "aurasteps_inactivity_reminder_\(hour)",
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
