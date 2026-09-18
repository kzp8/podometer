import SwiftUI

/// Vista de bienvenida u onboarding inicial para la recogida de datos antropométricos y personalización de tema con animaciones interactivas.
struct WelcomeOnboardingView: View {
    @EnvironmentObject private var userSettings: UserSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    
    let onComplete: () -> Void
    
    @State private var isVisible: Bool = false
    @State private var isPulsing: Bool = false
    @State private var isButtonPressed: Bool = false
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Cabecera
                    headerSection
                        .offset(y: isVisible ? 0 : 30)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isVisible)
                    
                    // MARK: - Datos Biométricos
                    biometricFormSection
                        .offset(y: isVisible ? 0 : 40)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: isVisible)
                    
                    // MARK: - Personalización Visual (Tema)
                    themeFormSection
                        .offset(y: isVisible ? 0 : 50)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: isVisible)
                    
                    // MARK: - Botón de Comienzo
                    startButton
                        .offset(y: isVisible ? 0 : 60)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: isVisible)
                }
                .padding(.vertical, 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isVisible = true
            isPulsing = true
        }
    }
    
    // MARK: - Subvistas
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.accentColor)
                .padding(.top, 12)
                .scaleEffect(isPulsing ? 1.05 : 0.95)
                .shadow(color: themeManager.accentColor.opacity(isPulsing ? 0.6 : 0.2), radius: isPulsing ? 14 : 6)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
            
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
                        .contentTransition(.numericText())
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
                        .contentTransition(.numericText())
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
                                .shadow(color: preset.color.opacity(isSelected ? 0.7 : 0.2), radius: isSelected ? 8 : 2)
                        }
                        if preset != AccentColorPreset.allCases.last {
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Selector de Fondo
            VStack(alignment: .leading, spacing: 10) {
                Text("Fondo de la App:")
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
    
    private var startButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isButtonPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                userSettings.hasCompletedOnboarding = true
                onComplete()
            }
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
            .scaleEffect(isButtonPressed ? 0.95 : 1.0)
            .shadow(color: themeManager.accentColor.opacity(0.5), radius: 10, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
