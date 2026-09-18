import SwiftUI

/// Vista nativa "Mi Panel" (Dashboard Cliente) que replica fielmente el diseño del panel web.
@MainActor
struct GymDashboardView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var onNavigateToRoutine: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let error = pbManager.errorMessage {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        userWelcomeCard
                        activeRoutineSection
                        recentUploadsSection
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Mi Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let user = pbManager.currentUser {
                        HStack(spacing: 8) {
                            Text(user.initials)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.purple)
                                .clipShape(Circle())
                            
                            Text(user.displayName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .refreshable {
                await pbManager.refreshAllGymData()
            }
            .task {
                if pbManager.activeRoutine == nil && pbManager.progressUploads.isEmpty {
                    await pbManager.refreshAllGymData()
                }
            }
        }
    }
    
    // MARK: - Subvistas @ViewBuilder
    
    @ViewBuilder
    private var userWelcomeCard: some View {
        if let user = pbManager.currentUser {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Text(user.initials)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("¡Bienvenido de vuelta!")
                        .font(.caption)
                        .foregroundColor(.purple.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Text("Hola, \(user.displayName)")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        Text("👊")
                            .font(.title3)
                    }
                    
                    if !user.formattedJoinedDate.isEmpty {
                        Text("Activo desde \(user.formattedJoinedDate)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .padding(18)
            .background(Color(red: 0.09, green: 0.07, blue: 0.12))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var activeRoutineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.purple)
                    .font(.subheadline)
                Text("Tu rutina actual")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if let routine = pbManager.activeRoutine {
                VStack(alignment: .leading, spacing: 12) {
                    Text(routine.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let desc = routine.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    
                    // Píldoras de Días
                    if !pbManager.routineDays.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pbManager.routineDays.prefix(3)) { day in
                                    Text(day.title)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                }
                                if pbManager.routineDays.count > 3 {
                                    Text("+\(pbManager.routineDays.count - 3) más")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.purple.opacity(0.15))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.12, green: 0.10, blue: 0.16))
                .cornerRadius(16)
                
                // Botón Ver Rutina Completa
                Button(action: {
                    onNavigateToRoutine()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                        Text("Ver rutina completa")
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
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Text("Sin rutina asignada")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Tu entrenador aún no te ha asignado una rutina activa.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
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
    private var recentUploadsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                    .font(.subheadline)
                Text("Mis últimas subidas")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if pbManager.progressUploads.isEmpty {
                VStack(spacing: 8) {
                    Text("Aún no has subido ningún vídeo o foto")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.03))
                .cornerRadius(16)
            } else {
                VStack(spacing: 10) {
                    ForEach(pbManager.progressUploads.prefix(3)) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.notes?.isEmpty == false ? item.notes! : (item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso"))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if let resp = item.admin_response, !resp.isEmpty {
                                    Text("Entrenador: \"\(resp)\"")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
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
        }
        .padding(18)
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
