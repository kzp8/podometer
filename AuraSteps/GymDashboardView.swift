import SwiftUI

/// Vista nativa principal del panel de Gimnasio cuando el alumno está vinculado a PocketBase.
struct GymDashboardView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showUploadSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Saludo y Tarjeta de Usuario
                        if let user = pbManager.currentUser {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("¡Hola, \(user.displayName)! 👋")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Plan de entrenamiento vinculado")
                                        .font(.caption)
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Spacer()
                                
                                Image(systemName: "figure.cross.training")
                                    .font(.title)
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(12)
                                    .background(themeManager.cardColor)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Tarjeta de Rutina Asignada
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "dumbbell.fill")
                                    .foregroundColor(themeManager.accentColor)
                                Text("Rutina Activa")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            if let routine = pbManager.activeRoutine {
                                Text(routine.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                if let desc = routine.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                HStack {
                                    Text("\(pbManager.routineDays.count) Días de entrenamiento")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    
                                    NavigationLink(destination: GymRoutineView()) {
                                        HStack(spacing: 4) {
                                            Text("Ver Rutina")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                            Image(systemName: "chevron.right")
                                        }
                                        .foregroundColor(.black)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 14)
                                        .background(themeManager.accentColor)
                                        .cornerRadius(10)
                                    }
                                }
                            } else {
                                Text("No tienes ninguna rutina asignada en este momento.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(18)
                        .background(themeManager.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Botón Rápido Subir Progreso
                        Button(action: {
                            showUploadSheet = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Subir Foto / Vídeo a mi Entrenador")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.accentColor)
                            .cornerRadius(16)
                            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8)
                        }
                        .padding(.horizontal)
                        
                        // Sección Galería y Feedback Reciente
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "photo.stack.fill")
                                    .foregroundColor(themeManager.accentColor)
                                Text("Mis Entregas y Feedback")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                NavigationLink(destination: GymGalleryView()) {
                                    Text("Ver Todo (\(pbManager.progressUploads.count))")
                                        .font(.caption)
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                            
                            if pbManager.progressUploads.isEmpty {
                                Text("Aún no has enviado entregas a tu entrenador.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(pbManager.progressUploads.prefix(3)) { item in
                                    HStack {
                                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                            .foregroundColor(themeManager.accentColor)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.notes?.isEmpty == false ? item.notes! : (item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso"))
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            if let resp = item.admin_response, !resp.isEmpty {
                                                Text("Entrenador: \"\(resp)\"")
                                                    .font(.caption2)
                                                    .foregroundColor(themeManager.accentColor)
                                                    .lineLimit(1)
                                            } else {
                                                Text(item.seen_by_admin == true ? "Visto 👁️" : "Pendiente ⏳")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(18)
                        .background(themeManager.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Gimnasio")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showUploadSheet) {
                GymProgressUploadView()
                    .environmentObject(pbManager)
                    .environmentObject(themeManager)
            }
            .refreshable {
                await pbManager.refreshAllGymData()
            }
        }
    }
}
