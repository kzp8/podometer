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

/// Gestor de logros, insignias unlocked y cálculo de racha diaria de pasos (100% local).
@MainActor
public final class AchievementsManager: ObservableObject {
    @Published public var currentStreakDays: Int = 0
    @Published public var bestStreakDays: Int = 0
    @Published public var achievements: [Achievement] = []
    
    private let achievementsStorageKey = "aurasteps_unlocked_achievements"
    private let currentStreakStorageKey = "aurasteps_current_streak_days"
    private let bestStreakStorageKey = "aurasteps_best_streak_days"
    
    public init() {
        self.currentStreakDays = UserDefaults.standard.integer(forKey: currentStreakStorageKey)
        self.bestStreakDays = UserDefaults.standard.integer(forKey: bestStreakStorageKey)
        setupDefaultAchievements()
        loadUnlockedAchievements()
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
    
    public func updateStreak(weeklySummary: [DailySummary], goal: Int) {
        // Calcular racha actual analizando días consecutivos anteriores donde se cumplió la meta
        var streak = 0
        let reversedDays = weeklySummary.reversed()
        
        for day in reversedDays {
            if day.steps >= goal {
                streak += 1
            } else {
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
        UserDefaults.standard.removeObject(forKey: currentStreakStorageKey)
        UserDefaults.standard.removeObject(forKey: bestStreakStorageKey)
        UserDefaults.standard.removeObject(forKey: achievementsStorageKey)
        setupDefaultAchievements()
    }
}
