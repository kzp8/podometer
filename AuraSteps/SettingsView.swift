import SwiftUI

/// Vista de Ajustes del usuario para personalizar parámetros biométricos, objetivos, recordatorios, insignias, conexiones descentralizadas, colores y purgado de datos.
@MainActor
struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var motionManager: StepMotionManager
    @EnvironmentObject private var dispatcher: WebhookDispatcher
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var achievementsManager: AchievementsManager
    @EnvironmentObject private var pbManager: PocketBaseManager
    @EnvironmentObject private var tabScrollManager: TabScrollManager
    
    var tabIndex: Int = 4
    
    @State private var isPresentingQRScanner = false
    @State private var pingResultMessage: String? = nil
    @State private var showDeleteConfirmation = false
    @State private var deleteSuccessMessage: String? = nil
    @State private var isQRButtonPressed = false
    @State private var isPingButtonPressed = false
    @State private var pbEmailInput: String = ""
    @State private var pbPasswordInput: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        Color.clear
                            .frame(height: 0)
                            .id("SCROLL_TOP")
                        
                        VStack(spacing: 24) {
                            biometricSection
                            goalsAndRemindersSection
                            achievementsGridSection
                            gymConnectionSection
                            themeSection
                            privacySection
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 75)
                    }
                    .onChange(of: tabScrollManager.scrollEvent) { event in
                        guard let event = event, event.tab == tabIndex else { return }
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
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingQRScanner) {
                QRScannerSheet { scannedString in
                    isPresentingQRScanner = false
                    if let url = URL(string: scannedString) {
                        deepLinkManager.handleURL(url)
                    }
                }
            }
            .sheet(isPresented: $deepLinkManager.isShowingConsentModal) {
                if let pending = deepLinkManager.pendingConfig {
                    ConsentModalView(config: pending, onConfirm: {
                        deepLinkManager.confirmPendingConfig()
                    }, onReject: {
                        deepLinkManager.rejectPendingConfig()
                    })
                }
            }
            .alert("¿Restablecer y Borrar Todos los Datos?", isPresented: $showDeleteConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar Todo", role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        pbManager.logoutManual()
                        tabScrollManager.selectTab(0)
                        deepLinkManager.deleteKeychainConfig()
                        motionManager.clearAllData()
                        userSettings.resetToDefaults()
                        themeManager.resetToDefaults()
                        achievementsManager.resetAchievements()
                        deleteSuccessMessage = "Todos los datos, sesión cerrada y ajustes restablecidos."
                    }
                }
            } message: {
                Text("Esta acción cerrará tu sesión, eliminará de forma irreversible el historial de pasos, credenciales y abrirá de nuevo la configuración inicial.")
            }
        }
    }
    
    // MARK: - Subvistas Modularizadas
    
    @ViewBuilder
    private var biometricSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("Perfil del Usuario")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Peso
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Peso (kg):")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(userSettings.weightKg)) kg")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                
                Slider(value: $userSettings.weightKg, in: 40...180, step: 1)
                    .tint(themeManager.accentColor)
            }
            
            // Altura
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Altura (cm):")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(userSettings.heightCm)) cm")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                
                Slider(value: $userSettings.heightCm, in: 120...220, step: 1)
                    .tint(themeManager.accentColor)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Longitud de Paso
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $userSettings.isAutoStepLength) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-calcular longitud de paso")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text("Calcula ~\(String(format: "%.2f", userSettings.heightCm * 0.414 / 100.0)) m según tu altura")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(themeManager.accentColor)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: userSettings.isAutoStepLength)
                
                if !userSettings.isAutoStepLength {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Longitud de paso manual:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.2f m", userSettings.stepLengthMeters))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.accentColor)
                        }
                        
                        Slider(value: $userSettings.stepLengthMeters, in: 0.40...1.20, step: 0.01)
                            .tint(themeManager.accentColor)
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var goalsAndRemindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flag.checkered")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("Objetivos y Recordatorios")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Meta Diaria de Pasos
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Meta Diaria:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(motionManager.todayGoal) pasos")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(motionManager.todayGoal) },
                        set: { motionManager.todayGoal = Int($0) }
                    ),
                    in: 3000...25000,
                    step: 500
                )
                .tint(themeManager.accentColor)
                
                // Botones de presets rápidos
                HStack(spacing: 8) {
                    ForEach([5000, 8000, 10000, 12000, 15000], id: \.self) { preset in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                motionManager.todayGoal = preset
                            }
                        }) {
                            Text("\(preset / 1000)k")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(motionManager.todayGoal == preset ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(motionManager.todayGoal == preset ? themeManager.accentColor : Color.white.opacity(0.08))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Notificaciones y Recordatorios
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recordatorios Locales:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    if !notificationManager.isAuthorized {
                        Button(action: {
                            Task { @MainActor in
                                _ = await notificationManager.requestAuthorization()
                            }
                        }) {
                            Text("Activar Permisos")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(themeManager.accentColor)
                                .cornerRadius(10)
                        }
                    }
                }
                
                Toggle(isOn: $notificationManager.isDailyReminderEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aviso Diario de Progreso")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Recibe una notificación si aún no has completado tu objetivo")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .tint(themeManager.accentColor)
                .disabled(!notificationManager.isAuthorized)
                
                if notificationManager.isDailyReminderEnabled {
                    DatePicker(
                        "Hora de aviso",
                        selection: $notificationManager.dailyReminderTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .font(.caption)
                    .foregroundColor(.gray)
                    .tint(themeManager.accentColor)
                }
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var achievementsGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("Logros e Insignias")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(achievementsManager.currentStreakDays)d Racha 🔥 • 🛡️ \(achievementsManager.streakFreezesAvailable)/1")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.accentColor)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 12) {
                ForEach(achievementsManager.achievements) { badge in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(badge.isUnlocked ? themeManager.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 44, height: 44)
                            Image(systemName: badge.iconName)
                                .font(.title3)
                                .foregroundColor(badge.isUnlocked ? themeManager.accentColor : .gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(badge.isUnlocked ? .white : .gray)
                            Text(badge.description)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if badge.isUnlocked {
                            Text("DESBLOQUEADO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(themeManager.accentColor)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                }
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    
    @ViewBuilder
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("Personalización de Colores")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Selector de Color de Acento
            VStack(alignment: .leading, spacing: 10) {
                Text("Color de Acento:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    ForEach(AccentColorPreset.allCases) { preset in
                        let isSelected = themeManager.accentPreset == preset
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                themeManager.accentPreset = preset
                            }
                        }) {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 36, height: 36)
                                .scaleEffect(isSelected ? 1.2 : 1.0)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                                )
                                .shadow(color: preset.color.opacity(isSelected ? 0.7 : 0.25), radius: isSelected ? 8 : 2)
                        }
                        if preset != AccentColorPreset.allCases.last {
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Selector de Color de Fondo
            VStack(alignment: .leading, spacing: 10) {
                Text("Color de Fondo:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(BackgroundColorPreset.allCases) { bgPreset in
                        let isSelected = themeManager.backgroundPreset == bgPreset
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                themeManager.backgroundPreset = bgPreset
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(bgPreset.backgroundColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                
                                Text(bgPreset.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isSelected ? themeManager.accentColor : .white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(bgPreset.cardColor)
                            .cornerRadius(12)
                            .scaleEffect(isSelected ? 1.03 : 1.0)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? themeManager.accentColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Selector de Animación de Fondo
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Animación de Fondo:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(themeManager.backgroundAnimation.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
                
                BackgroundAnimationPickerView()
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.trianglebadge.exclamationmark.fill")
                    .foregroundColor(.red)
                Text("Zona de Privacidad")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Conforme a la Guideline 5.1.1(v), puedes borrar irreversiblemente todo el historial de pasos local, credenciales guardadas en Keychain y restablecer las preferencias.")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Restablecer y Borrar Todos los Datos")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            
            if let msg = deleteSuccessMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(themeManager.accentColor)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var gymConnectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("Conectar")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if pbManager.isLoggedIn {
                    Text("Conectado 🟢")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            if pbManager.isLoggedIn, let user = pbManager.currentUser {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button("Cerrar Sesión") {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            pbManager.logoutManual()
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inicia sesión con tu cuenta de alumno para ver tu rutina asignada y enviar entregas a tu entrenador.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email de Alumno:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        TextField("alumno@gimnasio.com", text: $pbEmailInput)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contraseña:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        SecureField("••••••••", text: $pbPasswordInput)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    if let err = pbManager.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        Task { @MainActor in
                            let success = await pbManager.login(identity: pbEmailInput, password: pbPasswordInput)
                            if success {
                                pbPasswordInput = ""
                                tabScrollManager.selectTab(1)
                            }
                        }
                    }) {
                        HStack {
                            if pbManager.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "lock.open.fill")
                                Text("Iniciar Sesión en el Gimnasio")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        .cornerRadius(12)
                    }
                    .disabled(pbManager.isLoading || pbEmailInput.isEmpty || pbPasswordInput.isEmpty)
                }
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private func maskedToken(_ token: String) -> String {
        guard token.count > 6 else { return "••••••" }
        let prefix = token.prefix(4)
        return "\(prefix)••••••••"
    }
}
