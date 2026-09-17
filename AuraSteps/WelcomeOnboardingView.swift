import SwiftUI

/// Vista de bienvenida u onboarding inicial para la recogida de datos antropométricos y personalización de tema.
struct WelcomeOnboardingView: View {
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Cabecera
                    headerSection
                    
                    // MARK: - Datos Biométricos
                    biometricFormSection
                    
                    // MARK: - Personalización Visual (Tema)
                    themeFormSection
                    
                    // MARK: - Botón de Comienzo
                    startButton
                }
                .padding(.vertical, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subvistas
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.accentColor)
                .padding(.top, 12)
                .shadow(color: themeManager.accentColor.opacity(0.4), radius: 10)
            
            Text("¡Bienvenido a AuraSteps!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Tu contador de pasos autónomo, 100% local y privado. Personaliza tu perfil y tus colores favoritos antes de empezar.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
        }
    }
    
    private var biometricFormSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(themeManager.accentColor)
                Text("1. Tus Datos Biométricos")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Peso
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(themeManager.accentColor)
                        .font(.caption)
                    Text("Peso:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(userSettings.weightKg)) kg")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
                
                Slider(value: $userSettings.weightKg, in: 40...180, step: 1)
                    .tint(themeManager.accentColor)
            }
            
            // Altura
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "ruler.fill")
                        .foregroundColor(themeManager.accentColor)
                        .font(.caption)
                    Text("Altura:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(userSettings.heightCm)) cm")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                }
                
                Slider(value: $userSettings.heightCm, in: 120...220, step: 1)
                    .tint(themeManager.accentColor)
            }
            
            // Vista previa de zancada
            HStack {
                Image(systemName: "shoeprints.fill")
                    .foregroundColor(.gray)
                Text("Paso estimado:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.2f m", userSettings.stepLengthMeters))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    private var themeFormSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(themeManager.accentColor)
                Text("2. Colores de la App")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Selector de Color de Acento
            VStack(alignment: .leading, spacing: 10) {
                Text("Color Principal / Acento:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(AccentColorPreset.allCases) { preset in
                            Button(action: {
                                withAnimation {
                                    themeManager.accentPreset = preset
                                }
                            }) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: themeManager.accentPreset == preset ? 3 : 0)
                                    )
                                    .shadow(color: preset.color.opacity(0.5), radius: 5)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Selector de Fondo
            VStack(alignment: .leading, spacing: 10) {
                Text("Fondo de la App:")
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
    
    private var startButton: some View {
        Button(action: {
            userSettings.hasCompletedOnboarding = true
            onComplete()
        }) {
            HStack {
                Text("Comenzar Experiencia")
                    .font(.headline)
                    .fontWeight(.bold)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(themeManager.accentColor)
            .cornerRadius(18)
            .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
