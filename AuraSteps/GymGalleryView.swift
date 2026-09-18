import SwiftUI
import AVKit

/// Vista nativa para la galería de progresos subidos y respuestas del entrenador.
struct GymGalleryView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showUploadSheet: Bool = false
    @State private var selectedMediaURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                if pbManager.progressUploads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 54))
                            .foregroundColor(themeManager.accentColor.opacity(0.6))
                        Text("Aún no has subido progresos")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Sube fotos o vídeos de tu ejecución para que tu entrenador pueda darte feedback.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: {
                            showUploadSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Subir mi primer progreso")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.black)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(themeManager.accentColor)
                            .cornerRadius(14)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(pbManager.progressUploads) { item in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Encabezado
                                    HStack {
                                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                            .foregroundColor(themeManager.accentColor)
                                        
                                        Text(item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        // Badge de Estado del Admin
                                        if let response = item.admin_response, !response.isEmpty {
                                            Text("Resplicado 💬")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                                .background(themeManager.accentColor)
                                                .cornerRadius(8)
                                        } else if item.seen_by_admin == true {
                                            Text("Visto por Entrenador 👁️")
                                                .font(.caption2)
                                                .foregroundColor(.cyan)
                                        } else {
                                            Text("Pendiente de Revisar ⏳")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    // Previsualización / Vídeo si existe
                                    if let fileName = item.file,
                                       let url = pbManager.getFileURL(recordId: item.id, fileName: fileName) {
                                        if item.isVideo {
                                            VideoPlayer(player: AVPlayer(url: url))
                                                .frame(height: 200)
                                                .cornerRadius(12)
                                        } else {
                                            AsyncImage(url: url) { phase in
                                                if let image = phase.image {
                                                    image
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(maxHeight: 220)
                                                        .cornerRadius(12)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.05))
                                                        .frame(height: 180)
                                                        .cornerRadius(12)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Nota del Alumno
                                    if let note = item.notes, !note.isEmpty {
                                        Text("Tu nota: \"\(note)\"")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    // Respuesta del Entrenador
                                    if let adminResp = item.admin_response, !adminResp.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Feedback del Entrenador:")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(themeManager.accentColor)
                                            Text(adminResp)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(themeManager.accentColor.opacity(0.12))
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(16)
                                .background(themeManager.cardColor)
                                .cornerRadius(18)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Mi Galería de Entregas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showUploadSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
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
