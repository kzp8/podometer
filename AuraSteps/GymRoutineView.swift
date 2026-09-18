import SwiftUI

/// Vista nativa "Mi Rutina" que replica fielmente el diseño de la captura 2.
@MainActor
struct GymRoutineView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    @State private var selectedDayIndex: Int = 0
    @State private var showLogModal: Bool = false
    @State private var logText: String = ""
    @State private var showHistoryModal: Bool = false
    @State private var historyLogs: [GymWorkoutLog] = []
    @State private var isSavingLog: Bool = false
    @State private var isLoadingLog: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                if pbManager.routineDays.isEmpty {
                    ScrollView {
                        emptyStateView
                            .padding(.top, 60)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Color.clear
                                .frame(height: 0)
                                .id("SCROLL_TOP")
                            
                            VStack(spacing: 16) {
                                if let routine = pbManager.activeRoutine {
                                    routineHeaderView(routine: routine)
                                }
                                
                                if !pbManager.clientNotes.isEmpty {
                                    routineTrainerNotesCard
                                }
                                
                                daySelectorView
                                
                                if selectedDayIndex < pbManager.routineDays.count {
                                    dayDetailView(currentDay: pbManager.routineDays[selectedDayIndex])
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 75)
                        }
                        .onChange(of: tabScrollManager.scrollEvent) { event in
                            guard let event = event, event.tab == 2 else { return }
                            if event.animated {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    proxy.scrollTo("SCROLL_TOP", anchor: .top)
                                }
                            } else {
                                proxy.scrollTo("SCROLL_TOP", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mi Rutina")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogModal) {
                logModalView
            }
            .sheet(isPresented: $showHistoryModal) {
                historyModalView
            }
            .task {
                if let user = pbManager.currentUser {
                    await pbManager.fetchActiveRoutine(forUserId: user.id)
                    await pbManager.fetchClientNotes(forUserId: user.id)
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
                    .fill(themeManager.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36))
                    .foregroundColor(themeManager.accentColor)
            }
            Text("Sin rutina asignada")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Tu entrenador aún no te ha asignado una rutina activa o está configurándola.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                if let user = pbManager.currentUser {
                    Task {
                        await pbManager.fetchActiveRoutine(forUserId: user.id)
                        await pbManager.fetchClientNotes(forUserId: user.id)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Comprobar de nuevo")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundColor(.black)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(themeManager.accentColor)
                .cornerRadius(14)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    @ViewBuilder
    private func routineHeaderView(routine: GymRoutine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
        .background(themeManager.cardColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var routineTrainerNotesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(themeManager.accentColor)
                    .font(.caption)
                Text("Notas del entrenador")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(pbManager.clientNotes.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeManager.accentColor)
                    .clipShape(Capsule())
            }
            
            ForEach(pbManager.clientNotes) { note in
                Text(note.content ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
            }
        }
        .padding(14)
        .background(themeManager.cardColor)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.accentColor.opacity(0.15), lineWidth: 1)
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
            .background(isSelected ? themeManager.accentColor : Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundColor(themeManager.accentColor)
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
                    guard selectedDayIndex < pbManager.routineDays.count else { return }
                    let day = pbManager.routineDays[selectedDayIndex]
                    Task { @MainActor in
                        isLoadingLog = true
                        if let existing = await pbManager.fetchTodayLog(routineDayId: day.id) {
                            logText = existing.content ?? ""
                        } else {
                            logText = (day.content ?? "")
                                .split(separator: "\n")
                                .map { String($0).trimmingCharacters(in: .whitespaces) + ": " }
                                .joined(separator: "\n\n")
                        }
                        isLoadingLog = false
                        showLogModal = true
                    }
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
                    guard selectedDayIndex < pbManager.routineDays.count else { return }
                    let day = pbManager.routineDays[selectedDayIndex]
                    Task { @MainActor in
                        historyLogs = await pbManager.fetchAllLogs(routineDayId: day.id)
                        showHistoryModal = true
                    }
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
        .background(themeManager.cardColor)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var logModalView: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Introduce pesos, repeticiones o sensaciones de tu entrenamiento de hoy:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $logText)
                        .padding(10)
                        .background(themeManager.cardColor)
                        .cornerRadius(14)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    
                    Button(action: {
                        guard selectedDayIndex < pbManager.routineDays.count else { return }
                        let day = pbManager.routineDays[selectedDayIndex]
                        isSavingLog = true
                        Task { @MainActor in
                            _ = await pbManager.saveWorkoutLog(routineDayId: day.id, content: logText)
                            isSavingLog = false
                            showLogModal = false
                        }
                    }) {
                        HStack {
                            if isSavingLog {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "checkmark")
                                Text("Guardar Registro")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentColor)
                        .cornerRadius(14)
                    }
                    .disabled(isSavingLog)
                }
                .padding()
            }
            .navigationTitle("Registrar Cargas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        showLogModal = false
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
    
    @ViewBuilder
    private var historyModalView: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                if historyLogs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Sin registros de cargas previos")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Tus notas y cargas guardadas aparecerán aquí organizadas por fecha.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(historyLogs) { log in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(themeManager.accentColor)
                                            .font(.caption)
                                        Text(String((log.log_date ?? "").prefix(10)))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(themeManager.accentColor)
                                        Spacer()
                                    }
                                    
                                    if let content = log.content, !content.isEmpty {
                                        Text(content)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineSpacing(4)
                                    }
                                }
                                .padding(14)
                                .background(themeManager.cardColor)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Historial de Cargas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        showHistoryModal = false
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
    }
}
