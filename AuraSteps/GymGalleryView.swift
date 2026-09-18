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
                themeManager.backgroundColor.ignoresSafeArea()
                
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
                                        .background(isSelected ? themeManager.accentColor : Color(red: 0.12, green: 0.12, blue: 0.14))
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: 1)
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
                            .background(themeManager.cardColor)
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
                                                .foregroundColor(themeManager.accentColor)
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
                                                    .background(themeManager.accentColor)
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
                                                GymVideoPlayer(url: url, authToken: pbManager.authToken)
                                                    .frame(height: 200)
                                                    .cornerRadius(14)
                                            } else {
                                                GymImageView(url: url, authToken: pbManager.authToken)
                                                    .frame(maxHeight: 220)
                                                    .cornerRadius(14)
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
                                                    .foregroundColor(themeManager.accentColor)
                                                Text(adminResp)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(themeManager.accentColor.opacity(0.12))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(16)
                                    .background(themeManager.cardColor)
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
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                GymProgressUploadView()
                    .environmentObject(pbManager)
                    .environmentObject(themeManager)
            }
            .task {
                if pbManager.progressUploads.isEmpty, let user = pbManager.currentUser {
                    await pbManager.fetchProgressUploads(forUserId: user.id)
                }
            }
        }
    }
}

// MARK: - Componentes Autenticados de Imagen y Vídeo

@MainActor
struct GymImageView: View {
    let url: URL
    let authToken: String?
    
    @State private var uiImage: UIImage? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 180)
                    ProgressView()
                        .tint(themeManager.accentColor)
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 180)
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        var request = URLRequest(url: url)
        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode),
               let image = UIImage(data: data) {
                self.uiImage = image
            }
        } catch {
            print("Error cargando imagen: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

@MainActor
struct GymVideoPlayer: View {
    let url: URL
    let authToken: String?
    
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        var options: [String: Any] = [:]
        if let token = authToken, !token.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = ["Authorization": "Bearer \(token)"]
        }
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: item)
    }
}
