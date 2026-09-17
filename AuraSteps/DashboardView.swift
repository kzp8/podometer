import SwiftUI
import Charts

/// Vista principal Dashboard con el anillo circular animado y gráficos de Swift Charts (iOS 16+).
struct DashboardView: View {
    @EnvironmentObject private var motionManager: StepMotionManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var animatedProgress: Double = 0.0
    
    // Paleta de colores deportivos dark mode
    private let backgroundColor = Color(red: 9/255, green: 9/255, blue: 11/255)
    private let cardColor = Color(red: 18/255, green: 18/255, blue: 22/255)
    private let accentColor = Color(red: 163/255, green: 230/255, blue: 53/255)
    private let secondaryTextColor = Color.gray
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: - Banner de Modo Demo (Revisión de App Store)
                        if motionManager.isDemoMode {
                            HStack {
                                Image(systemName: "flask.fill")
                                Text("Modo Demostración Activo (App Store Review)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(accentColor)
                            .cornerRadius(20)
                            .padding(.top, 8)
                        }
                        
                        // MARK: - Anillo Circular Animado de Pasos
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(cardColor)
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
                                                gradient: Gradient(colors: [accentColor.opacity(0.6), accentColor]),
                                                center: .center,
                                                startAngle: .degrees(-90),
                                                endAngle: .degrees(270)
                                            ),
                                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 200, height: 200)
                                        .shadow(color: accentColor.opacity(0.4), radius: 8, x: 0, y: 0)
                                    
                                    VStack(spacing: 4) {
                                        Image(systemName: "figure.walk")
                                            .font(.title2)
                                            .foregroundColor(accentColor)
                                        
                                        Text("\(motionManager.todaySteps)")
                                            .font(.system(size: 42, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Text("de \(motionManager.todayGoal) pasos")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(secondaryTextColor)
                                    }
                                }
                                .padding(.top, 16)
                                
                                HStack(spacing: 12) {
                                    Text("\(Int(progressRatio * 100))% del objetivo diario")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(accentColor)
                                }
                                .padding(.bottom, 8)
                            }
                            .padding(20)
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Cuadrícula de Métricas Secundarias
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricCard(
                                title: "Distancia",
                                value: String(format: "%.2f km", motionManager.todayDistanceKm),
                                icon: "map.fill",
                                cardColor: cardColor,
                                accentColor: accentColor
                            )
                            
                            MetricCard(
                                title: "Calorías",
                                value: "\(motionManager.todayCaloriesKcal) kcal",
                                icon: "flame.fill",
                                cardColor: cardColor,
                                accentColor: accentColor
                            )
                            
                            MetricCard(
                                title: "Pisos Subidos",
                                value: "\(motionManager.todayFloors)",
                                icon: "building.2.fill",
                                cardColor: cardColor,
                                accentColor: accentColor
                            )
                            
                            MetricCard(
                                title: "Tiempo Activo",
                                value: "\(motionManager.todayActiveMinutes) min",
                                icon: "clock.fill",
                                cardColor: cardColor,
                                accentColor: accentColor
                            )
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Gráfico Interactivo de Rendimiento Semanal (Swift Charts)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(accentColor)
                                Text("Resumen de los últimos 7 días")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            if !motionManager.weeklySummary.isEmpty {
                                Chart(motionManager.weeklySummary) { day in
                                    BarMark(
                                        x: .value("Día", day.date, format: .dateTime.weekday(.short)),
                                        y: .value("Pasos", day.steps)
                                    )
                                    .cornerRadius(6)
                                    .foregroundStyle(
                                        day.steps >= motionManager.todayGoal ? accentColor : Color.white.opacity(0.2)
                                    )
                                    
                                    RuleMark(y: .value("Meta", motionManager.todayGoal))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundStyle(Color.gray)
                                }
                                .frame(height: 180)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisValueLabel {
                                            if let intVal = value.as(Int.self) {
                                                Text("\(intVal / 1000)k")
                                                    .foregroundColor(.gray)
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let dateVal = value.as(Date.self) {
                                                Text(dateVal, format: .dateTime.weekday(.short))
                                                    .foregroundColor(.white)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("Cargando historial de actividad...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            }
                        }
                        .padding(20)
                        .background(cardColor)
                        .cornerRadius(24)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("AuraSteps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        motionManager.toggleDemoMode(!motionManager.isDemoMode)
                    }) {
                        Image(systemName: motionManager.isDemoMode ? "flask.fill" : "flask")
                            .foregroundColor(motionManager.isDemoMode ? accentColor : .gray)
                    }
                }
            }
            .onAppear {
                updateProgressAnimation()
                motionManager.startLiveTracking()
            }
            .onChange(of: motionManager.todaySteps) { _ in
                updateProgressAnimation()
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
