import SwiftUI
import Charts

/// Vista principal Dashboard con anillo animado en tiempo real, micro-animaciones fluidas, métricas interactivas y desgloses.
struct DashboardView: View {
    @EnvironmentObject private var motionManager: StepMotionManager
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var achievementsManager: AchievementsManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var animatedProgress: Double = 0.0
    @State private var showActiveTimeInfo: Bool = false
    @State private var isGlowPulsing: Bool = false
    @State private var isIconBouncing: Bool = false
    @State private var pressedCardIndex: Int? = nil
    
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
                        streakBannerView
                        metricsGridView
                        historyInteractiveSectionView
                    }
                    .padding(.vertical)
                }
                .navigationTitle("AuraSteps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        demoButton
                    }
                }
            }
            .alert("¿Qué es el Tiempo Activo?", isPresented: $showActiveTimeInfo) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("El Tiempo Activo mide los minutos acumulados en los que te has desplazado continuamente a una cadencia de caminata o carrera (>30 pasos/min). No cuenta el tiempo que estás de pie sin desplazarte.")
            }
            .onAppear {
                updateProgressAnimation()
                startGlowPulseAnimation()
                motionManager.startLiveTracking()
                Task { @MainActor in
                    await motionManager.fetchHistoryForSelectedDate()
                    achievementsManager.updateStreak(weeklySummary: motionManager.weeklySummary, goal: motionManager.todayGoal)
                    achievementsManager.evaluateProgress(
                        steps: motionManager.todaySteps,
                        goal: motionManager.todayGoal,
                        floors: motionManager.todayFloors,
                        totalDistanceKm: motionManager.todayDistanceKm,
                        notificationManager: notificationManager
                    )
                }
            }
            .onChange(of: motionManager.todaySteps) { newSteps in
                updateProgressAnimation()
                triggerIconBounce()
                achievementsManager.evaluateProgress(
                    steps: newSteps,
                    goal: motionManager.todayGoal,
                    floors: motionManager.todayFloors,
                    totalDistanceKm: motionManager.todayDistanceKm,
                    notificationManager: notificationManager
                )
            }
            .onChange(of: motionManager.selectedHistoryDate) { _ in
                Task { @MainActor in
                    await motionManager.fetchHistoryForSelectedDate()
                }
            }
            .onChange(of: motionManager.selectedHistoryPeriod) { _ in
                Task { @MainActor in
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
    
    // MARK: - Subvistas Animadas
    
    private var demoBannerView: some View {
        HStack {
            Image(systemName: "flask.fill")
                .rotationEffect(.degrees(isGlowPulsing ? 10 : -10))
            Text("Modo Demostración Activo")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.black)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(themeManager.accentColor)
        .cornerRadius(20)
        .shadow(color: themeManager.accentColor.opacity(isGlowPulsing ? 0.6 : 0.2), radius: isGlowPulsing ? 10 : 4)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isGlowPulsing)
        .padding(.top, 4)
    }
    
    private var stepRingCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(themeManager.cardColor)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 20) {
                ZStack {
                    // Aura pulsante de fondo
                    Circle()
                        .stroke(themeManager.accentColor.opacity(isGlowPulsing ? 0.25 : 0.05), lineWidth: 28)
                        .frame(width: 200, height: 200)
                        .scaleEffect(isGlowPulsing ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isGlowPulsing)
                    
                    // Anillo estático de carril
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 18)
                        .frame(width: 200, height: 200)
                    
                    // Anillo de progreso dinámico animado
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [themeManager.accentColor.opacity(0.5), themeManager.accentColor]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)
                        .shadow(color: themeManager.accentColor.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(themeManager.accentColor)
                            .scaleEffect(isIconBouncing ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isIconBouncing)
                        
                        Text("\(motionManager.todaySteps)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
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
    
    private var streakBannerView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(themeManager.accentColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(achievementsManager.currentStreakDays) Días")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Racha Actual")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(themeManager.accentColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    let unlockedCount = achievementsManager.achievements.filter { $0.isUnlocked }.count
                    Text("\(unlockedCount)/\(achievementsManager.achievements.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Logros")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(themeManager.cardColor)
        .cornerRadius(18)
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
                accentColor: themeManager.accentColor,
                isPressed: pressedCardIndex == 0
            )
            .onTapGesture {
                animateCardTap(index: 0)
            }
            
            MetricCard(
                title: "Calorías",
                value: "\(currentCal) kcal",
                icon: "flame.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor,
                isPressed: pressedCardIndex == 1
            )
            .onTapGesture {
                animateCardTap(index: 1)
            }
            
            MetricCard(
                title: "Pisos Subidos",
                value: "\(motionManager.todayFloors)",
                icon: "building.2.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor,
                isPressed: pressedCardIndex == 2
            )
            .onTapGesture {
                animateCardTap(index: 2)
            }
            
            MetricCard(
                title: "Tiempo Activo ℹ️",
                value: "\(motionManager.todayActiveMinutes) min",
                icon: "clock.fill",
                cardColor: themeManager.cardColor,
                accentColor: themeManager.accentColor,
                isPressed: pressedCardIndex == 3
            )
            .onTapGesture {
                animateCardTap(index: 3)
                showActiveTimeInfo = true
            }
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
            
            // Contenido dinámico animado según el período elegido
            Group {
                switch motionManager.selectedHistoryPeriod {
                case .day:
                    hourlyBreakdownView
                case .week:
                    weeklyChartView
                case .month:
                    monthlyChartView
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                .animation(.easeInOut(duration: 0.5), value: motionManager.selectedDayHourly.map { $0.steps })
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
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
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
                .animation(.easeInOut(duration: 0.5), value: motionManager.weeklySummary.map { $0.steps })
                
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
                .animation(.easeInOut(duration: 0.5), value: motionManager.monthlySummary.map { $0.steps })
            }
        }
    }
    
    private var demoButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                motionManager.toggleDemoMode(!motionManager.isDemoMode)
            }
        }) {
            Image(systemName: motionManager.isDemoMode ? "flask.fill" : "flask")
                .foregroundColor(motionManager.isDemoMode ? themeManager.accentColor : .gray)
                .scaleEffect(motionManager.isDemoMode ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: motionManager.isDemoMode)
        }
    }
    
    private var progressRatio: Double {
        guard motionManager.todayGoal > 0 else { return 0 }
        return min(Double(motionManager.todaySteps) / Double(motionManager.todayGoal), 1.0)
    }
    
    private func updateProgressAnimation() {
        withAnimation(.easeOut(duration: 1.2)) {
            self.animatedProgress = progressRatio
        }
    }
    
    private func startGlowPulseAnimation() {
        isGlowPulsing = true
    }
    
    private func triggerIconBounce() {
        isIconBouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isIconBouncing = false
        }
    }
    
    private func animateCardTap(index: Int) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            pressedCardIndex = index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                pressedCardIndex = nil
            }
        }
    }
}
