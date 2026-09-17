import SwiftUI

/// Vista de Ajustes del usuario para personalizar parámetros biométricos, conexiones descentralizadas, colores del tema y purgado de datos.
struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var motionManager: StepMotionManager
    @EnvironmentObject private var dispatcher: WebhookDispatcher
    
    @State private var isPresentingQRScanner = false
    @State private var pingResultMessage: String? = nil
    @State private var showDeleteConfirmation = false
    @State private var deleteSuccessMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        biometricSection
                        connectionSection
                        themeSection
                        privacySection
                    }
                    .padding(.vertical)
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
                    deepLinkManager.deleteKeychainConfig()
                    motionManager.clearAllData()
                    userSettings.resetToDefaults()
                    themeManager.resetToDefaults()
                    deleteSuccessMessage = "Todos los datos locales, métricas y temas se han purgado."
                }
            } message: {
                Text("Esta acción eliminará de forma irreversible el historial de pasos local, credenciales de Keychain y restablecerá los ajustes a sus valores por defecto.")
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
                }
            }
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                
                Text("Conexiones y Servidores")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                StatusBadge(isConnected: deepLinkManager.activeConfig != nil, accentColor: themeManager.accentColor)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            if let config = deepLinkManager.activeConfig {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Plataforma:")
                            .foregroundColor(.gray)
                        Text(config.appName)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Endpoint HTTPS:")
                            .foregroundColor(.gray)
                        Text(config.endpoint.absoluteString)
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    HStack {
                        Text("Token Cliente:")
                            .foregroundColor(.gray)
                        Text(maskedToken(config.token))
                            .font(.caption)
                            .monospaced()
                            .foregroundColor(.white)
                    }
                }
                .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sin conexión activa")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("Escanea un código QR provisto por tu gimnasio o abre un enlace 'aurasteps://connect' para transmitir métricas.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    isPresentingQRScanner = true
                }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                        Text("Escanear Código QR")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.accentColor)
                    .cornerRadius(16)
                }
                
                if let config = deepLinkManager.activeConfig {
                    Button(action: {
                        Task {
                            let success = await dispatcher.dispatchMetrics(
                                config: config,
                                motionManager: motionManager,
                                isManualPing: true
                            )
                            if success {
                                pingResultMessage = "✓ Sincronización de prueba enviada con éxito (HTTP 200)."
                            } else {
                                pingResultMessage = "✕ Error en la sincronización de prueba."
                            }
                        }
                    }) {
                        HStack {
                            if dispatcher.isSyncing {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Probar Envío (Ping)")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .disabled(dispatcher.isSyncing)
                }
                
                if let pingMsg = pingResultMessage {
                    Text(pingMsg)
                        .font(.caption)
                        .foregroundColor(pingMsg.contains("éxito") ? themeManager.accentColor : .red)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 4)
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
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.accentPreset = preset
                            }
                        }) {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: themeManager.accentPreset == preset ? 3 : 0)
                                )
                                .shadow(color: preset.color.opacity(themeManager.accentPreset == preset ? 0.6 : 0.25), radius: themeManager.accentPreset == preset ? 6 : 2)
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
                        Button(action: {
                            withAnimation {
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
                                    .foregroundColor(themeManager.backgroundPreset == bgPreset ? themeManager.accentColor : .white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(bgPreset.cardColor)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.backgroundPreset == bgPreset ? themeManager.accentColor : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
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
