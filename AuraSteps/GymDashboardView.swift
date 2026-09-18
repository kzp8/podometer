import SwiftUI

/// Vista nativa "Mi Panel" (Dashboard Cliente) que replica fielmente el diseño del panel web.
@MainActor
struct GymDashboardView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    var onNavigateToRoutine: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear
                            .frame(height: 0)
                            .id("SCROLL_TOP")
                        
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
                            trainerNotesSection
                            activeRoutineSection
                            recentUploadsSection
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 75)
                    }
                    .onChange(of: tabScrollManager.scrollEvent) { event in
                        guard let event = event, event.tab == 1 else { return }
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
            .navigationTitle("Mi Panel")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await pbManager.refreshAllGymData()
            }
            .task {
                await pbManager.refreshAllGymData()
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
                        .fill(LinearGradient(colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Text(user.initials)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("¡Te damos la bienvenida!")
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor.opacity(0.8))
                    
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
                    
                    if pbManager.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("\(pbManager.streak) día\(pbManager.streak != 1 ? "s" : "") de racha 🔥")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(themeManager.accentColor)
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .padding(18)
            .background(themeManager.cardColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var activeRoutineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(themeManager.accentColor)
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
                                        .foregroundColor(themeManager.accentColor)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
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
        .background(themeManager.cardColor)
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
                    .foregroundColor(themeManager.accentColor)
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
    private var trainerNotesSection: some View {
        if !pbManager.clientNotes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(themeManager.accentColor)
                        .font(.subheadline)
                    Text("Notas de tu entrenador")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(pbManager.clientNotes.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(themeManager.accentColor)
                        .clipShape(Capsule())
                }
                
                VStack(spacing: 10) {
                    ForEach(pbManager.clientNotes) { note in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pencil.line")
                                .foregroundColor(themeManager.accentColor.opacity(0.9))
                                .font(.footnote)
                                .padding(.top, 2)
                            
                            Text(note.content ?? "")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(themeManager.accentColor.opacity(0.18), lineWidth: 1)
                        )
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
    }
}
