import SwiftUI

struct ForceChangePasswordView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    
                    // Icono y Encabezado
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(themeManager.accentColor)
                        }
                        
                        Text("Cambio de Contraseña")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Por tu seguridad, debes cambiar la contraseña temporal proporcionada por tu entrenador antes de continuar.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 20)
                    
                    // Formulario
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña Actual (Temporal)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            SecureField("Ingresa tu contraseña actual", text: $oldPassword)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nueva Contraseña")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            SecureField("Mínimo 8 caracteres", text: $newPassword)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirmar Nueva Contraseña")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            SecureField("Repite tu nueva contraseña", text: $confirmPassword)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    
                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    if let succ = successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(succ)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // Botón Guardar
                    Button(action: saveNewPassword) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Guardar y Continuar")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(themeManager.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                    .opacity((isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) ? 0.6 : 1.0)
                    
                    // Botón Cerrar Sesión
                    Button(action: {
                        pbManager.logoutManual()
                    }) {
                        Text("Cerrar Sesión")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .interactiveDismissDisabled(true)
    }
    
    private func saveNewPassword() {
        errorMessage = nil
        successMessage = nil
        
        guard newPassword.count >= 8 else {
            errorMessage = "La nueva contraseña debe tener al menos 8 caracteres."
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        
        isLoading = true
        Task {
            let res = await pbManager.changeOwnPassword(oldPassword: oldPassword, newPassword: newPassword)
            await MainActor.run {
                isLoading = false
                if res.success {
                    successMessage = res.message
                } else {
                    errorMessage = res.message
                }
            }
        }
    }
}
