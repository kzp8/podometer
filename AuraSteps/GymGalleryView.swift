import SwiftUI
import AVKit

/// Vista nativa "Mi Galería" con soporte de selección múltiple para borrado y visor de media a pantalla completa.
@MainActor
struct GymGalleryView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedFilter: String = "Todos" // "Todos", "Fotos", "Vídeos"
    @State private var showUploadSheet: Bool = false
    @State private var isSelectionMode: Bool = false
    @State private var selectedUploadIds: Set<String> = []
    @State private var showDeleteAlert: Bool = false
    @State private var isDeleting: Bool = false
    @State private var activeViewerItem: GymProgressUpload? = nil
    
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
                        headerView
                        
                        // Selector Píldoras de Filtro (Todos, Fotos, Vídeos)
                        filterPillsView
                        
                        // Estado Vacío o Grid de Entregas
                        if filteredUploads.isEmpty {
                            emptyStateView
                        } else {
                            uploadsListView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .padding(.bottom, isSelectionMode ? 80 : 0)
                }
                
                // Barra flotante de selección y eliminación por lotes
                if isSelectionMode {
                    selectionBottomBar
                }
            }
            .navigationTitle("Mi Galería")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Botón de Papelera / Modo Selección
                        if !pbManager.progressUploads.isEmpty {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode {
                                        selectedUploadIds.removeAll()
                                    }
                                }
                            }) {
                                Image(systemName: isSelectionMode ? "xmark" : "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isSelectionMode ? .white : (selectedUploadIds.isEmpty ? themeManager.accentColor : .red))
                            }
                        }
                        
                        // Botón "+" para subir fotos o vídeos
                        Button(action: {
                            showUploadSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                GymProgressUploadView()
                    .environmentObject(pbManager)
                    .environmentObject(themeManager)
            }
            .fullScreenCover(item: $activeViewerItem) { item in
                GymMediaViewerModal(item: item)
                    .environmentObject(pbManager)
                    .environmentObject(themeManager)
            }
            .alert("¿Eliminar archivos?", isPresented: $showDeleteAlert) {
                Button("Eliminar \(selectedUploadIds.count) archivo(s)", role: .destructive) {
                    Task {
                        await deleteSelectedItems()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción eliminará de forma permanente los archivos seleccionados.")
            }
            .refreshable {
                if let user = pbManager.currentUser {
                    await pbManager.fetchProgressUploads(forUserId: user.id)
                }
            }
            .task {
                if pbManager.progressUploads.isEmpty, let user = pbManager.currentUser {
                    await pbManager.fetchProgressUploads(forUserId: user.id)
                }
            }
        }
    }
    
    // MARK: - Subvistas
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mi Galería")
                .font(.title)
                .fontWeight(.heavy)
                .foregroundColor(.white)
            Text("\(pbManager.progressUploads.count) archivos subidos")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private var filterPillsView: some View {
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
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
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
    }
    
    @ViewBuilder
    private var uploadsListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(filteredUploads) { item in
                uploadCard(item: item)
            }
        }
    }
    
    @ViewBuilder
    private func uploadCard(item: GymProgressUpload) -> some View {
        let isSelected = selectedUploadIds.contains(item.id)
        
        Button(action: {
            if isSelectionMode {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if isSelected {
                    selectedUploadIds.remove(item.id)
                } else {
                    selectedUploadIds.insert(item.id)
                }
            } else {
                activeViewerItem = item
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Cabecera de la tarjeta con icono y estado
                HStack {
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                    }
                    
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                        .foregroundColor(themeManager.accentColor)
                    
                    Text(item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let resp = item.admin_response, !resp.isEmpty {
                        Text("Respondido 💬")
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
                
                // Vista previa de Foto o Miniatura de Vídeo
                if let fileName = item.file,
                   let url = pbManager.getFileURL(recordId: item.id, fileName: fileName) {
                    if item.isVideo {
                        // El vídeo NO se reproduce aquí en tarjeta: muestra indicador de tocar para reproducir
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 180)
                            
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.accentColor)
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                        .foregroundColor(.black)
                                        .offset(x: 2)
                                }
                                
                                Text("Toca para reproducir a pantalla completa")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    } else {
                        GymImageView(url: url, authToken: pbManager.authToken)
                            .frame(maxHeight: 220)
                            .cornerRadius(14)
                    }
                }
                
                // Nota del cliente si existe
                if let notes = item.notes, !notes.isEmpty {
                    Text("Nota: \"\(notes)\"")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Feedback del entrenador si existe
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
                    .stroke(isSelected ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var selectionBottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedUploadIds.count) seleccionado\(selectedUploadIds.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if selectedUploadIds.count < filteredUploads.count {
                        Button("Seleccionar todos") {
                            selectedUploadIds = Set(filteredUploads.map(\.id))
                        }
                        .font(.caption2)
                        .foregroundColor(themeManager.accentColor)
                    } else {
                        Button("Deseleccionar todos") {
                            selectedUploadIds.removeAll()
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(role: .destructive, action: {
                    showDeleteAlert = true
                }) {
                    HStack(spacing: 6) {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Eliminar")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(selectedUploadIds.isEmpty ? Color.gray.opacity(0.3) : Color.red)
                    .cornerRadius(12)
                }
                .disabled(selectedUploadIds.isEmpty || isDeleting)
            }
            .padding(16)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func deleteSelectedItems() async {
        guard !selectedUploadIds.isEmpty else { return }
        isDeleting = true
        let idsToDelete = selectedUploadIds
        _ = await pbManager.deleteMultipleProgressUploads(ids: idsToDelete)
        selectedUploadIds.removeAll()
        isSelectionMode = false
        isDeleting = false
    }
}

// MARK: - Visor de Media a Pantalla Completa

@MainActor
struct GymMediaViewerModal: View {
    let item: GymProgressUpload
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Barra superior con botón de cerrar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.isVideo ? "Vídeo de Progreso" : "Foto de Progreso")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        if let uploaded = item.uploaded_at, !uploaded.isEmpty {
                            Text(String(uploaded.prefix(10)))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Contenido central: Foto con zoom o Vídeo con reproductor AVKit
                if let fileName = item.file,
                   let url = pbManager.getFileURL(recordId: item.id, fileName: fileName) {
                    if item.isVideo {
                        FullScreenVideoPlayer(url: url, authToken: pbManager.authToken)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        FullScreenImageView(url: url, authToken: pbManager.authToken)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                Spacer()
                
                // Barra inferior con notas y feedback del entrenador
                VStack(alignment: .leading, spacing: 8) {
                    if let note = item.notes, !note.isEmpty {
                        Text("Nota: \(note)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    if let adminResp = item.admin_response, !adminResp.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.bubble.fill")
                                .foregroundColor(themeManager.accentColor)
                                .font(.caption)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Comentario del entrenador:")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.accentColor)
                                Text(adminResp)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Visor de Foto Interactivo a Pantalla Completa (Zoom y Pan)

@MainActor
struct FullScreenImageView: View {
    let url: URL
    let authToken: String?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GymImageView(url: url, authToken: authToken)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        let delta = val / lastScale
                        lastScale = val
                        scale = min(max(scale * delta, 1.0), 4.0)
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale <= 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { val in
                        if scale > 1.0 {
                            offset = CGSize(
                                width: lastOffset.width + val.translation.width,
                                height: lastOffset.height + val.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                    }
                }
            }
    }
}

// MARK: - Reproductor de Vídeo a Pantalla Completa

@MainActor
struct FullScreenVideoPlayer: View {
    let url: URL
    let authToken: String?
    
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
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
        let newPlayer = AVPlayer(playerItem: item)
        self.player = newPlayer
    }
}

// MARK: - Componentes Autenticados de Imagen

@MainActor
struct GymImageView: View {
    let url: URL
    let authToken: String?
    @EnvironmentObject var themeManager: ThemeManager
    
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
