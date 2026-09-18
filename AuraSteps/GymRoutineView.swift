import SwiftUI

/// Vista nativa "Mi Rutina" que replica fielmente el diseño de la captura 2.
@MainActor
struct GymRoutineView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedDayIndex: Int = 0
    @State private var showLogModal: Bool = false
    @State private var logText: String = ""
    @State private var showHistoryModal: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea()
                
                if pbManager.routineDays.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let routine = pbManager.activeRoutine {
                                routineHeaderView(routine: routine)
                            }
                            
                            daySelectorView
                            
                            if selectedDayIndex < pbManager.routineDays.count {
                                dayDetailView(currentDay: pbManager.routineDays[selectedDayIndex])
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Mi Rutina")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogModal) {
                logModalView
            }
            .task {
                if pbManager.routineDays.isEmpty, let user = pbManager.currentUser {
                    await pbManager.fetchActiveRoutine(forUserId: user.id)
                }
            }
        }
    }
    
    // MARK: - Subvistas Modularizadas para Evitar Type-Check Timeouts
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.purple)
            }
            Text("Sin rutina asignada")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Tu entrenador aún no te ha asignado una rutina activa.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func routineHeaderView(routine: GymRoutine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "dumbbell.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                    
                    if let desc = routine.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            
            HStack(spacing: 16) {
                Label("\(pbManager.routineDays.count) días / semana", systemImage: "calendar")
                if let lvl = routine.level, !lvl.isEmpty {
                    Label(lvl, systemImage: "rosette")
                }
            }
            .font(.caption2)
            .foregroundColor(.gray)
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.07, blue: 0.12))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var daySelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(pbManager.routineDays.enumerated()), id: \.offset) { index, day in
                    dayButton(index: index, day: day)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private func dayButton(index: Int, day: GymRoutineDay) -> some View {
        let isSelected = selectedDayIndex == index
        let isDone = pbManager.completedDayIds.contains(day.id)
        
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDayIndex = index
            }
        }) {
            HStack(spacing: 6) {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isSelected ? .black : Color(red: 0.1, green: 0.8, blue: 0.4))
                }
                Text(day.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .foregroundColor(isSelected ? .black : .gray)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(isSelected ? Color.purple : Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.purple : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private func dayDetailView(currentDay: GymRoutineDay) -> some View {
        let isDoneToday = pbManager.completedDayIds.contains(currentDay.id)
        let emerald = Color(red: 0.1, green: 0.8, blue: 0.4)
        
        VStack(alignment: .leading, spacing: 16) {
            // Encabezado del Día
            HStack {
                Text(currentDay.title.uppercased())
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.purple)
                    .tracking(1.5)
                
                Spacer()
                
                if isDoneToday {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Completado hoy")
                    }
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(emerald)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Contenido de Ejercicios
            Text(currentDay.content ?? "Sin contenido")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Botones de Acción
            VStack(spacing: 10) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    Task { @MainActor in
                        await pbManager.toggleDayCompletion(dayId: currentDay.id)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isDoneToday ? "checkmark.circle.fill" : "target")
                        Text(isDoneToday ? "Completado — desmarcar" : "Marcar como completado hoy")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundColor(isDoneToday ? emerald : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isDoneToday ? emerald.opacity(0.15) : Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isDoneToday ? emerald.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                
                Button(action: {
                    logText = (currentDay.content ?? "")
                        .split(separator: "\n")
                        .map { String($0).trimmingCharacters(in: .whitespaces) + ": " }
                        .joined(separator: "\n\n")
                    showLogModal = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                        Text("Registrar cargas de hoy")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                
                Button(action: {
                    showHistoryModal = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                        Text("Ver historial de cargas")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var logModalView: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Registrar cargas")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextEditor(text: $logText)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                
                Button("Guardar Registro") {
                    showLogModal = false
                }
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .cornerRadius(14)
            }
            .padding()
        }
        .presentationDetents([.medium])
    }
}
