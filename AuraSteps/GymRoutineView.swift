import SwiftUI

/// Vista nativa para la visualización y ejecución interactiva de la rutina de entrenamiento del alumno.
@MainActor
struct GymRoutineView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedDayIndex: Int = 0
    @State private var showRestTimer: Bool = false
    @State private var restSecondsRemaining: Int = 60
    @State private var timerActive: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                if pbManager.routineDays.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbells.fill")
                            .font(.system(size: 54))
                            .foregroundColor(themeManager.accentColor.opacity(0.6))
                        Text("No hay rutina cargada actualmente")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Pide a tu entrenador que te asigne una rutina desde PocketBase.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Selector de Días de Rutina (Día 1, Día 2, etc.)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(pbManager.routineDays.enumerated()), id: \.offset) { index, day in
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedDayIndex = index
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            let isCompleted = pbManager.completedDayIds.contains(day.id)
                                            if isCompleted {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.emeraldGreen)
                                            }
                                            Text(day.title.isEmpty ? "Día \(index + 1)" : day.title)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(selectedDayIndex == index ? .black : .white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(selectedDayIndex == index ? themeManager.accentColor : themeManager.cardColor)
                                        .cornerRadius(14)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Detalle del día seleccionado
                        if selectedDayIndex < pbManager.routineDays.count {
                            let currentDay = pbManager.routineDays[selectedDayIndex]
                            let isCompleted = pbManager.completedDayIds.contains(currentDay.id)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    // Encabezado del Día
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(currentDay.title)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Text("Día \(selectedDayIndex + 1) de tu plan")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        
                                        // Botón Completar Día
                                        Button(action: {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            Task { @MainActor in
                                                await pbManager.toggleDayCompletion(dayId: currentDay.id)
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: isCompleted ? "checkmark.seal.fill" : "circle")
                                                Text(isCompleted ? "Completado" : "Marcar Hecho")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                            }
                                            .foregroundColor(isCompleted ? .black : themeManager.accentColor)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 14)
                                            .background(isCompleted ? themeManager.accentColor : themeManager.accentColor.opacity(0.15))
                                            .cornerRadius(12)
                                        }
                                    }
                                    
                                    // Contenido de la rutina (Texto / Ejercicios)
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Ejercicios y Descripción:")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(themeManager.accentColor)
                                        
                                        Text(currentDay.content ?? "Sin descripción para este día.")
                                            .font(.body)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineSpacing(4)
                                    }
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(themeManager.cardColor)
                                    .cornerRadius(18)
                                    
                                    // Botón de Temporizador de Descanso
                                    Button(action: {
                                        restSecondsRemaining = 60
                                        timerActive = true
                                        showRestTimer = true
                                    }) {
                                        HStack {
                                            Image(systemName: "timer")
                                            Text("Iniciar Temporizador de Descanso (60s)")
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(themeManager.accentColor)
                                        .cornerRadius(14)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mi Rutina")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRestTimer) {
                ZStack {
                    themeManager.backgroundColor.ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Text("Descanso Activo")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(restSecondsRemaining) / 60.0)
                                .stroke(themeManager.accentColor, lineWidth: 12)
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(restSecondsRemaining)s")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 16) {
                            Button("+30s") {
                                restSecondsRemaining += 30
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(themeManager.cardColor)
                            .cornerRadius(12)
                            
                            Button("Cerrar") {
                                showRestTimer = false
                                timerActive = false
                            }
                            .foregroundColor(.black)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(themeManager.accentColor)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                .presentationDetents([.height(350)])
                .onReceive(timer) { _ in
                    if timerActive && restSecondsRemaining > 0 {
                        restSecondsRemaining -= 1
                        if restSecondsRemaining == 0 {
                            timerActive = false
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
            }
        }
    }
}

extension Color {
    static let emeraldGreen = Color(red: 0.1, green: 0.8, blue: 0.4)
}
