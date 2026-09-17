import Foundation
import Combine

/// Gestor de parámetros antropométricos y preferencias personales del usuario (iOS 16+).
@MainActor
public final class UserSettingsManager: ObservableObject {
    @Published public var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "has_completed_onboarding")
        }
    }
    
    @Published public var weightKg: Double {
        didSet {
            UserDefaults.standard.set(weightKg, forKey: "user_weight_kg")
        }
    }
    
    @Published public var heightCm: Double {
        didSet {
            UserDefaults.standard.set(heightCm, forKey: "user_height_cm")
            if isAutoStepLength {
                autoCalculateStepLength()
            }
        }
    }
    
    @Published public var stepLengthMeters: Double {
        didSet {
            UserDefaults.standard.set(stepLengthMeters, forKey: "user_step_length_meters")
        }
    }
    
    @Published public var isAutoStepLength: Bool {
        didSet {
            UserDefaults.standard.set(isAutoStepLength, forKey: "user_auto_step_length")
            if isAutoStepLength {
                autoCalculateStepLength()
            }
        }
    }
    
    public init() {
        let savedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        let savedWeight = UserDefaults.standard.double(forKey: "user_weight_kg")
        let savedHeight = UserDefaults.standard.double(forKey: "user_height_cm")
        let savedStepLength = UserDefaults.standard.double(forKey: "user_step_length_meters")
        let hasAutoSet = UserDefaults.standard.object(forKey: "user_auto_step_length") != nil
        
        self.hasCompletedOnboarding = savedOnboarding
        self.weightKg = savedWeight > 0 ? savedWeight : 70.0
        self.heightCm = savedHeight > 0 ? savedHeight : 175.0
        self.isAutoStepLength = hasAutoSet ? UserDefaults.standard.bool(forKey: "user_auto_step_length") : true
        
        if savedStepLength > 0 && !hasAutoSet {
            self.stepLengthMeters = savedStepLength
        } else {
            self.stepLengthMeters = (savedHeight > 0 ? savedHeight : 175.0) * 0.414 / 100.0
        }
    }
    
    /// Calcula automáticamente la longitud media de paso basada en la altura del usuario (Fórmula biométrica: altura * 0.414).
    public func autoCalculateStepLength() {
        let calculated = (heightCm * 0.414) / 100.0
        self.stepLengthMeters = (calculated * 100).rounded() / 100.0
    }
    
    /// Calcula la distancia recorrida exacta en kilómetros en función de los pasos y la longitud de paso actual.
    public func calculateDistanceKm(forSteps steps: Int) -> Double {
        let meters = Double(steps) * stepLengthMeters
        return (meters / 1000.0 * 100).rounded() / 100.0
    }
    
    /// Estima las calorías quemadas (kcal) basándose en los pasos y el peso real del usuario.
    /// Fórmula metabólica: Calorías = Pasos * Peso(kg) * 0.00057
    public func calculateCaloriesKcal(forSteps steps: Int) -> Int {
        let caloriesPerStep = weightKg * 0.00057
        return Int(Double(steps) * caloriesPerStep)
    }
    
    public func resetToDefaults() {
        self.hasCompletedOnboarding = false
        self.weightKg = 70.0
        self.heightCm = 175.0
        self.isAutoStepLength = true
        autoCalculateStepLength()
    }
}
