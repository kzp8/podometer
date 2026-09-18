import Foundation
import Combine

/// Estructura que representa un logro o insignia en AuraSteps.
public struct Achievement: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let iconName: String
    public let category: String
    public var isUnlocked: Bool
    public var unlockedDate: Date?
    
    public init(id: String, title: String, description: String, iconName: String, category: String, isUnlocked: Bool = false, unlockedDate: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.category = category
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
    }
}

/// Gestor de logros, insignias unlocked y cálculo de racha diaria de pasos con Días Congelados (100% local).
@MainActor
public final class AchievementsManager: ObservableObject {
    @Published public var currentStreakDays: Int = 0
    @Published public var bestStreakDays: Int = 0
    @Published public var streakFreezesAvailable: Int = 1
    @Published public var achievements: [Achievement] = []
    
    private let achievementsStorageKey = "aurasteps_unlocked_achievements"
    private let currentStreakStorageKey = "aurasteps_current_streak_days"
    private let bestStreakStorageKey = "aurasteps_best_streak_days"
    private let streakFreezesStorageKey = "aurasteps_streak_freezes_available"
    private let lastFreezeWeekStorageKey = "aurasteps_last_freeze_week_year"
    private let lastEvaluatedDateStorageKey = "aurasteps_last_evaluated_date"
    private let frozenDatesStorageKey = "aurasteps_frozen_dates"
    
    private var lastStreakFreezeWeekYear: String = ""
    private var lastEvaluatedDateString: String = ""
    private var frozenDateStrings: Set<String> = []
    
    public init() {
        self.currentStreakDays = UserDefaults.standard.integer(forKey: currentStreakStorageKey)
        self.bestStreakDays = UserDefaults.standard.integer(forKey: bestStreakStorageKey)
        
        if UserDefaults.standard.object(forKey: streakFreezesStorageKey) != nil {
            self.streakFreezesAvailable = UserDefaults.standard.integer(forKey: streakFreezesStorageKey)
        } else {
            self.streakFreezesAvailable = 1
        }
        
        self.lastStreakFreezeWeekYear = UserDefaults.standard.string(forKey: lastFreezeWeekStorageKey) ?? ""
        self.lastEvaluatedDateString = UserDefaults.standard.string(forKey: lastEvaluatedDateStorageKey) ?? ""
        if let savedFrozen = UserDefaults.standard.stringArray(forKey: frozenDatesStorageKey) {
            self.frozenDateStrings = Set(savedFrozen)
        }
        
        setupDefaultAchievements()
        loadUnlockedAchievements()
        checkWeeklyStreakFreezeReset()
    }
    
    private func setupDefaultAchievements() {
        self.achievements = [
            Achievement(id: "first_steps", title: "Primeros Pasos", description: "Completa 1.000 pasos en un solo día", iconName: "figure.walk", category: "Pasos"),
            Achievement(id: "goal_reached", title: "Meta Cumplida", description: "Alcanza tu objetivo diario de pasos", iconName: "checkmark.seal.fill", category: "Pasos"),
            Achievement(id: "streak_3", title: "En Marcha (3 días)", description: "Cumple tu meta diaria durante 3 días seguidos", iconName: "flame.fill", category: "Rachas"),
            Achievement(id: "streak_7", title: "Imparable (7 días)", description: "Cumple tu meta diaria durante 7 días seguidos", iconName: "crown.fill", category: "Rachas"),
            Achievement(id: "elite_walker", title: "Caminante de Élite", description: "Supera los 15.000 pasos en un solo día", iconName: "shoeprints.fill", category: "Pasos"),
            Achievement(id: "climber", title: "Escalador Urbano", description: "Sube más de 10 pisos en un solo día", iconName: "building.2.fill", category: "Pisos"),
            Achievement(id: "marathoner", title: "Maratoniano", description: "Supera los 42 km de distancia total recorrida", iconName: "map.fill", category: "Distancia")
        ]
    }
    
    private func loadUnlockedAchievements() {
        guard let data = UserDefaults.standard.data(forKey: achievementsStorageKey),
              let unlockedDict = try? JSONDecoder().decode([String: Date].self, from: data) else { return }
        
        for i in 0..<achievements.count {
            if let date = unlockedDict[achievements[i].id] {
                achievements[i].isUnlocked = true
                achievements[i].unlockedDate = date
            }
        }
    }
    
    private func saveUnlockedAchievements() {
        var unlockedDict: [String: Date] = [:]
        for item in achievements where item.isUnlocked {
            unlockedDict[item.id] = item.unlockedDate ?? Date()
        }
        if let data = try? JSONEncoder().encode(unlockedDict) {
            UserDefaults.standard.set(data, forKey: achievementsStorageKey)
        }
    }
    
    public func checkWeeklyStreakFreezeReset() {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let week = calendar.component(.weekOfYear, from: now)
        let currentWeekKey = "\(year)-\(week)"
        
        if lastStreakFreezeWeekYear.isEmpty {
            lastStreakFreezeWeekYear = currentWeekKey
            streakFreezesAvailable = 1
            saveStreakFreezeData()
        } else if lastStreakFreezeWeekYear != currentWeekKey {
            // Nueva semana: recargar 1 día congelado semanal (máximo 1 disponible)
            lastStreakFreezeWeekYear = currentWeekKey
            streakFreezesAvailable = 1
            saveStreakFreezeData()
        }
    }
    
    private func saveStreakFreezeData() {
        UserDefaults.standard.set(streakFreezesAvailable, forKey: streakFreezesStorageKey)
        UserDefaults.standard.set(lastStreakFreezeWeekYear, forKey: lastFreezeWeekStorageKey)
        UserDefaults.standard.set(lastEvaluatedDateString, forKey: lastEvaluatedDateStorageKey)
        UserDefaults.standard.set(Array(frozenDateStrings), forKey: frozenDatesStorageKey)
    }
    
    /// Evalúa el progreso actual del usuario y desbloquea insignias de forma automática.
    public func evaluateProgress(steps: Int, goal: Int, floors: Int, totalDistanceKm: Double, notificationManager: NotificationManager? = nil) {
        var newlyUnlockedTitle: String? = nil
        
        // 1. Primeros pasos
        if steps >= 1000 {
            newlyUnlockedTitle = unlockIfNeeded(id: "first_steps") ?? newlyUnlockedTitle
        }
        
        // 2. Meta alcanzada
        if steps >= goal && goal > 0 {
            newlyUnlockedTitle = unlockIfNeeded(id: "goal_reached") ?? newlyUnlockedTitle
        }
        
        // 3. Caminante de elite
        if steps >= 15000 {
            newlyUnlockedTitle = unlockIfNeeded(id: "elite_walker") ?? newlyUnlockedTitle
        }
        
        // 4. Escalador
        if floors >= 10 {
            newlyUnlockedTitle = unlockIfNeeded(id: "climber") ?? newlyUnlockedTitle
        }
        
        // 5. Maratoniano
        if totalDistanceKm >= 42.2 {
            newlyUnlockedTitle = unlockIfNeeded(id: "marathoner") ?? newlyUnlockedTitle
        }
        
        // 6. Rachas
        if currentStreakDays >= 3 {
            newlyUnlockedTitle = unlockIfNeeded(id: "streak_3") ?? newlyUnlockedTitle
        }
        if currentStreakDays >= 7 {
            newlyUnlockedTitle = unlockIfNeeded(id: "streak_7") ?? newlyUnlockedTitle
        }
        
        if let title = newlyUnlockedTitle {
            notificationManager?.sendAchievementNotification(
                title: "🏆 ¡Nuevo Logro Desbloqueado!",
                body: "¡Felicidades! Has conseguido la insignia '\(title)'."
            )
        }
    }
    
    private func unlockIfNeeded(id: String) -> String? {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return nil }
        if !achievements[index].isUnlocked {
            achievements[index].isUnlocked = true
            achievements[index].unlockedDate = Date()
            saveUnlockedAchievements()
            return achievements[index].title
        }
        return nil
    }
    
    /// Evalúa el cambio de día y gestiona automáticamente los Días Congelados y avisos si no se cumplió la meta del día anterior.
    public func updateStreak(weeklySummary: [DailySummary], goal: Int, notificationManager: NotificationManager? = nil) {
        checkWeeklyStreakFreezeReset()
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            updateStreakWithFreezes(weeklySummary: weeklySummary, goal: goal)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let yesterdayStr = formatter.string(from: yesterday)
        let todayStr = formatter.string(from: today)
        
        // Comprobar si el día de ayer necesita ser procesado por primera vez
        if lastEvaluatedDateString != yesterdayStr && lastEvaluatedDateString != todayStr {
            if let yesterdaySummary = weeklySummary.first(where: { $0.dateString == yesterdayStr }) {
                if yesterdaySummary.steps >= goal {
                    // Meta cumplida ayer sin problemas
                    lastEvaluatedDateString = yesterdayStr
                    saveStreakFreezeData()
                } else {
                    // Ayer NO se cumplieron los pasos
                    if streakFreezesAvailable > 0 {
                        // Consumir Día Congelado semanal y notificar
                        streakFreezesAvailable -= 1
                        frozenDateStrings.insert(yesterdayStr)
                        lastEvaluatedDateString = yesterdayStr
                        saveStreakFreezeData()
                        
                        notificationManager?.sendAchievementNotification(
                            title: "🛡️ ¡Día Congelado Utilizado!",
                            body: "Ayer no alcanzaste tu objetivo de pasos, pero tu racha de \(currentStreakDays) días sigue intacta gracias a tu Día Congelado semanal. Te quedan 0 congelados esta semana."
                        )
                    } else {
                        // Sin Días Congelados: reinicio de racha y notificación
                        lastEvaluatedDateString = yesterdayStr
                        saveStreakFreezeData()
                        
                        notificationManager?.sendAchievementNotification(
                            title: "💔 Racha Interrumpida",
                            body: "Ayer no alcanzaste tu meta diaria y no tenías Días Congelados disponibles. ¡Tu racha se ha reiniciado! Hoy es un buen día para volver a empezar."
                        )
                    }
                }
            }
        }
        
        updateStreakWithFreezes(weeklySummary: weeklySummary, goal: goal)
    }
    
    private func updateStreakWithFreezes(weeklySummary: [DailySummary], goal: Int) {
        var streak = 0
        let reversedDays = weeklySummary.reversed()
        let calendar = Calendar.current
        
        for day in reversedDays {
            if day.steps >= goal || frozenDateStrings.contains(day.dateString) {
                streak += 1
            } else {
                // Si es el día actual y aún está transcurriendo, no rompe la racha de días anteriores
                if calendar.isDateInToday(day.date) {
                    continue
                }
                break
            }
        }
        
        self.currentStreakDays = streak
        if streak > bestStreakDays {
            self.bestStreakDays = streak
            UserDefaults.standard.set(bestStreakDays, forKey: bestStreakStorageKey)
        }
        UserDefaults.standard.set(currentStreakDays, forKey: currentStreakStorageKey)
    }
    
    public func resetAchievements() {
        currentStreakDays = 0
        bestStreakDays = 0
        streakFreezesAvailable = 1
        lastStreakFreezeWeekYear = ""
        lastEvaluatedDateString = ""
        frozenDateStrings.removeAll()
        
        UserDefaults.standard.removeObject(forKey: currentStreakStorageKey)
        UserDefaults.standard.removeObject(forKey: bestStreakStorageKey)
        UserDefaults.standard.removeObject(forKey: achievementsStorageKey)
        UserDefaults.standard.removeObject(forKey: streakFreezesStorageKey)
        UserDefaults.standard.removeObject(forKey: lastFreezeWeekStorageKey)
        UserDefaults.standard.removeObject(forKey: lastEvaluatedDateStorageKey)
        UserDefaults.standard.removeObject(forKey: frozenDatesStorageKey)
        
        setupDefaultAchievements()
    }
}
