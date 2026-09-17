import Foundation
import CoreMotion
import HealthKit
import Combine

/// Estructura que representa la métrica resumida de un día específico.
public struct DailySummary: Identifiable, Codable, Sendable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String // Formato YYYY-MM-DD
    public let steps: Int
    public let distanceKm: Double
    public let caloriesKcal: Int
    public let activeMinutes: Int
    public let floorsClimbed: Int
    
    public init(date: Date, steps: Int, distanceKm: Double, caloriesKcal: Int = 0, activeMinutes: Int = 0, floorsClimbed: Int = 0) {
        self.date = date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateString = formatter.string(from: date)
        self.steps = steps
        self.distanceKm = distanceKm
        self.caloriesKcal = caloriesKcal
        self.activeMinutes = activeMinutes
        self.floorsClimbed = floorsClimbed
    }
}

/// Gestor principal del podómetro en tiempo real con CoreMotion y HealthKit.
/// Diseñado para máxima eficiencia energética y compatible con iOS 16.0+.
@MainActor
public final class StepMotionManager: ObservableObject {
    // MARK: - Propiedades de Estado Publicadas (iOS 16+)
    @Published public var todaySteps: Int = 0
    @Published public var todayGoal: Int = 10000
    @Published public var todayDistanceKm: Double = 0.0
    @Published public var todayCaloriesKcal: Int = 0
    @Published public var todayFloors: Int = 0
    @Published public var todayActiveMinutes: Int = 0
    @Published public var hourlySteps: [String: Int] = [:]
    @Published public var weeklySummary: [DailySummary] = []
    
    @Published public var isLiveTracking: Bool = false
    @Published public var isHealthKitAuthorized: Bool = false
    @Published public var isDemoMode: Bool = false
    @Published public var errorMessage: String? = nil
    
    // MARK: - Componentes Privados
    private let pedometer = CMPedometer()
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    
    public init() {
        #if targetEnvironment(simulator)
        self.isDemoMode = true
        loadDemoData()
        #endif
    }
    
    // MARK: - Control de Seguimiento en Vivo (CoreMotion)
    
    /// Inicia la lectura del podómetro en tiempo real (invocado cuando ScenePhase == .active).
    public func startLiveTracking() {
        guard !isDemoMode else {
            loadDemoData()
            isLiveTracking = true
            return
        }
        
        guard CMPedometer.isStepCountingAvailable() else {
            errorMessage = "El conteo de pasos no está disponible en este dispositivo."
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        isLiveTracking = true
        
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = "Error de CoreMotion: \(error.localizedDescription)"
                    self.isLiveTracking = false
                    return
                }
                
                if let data = data {
                    self.todaySteps = data.numberOfSteps.intValue
                    if let distance = data.distance?.doubleValue {
                        self.todayDistanceKm = (distance / 1000.0 * 100).rounded() / 100
                    }
                    if let floors = data.floorsAscended?.intValue {
                        self.todayFloors = floors
                    }
                    self.todayActiveMinutes = max(1, self.todaySteps / 100)
                    self.todayCaloriesKcal = Int(Double(self.todaySteps) * 0.04)
                }
            }
        }
    }
    
    /// Detiene inmediatamente los updates del coprocesador para conservar batería (invocado en background/inactive).
    public func stopLiveTracking() {
        guard !isDemoMode else {
            isLiveTracking = false
            return
        }
        pedometer.stopUpdates()
        isLiveTracking = false
    }
    
    // MARK: - Integración y Consolidación con HealthKit
    
    /// Solicita permisos de HealthKit para lectura de métricas deportivas básicas.
    public func requestHealthKitAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.errorMessage = "HealthKit no está disponible en este dispositivo."
            return
        }
        
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            self.isHealthKitAuthorized = true
            await fetchTodayHealthKitData()
            await fetchWeeklySummaryFromHealthKit()
            setupBackgroundDelivery()
        } catch {
            self.errorMessage = "Autorización de HealthKit denegada: \(error.localizedDescription)"
        }
    }
    
    /// Carga las métricas del día actual desde HealthKit.
    public func fetchTodayHealthKitData() async {
        guard isHealthKitAuthorized && !isDemoMode else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            Task { @MainActor [weak self] in
                guard let self = self, let result = result, let sum = result.sumQuantity() else { return }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                if steps > self.todaySteps {
                    self.todaySteps = steps
                }
            }
        }
        healthStore.execute(query)
        await fetchHourlySteps()
    }
    
    /// Obtiene el desglose por horas del día actual.
    private func fetchHourlySteps() async {
        guard isHealthKitAuthorized && !isDemoMode else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let interval = DateComponents(hour: 1)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, results, error in
            Task { @MainActor [weak self] in
                guard let self = self, let results = results else { return }
                var hourlyDict: [String: Int] = [:]
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:00"
                
                results.enumerateStatistics(from: startOfDay, to: now) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let key = timeFormatter.string(from: statistics.startDate)
                        let steps = Int(sum.doubleValue(for: HKUnit.count()))
                        if steps > 0 {
                            hourlyDict[key] = steps
                        }
                    }
                }
                self.hourlySteps = hourlyDict
            }
        }
        healthStore.execute(query)
    }
    
    /// Consolida el historial de los últimos 7 días.
    public func fetchWeeklySummaryFromHealthKit() async {
        guard isHealthKitAuthorized && !isDemoMode else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return }
        let interval = DateComponents(day: 1)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: now),
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, results, error in
            Task { @MainActor [weak self] in
                guard let self = self, let results = results else { return }
                var summaries: [DailySummary] = []
                
                results.enumerateStatistics(from: sevenDaysAgo, to: now) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                    let distanceKm = (Double(steps) * 0.00075 * 100).rounded() / 100
                    let summary = DailySummary(
                        date: statistics.startDate,
                        steps: steps,
                        distanceKm: distanceKm,
                        caloriesKcal: Int(Double(steps) * 0.04),
                        activeMinutes: max(0, steps / 110),
                        floorsClimbed: max(0, steps / 750)
                    )
                    summaries.append(summary)
                }
                self.weeklySummary = summaries
            }
        }
        healthStore.execute(query)
    }
    
    /// Habilita las notificaciones en segundo plano cuando HealthKit detecte nuevos pasos.
    private func setupBackgroundDelivery() {
        guard isHealthKitAuthorized, let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { success, error in
            if let error = error {
                print("Error habilitando background delivery de HealthKit: \(error.localizedDescription)")
            }
        }
        
        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            Task { @MainActor [weak self] in
                await self?.fetchTodayHealthKitData()
                completionHandler()
            }
        }
        self.observerQuery = observer
        healthStore.execute(observer)
    }
    
    // MARK: - Guideline 2.1: Modo Demo/Mock para Revisores de Apple
    
    public func toggleDemoMode(_ enabled: Bool) {
        self.isDemoMode = enabled
        if enabled {
            loadDemoData()
        } else {
            todaySteps = 0
            todayDistanceKm = 0.0
            todayCaloriesKcal = 0
            todayFloors = 0
            todayActiveMinutes = 0
            hourlySteps = [:]
            weeklySummary = []
        }
    }
    
    public func loadDemoData() {
        self.todaySteps = 8420
        self.todayGoal = 10000
        self.todayDistanceKm = 6.12
        self.todayCaloriesKcal = 340
        self.todayFloors = 12
        self.todayActiveMinutes = 58
        
        self.hourlySteps = [
            "07:00": 420,
            "08:00": 1200,
            "09:00": 1850,
            "10:00": 950,
            "11:00": 600,
            "12:00": 1100,
            "13:00": 800,
            "14:00": 1500
        ]
        
        let calendar = Calendar.current
        let today = Date()
        
        var demoSummaries: [DailySummary] = []
        let pastSteps = [9200, 10400, 7800, 11500, 8900, 10100, 8420]
        
        for (index, steps) in pastSteps.enumerated() {
            let offset = index - 6
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let dist = (Double(steps) * 0.00075 * 100).rounded() / 100
                demoSummaries.append(DailySummary(
                    date: date,
                    steps: steps,
                    distanceKm: dist,
                    caloriesKcal: Int(Double(steps) * 0.04),
                    activeMinutes: max(30, steps / 120),
                    floorsClimbed: Int.random(in: 5...15)
                ))
            }
        }
        self.weeklySummary = demoSummaries
    }
    
    public func clearAllData() {
        todaySteps = 0
        todayDistanceKm = 0.0
        todayCaloriesKcal = 0
        todayFloors = 0
        todayActiveMinutes = 0
        hourlySteps = [:]
        weeklySummary = []
        isLiveTracking = false
    }
}
