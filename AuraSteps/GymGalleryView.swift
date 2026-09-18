import SwiftUI
import AVKit

/// Vista nativa "Mi Galería" que replica fielmente el diseño de la captura 3.
@MainActor
struct GymGalleryView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedFilter: String = "Todos" // "Todos", "Fotos", "Vídeos"
    @State private var showUploadSheet: Bool = false
    
    var filteredUploads: [GymProgressUpload] {
        if selectedFilter == "Fotos" {
            return pbManager.progressUploads.filter { !$0.isVideo }
        } else if selectedFilter == "Vídeos" {
            return pbManager.progressUploads.filter { $0.isVideo }
        }
        return pbManager.progressUploads
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mi Galería")
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                            Text("\(pbManager.progressUploads.count) archivos subidos")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Selector Píldoras de Filtro (Todos, Fotos, Vídeos)
                        HStack(spacing: 10) {
                            ForEach(["Todos", "Fotos", "Vídeos"], id: \.self) { filter in
                                let isSelected = selectedFilter == filter
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                }) {
                                    Text(filter)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(isSelected ? .black : .gray)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 24)
                                        .background(isSelected ? Color.purple : Color(red: 0.12, green: 0.12, blue: 0.14))
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? Color.purple : Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        
                        // Estado Vacío o Grid de Entregas
                        if filteredUploads.isEmpty {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                }
                                
                                Text("Sin archivos aún")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Sube tu primer vídeo o foto de progreso")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                            .cornerRadius(22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredUploads) { item in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                                .foregroundColor(.purple)
                                            Text(item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Spacer()
                                            
                                            if let resp = item.admin_response, !resp.isEmpty {
                                                Text("Resplicado 💬")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.black)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(Color.purple)
                                                    .cornerRadius(8)
                                            } else {
                                                Text(item.seen_by_admin == true ? "Visto 👁️" : "Pendiente ⏳")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        if let fileName = item.file,
                                           let url = pbManager.getFileURL(recordId: item.id, fileName: fileName) {
                                            if item.isVideo {
                                                VideoPlayer(player: AVPlayer(url: url))
                                                    .frame(height: 200)
                                                    .cornerRadius(14)
                                            } else {
                                                AsyncImage(url: url) { phase in
                                                    if let img = phase.image {
                                                        img
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(maxHeight: 220)
                                                            .cornerRadius(14)
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.white.opacity(0.05))
                                                            .frame(height: 180)
                                                            .cornerRadius(14)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        if let notes = item.notes, !notes.isEmpty {
                                            Text("Nota: \"\(notes)\"")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        if let adminResp = item.admin_response, !adminResp.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Feedback del Entrenador:")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.purple)
                                                Text(adminResp)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.purple.opacity(0.12))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(red: 0.08, green: 0.08, blue: 0.10))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Mi Galería")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showUploadSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                GymProgressUploadView()
                    .environmentObject(pbManager)
                    .environmentObject(themeManager)
            }
        }
    }
}
