import SwiftUI
import Charts

/// Vista principal Dashboard con anillo animado, métricas interactivas y selector de historial (Día/Semana/Mes) con desglose hora por hora.
struct DashboardView: View {
    @EnvironmentObject private var motionManager: StepMotionManager
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var animatedProgress: Double = 0.0
    @State private var showActiveTimeInfo: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        if motionManager.isDemoMode {
                            demoBannerView
                        }
                        
                        stepRingCardView
                        metricsGridView
                        historyInteractiveSectionView
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("AuraSteps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    demoButton
                }
            }
            .alert("¿Qué es el Tiempo Activo?", isPresented: $showActiveTimeInfo) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("El Tiempo Activo mide los minutos acumulados en los que te has desplazado continuamente a una cadencia de caminata o carrera (>30 pasos/min). No cuenta el tiempo que estás de pie sin desplazarte.")
            }
            .onAppear {
                updateProgressAnimation()
                motionManager.startLiveTracking()
                Task {
                    await motionManager.fetchHistoryForSelectedDate()
                }
            }
            .onChange(of: motionManager.todaySteps) { _ in
                updateProgressAnimation()
            }
            .onChange(of: motionManager.selectedHistoryDate) { _ in
                Task {
                    await motionManager.fetchHistoryForSelectedDate()
                }
            }
            .onChange(of: motionManager.selectedHistoryPeriod) { _ in
                Task {
                    await motionManager.fetchHistoryForSelectedDate()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    motionManager.startLiveTracking()
                } else if newPhase == .background || newPhase == .inactive {
                    motionManager.stopLiveTracking()
                }
            }
        }
    }
    
    // MARK: - Subvistas
    
    private var demoBannerView: some View {
        HStack {
            Image(systemName: "flask.fill")
            Text("Modo Demostración Activo")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.black)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(themeManager.accentColor)
        .cornerRadius(20)
        .padding(.top, 4)
    }
    
    private var stepRingCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(themeManager.cardColor)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 18)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [themeManager.accentColor.opacity(0.6), themeManager.accentColor]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)
                        .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, x: 0, y: 0)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(themeManager.accentColor)
                        
                        Text("\(motionManager.todaySteps)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("de \(motionManager.todayGoal) pasos")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 16)
                
                HStack(spacing: 12) {
                    Text("\(Int(progressRatio * 100))% del objetivo diario")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
                .padding(.bottom, 8)
            }
            .padding(20)
        }
        .padding(.horizontal)
    }
    
    private var metricsGridView: some View {
        let currentDist = userSettings.calculateDistanceKm(forSteps: motionManager.todaySteps)
        let currentCal = userSettings.calculateCaloriesKcal(forSteps: motionManager.todaySteps)
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(
                title: "Distancia",
                value: String(format: "%.2f km", currentDist),
                icon: "map.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor
            )
            
            MetricCard(
                title: "Calorías",
                value: "\(currentCal) kcal",
                icon: "flame.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor
            )
            
            MetricCard(
                title: "Pisos Subidos",
                value: "\(motionManager.todayFloors)",
                icon: "building.2.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor
            )
            
            Button(action: {
                showActiveTimeInfo = true
            }) {
                MetricCard(
                    title: "Tiempo Activo ℹ️",
                    value: "\(motionManager.todayActiveMinutes) min",
                    icon: "clock.fill",
                    cardColor: themeManager.cardColor,
                    accentColor: themeManager.accentColor
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Sección de Historial Interactivo (Calendario + Hora por Hora)
    
    private var historyInteractiveSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.accentColor)
                Text("Historial y Tendencias")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Selector de Período (Día / Semana / Mes)
            Picker("Período", selection: $motionManager.selectedHistoryPeriod) {
                ForEach(HistoryPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)
            
            // Selector de Fecha (Calendario)
            HStack {
                Text("Seleccionar Fecha:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                DatePicker(
                    "",
                    selection: $motionManager.selectedHistoryDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .tint(themeManager.accentColor)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Contenido dinámico según el período elegido
            switch motionManager.selectedHistoryPeriod {
            case .day:
                hourlyBreakdownView
            case .week:
                weeklyChartView
            case .month:
                monthlyChartView
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    // MARK: - Vista Desglose Hora por Hora (Día)
    
    private var hourlyBreakdownView: some View {
        VStack(alignment: .leading, spacing: 14) {
            let activeEntries = motionManager.selectedDayHourly.filter { $0.steps > 0 }
            let totalDaySteps = motionManager.selectedDayHourly.last?.cumulativeSteps ?? 0
            
            HStack {
                Text("Total del Día:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(totalDaySteps) pasos")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.accentColor)
            }
            
            if !motionManager.selectedDayHourly.isEmpty {
                Chart(motionManager.selectedDayHourly) { entry in
                    BarMark(
                        x: .value("Hora", entry.hourString),
                        y: .value("Pasos", entry.steps)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(entry.steps > 0 ? themeManager.accentColor : Color.white.opacity(0.1))
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 4)) { value in
                        AxisValueLabel {
                            if let str = value.as(String.self) {
                                Text(str).font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            
            if !activeEntries.isEmpty {
                Text("Detalle por Franjas Horarias:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 4)
                
                VStack(spacing: 8) {
                    ForEach(activeEntries) { entry in
                        HStack {
                            Text(entry.hourString)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("+\(entry.steps) pasos")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.accentColor)
                            Text("(Acum: \(entry.cumulativeSteps))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No hay pasos registrados en esta fecha.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Vista Gráfico Semanal (Semana)
    
    private var weeklyChartView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !motionManager.weeklySummary.isEmpty {
                Chart(motionManager.weeklySummary) { day in
                    BarMark(
                        x: .value("Día", day.date.formatted(.dateTime.weekday(.short))),
                        y: .value("Pasos", day.steps)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(
                        day.steps >= motionManager.todayGoal ? themeManager.accentColor : Color.white.opacity(0.2)
                    )
                    
                    RuleMark(y: .value("Meta", motionManager.todayGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.gray)
                }
                .frame(height: 180)
                
                VStack(spacing: 8) {
                    ForEach(motionManager.weeklySummary) { day in
                        HStack {
                            Text(day.date.formatted(.dateTime.weekday(.wide).day().month()))
                                .font(.caption)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(day.steps) pasos")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.accentColor)
                            Text(String(format: "%.1f km", day.distanceKm))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Vista Gráfico Mensual (Mes)
    
    private var monthlyChartView: some View {
        VStack(alignment: .leading, spacing: 14) {
            let totalMonthSteps = motionManager.monthlySummary.reduce(0) { $0 + $1.steps }
            let avgMonthSteps = motionManager.monthlySummary.isEmpty ? 0 : totalMonthSteps / motionManager.monthlySummary.count
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total 30 días")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(totalMonthSteps) pasos")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Media diaria")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(avgMonthSteps) pasos/día")
                        .font(.headline)
                        .foregroundColor(themeManager.accentColor)
                }
            }
            
            if !motionManager.monthlySummary.isEmpty {
                Chart(motionManager.monthlySummary) { day in
                    BarMark(
                        x: .value("Día", day.date.formatted(.dateTime.day())),
                        y: .value("Pasos", day.steps)
                    )
                    .cornerRadius(2)
                    .foregroundStyle(themeManager.accentColor.opacity(0.8))
                }
                .frame(height: 160)
            }
        }
    }
    
    private var demoButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            motionManager.toggleDemoMode(!motionManager.isDemoMode)
        }) {
            Image(systemName: motionManager.isDemoMode ? "flask.fill" : "flask")
                .foregroundColor(motionManager.isDemoMode ? themeManager.accentColor : .gray)
        }
    }
    
    private var progressRatio: Double {
        guard motionManager.todayGoal > 0 else { return 0 }
        return min(Double(motionManager.todaySteps) / Double(motionManager.todayGoal), 1.0)
    }
    
    private func updateProgressAnimation() {
        withAnimation(.easeOut(duration: 1.0)) {
            self.animatedProgress = progressRatio
        }
    }
}

/// Componente reutilizable para cada tarjeta de métrica secundaria.
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let cardColor: Color
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accentColor)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardColor)
        .cornerRadius(18)
    }
}

