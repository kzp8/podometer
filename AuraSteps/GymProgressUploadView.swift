import SwiftUI
import PhotosUI

/// Vista nativa "Subir Progreso" que replica fielmente el diseño de la captura 4.
@MainActor
struct GymProgressUploadView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedData: Data?
    @State private var mimeType: String = "image/jpeg"
    @State private var fileName: String = "progress.jpg"
    @State private var isVideo: Bool = false
    @State private var notesText: String = ""
    @State private var isLoadingMedia: Bool = false
    @State private var isUploading: Bool = false
    @State private var uploadSuccess: Bool = false
    @State private var uploadError: String?
    
    struct VideoTransferable: Transferable {
        let url: URL
        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .movie) { movie in
                SentTransferredFile(movie.url)
            } importing: { received in
                let tempDir = FileManager.default.temporaryDirectory
                let copyURL = tempDir.appendingPathComponent("upload_\(UUID().uuidString).mp4")
                try? FileManager.default.removeItem(at: copyURL)
                try FileManager.default.copyItem(at: received.file, to: copyURL)
                return VideoTransferable(url: copyURL)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subir progreso")
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                            Text("Comparte un vídeo o foto con tu entrenador")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Dos tarjetas de acción lado a lado (Vídeo / Foto)
                        HStack(spacing: 14) {
                            // Tarjeta Vídeo
                            PhotosPicker(selection: $selectedItem, matching: .videos) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: "video.fill")
                                            .font(.title2)
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    
                                    Text("Vídeo")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("de tu galería")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(themeManager.cardColor)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(selectedData != nil && isVideo ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: selectedData != nil && isVideo ? 2 : 1)
                                )
                            }
                            
                            // Tarjeta Foto
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.06))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    
                                    Text("Foto")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("o cámara")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(themeManager.cardColor)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(selectedData != nil && !isVideo ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: selectedData != nil && !isVideo ? 2 : 1)
                                )
                            }
                        }
                        
                        // Estado Cargando Archivo
                        if isLoadingMedia {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(themeManager.accentColor)
                                Text("Procesando archivo multimedia...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                        }
                        
                        // Vista Previa de Selección
                        if let data = selectedData {
                            HStack(spacing: 10) {
                                Image(systemName: isVideo ? "video.circle.fill" : "photo.circle.fill")
                                    .foregroundColor(themeManager.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Archivo listo: \(fileName)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
                                        .font(.caption2)
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Spacer()
                                Button("Quitar") {
                                    selectedData = nil
                                    selectedItem = nil
                                }
                                .font(.caption2)
                                .foregroundColor(.red)
                            }
                            .padding(12)
                            .background(themeManager.accentColor.opacity(0.12))
                            .cornerRadius(12)
                        }
                        
                        // Campo Nota / Mensaje
                        VStack(alignment: .leading, spacing: 8) {
                            Text("¿Cómo te has sentido? ¿Tienes alguna duda?")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            TextField("Ej: He mejorado mucho en la profundidad de la sentadilla. ¿Está bien el ángulo de la rodilla?", text: $notesText, axis: .vertical)
                                .lineLimit(4...7)
                                .padding(14)
                                .background(themeManager.cardColor)
                                .cornerRadius(16)
                                .foregroundColor(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        
                        if let err = uploadError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Botón de Envío
                        VStack(spacing: 8) {
                            Button(action: {
                                performUpload()
                            }) {
                                HStack(spacing: 8) {
                                    if isUploading {
                                        ProgressView().tint(.white)
                                        Text("Enviando...")
                                            .fontWeight(.bold)
                                    } else if uploadSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("¡Enviado!")
                                            .fontWeight(.bold)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("Enviar a mi Entrenador")
                                            .fontWeight(.bold)
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(selectedData != nil ? .black : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedData != nil ? themeManager.accentColor : Color.white.opacity(0.08))
                                .cornerRadius(16)
                            }
                            .disabled(isUploading || isLoadingMedia || selectedData == nil)
                            
                            if selectedData == nil {
                                Text("Selecciona una foto o vídeo arriba para poder enviar")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Subir Progreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
            .onChange(of: selectedItem) { newItem in
                guard let newItem = newItem else {
                    self.selectedData = nil
                    return
                }
                self.isLoadingMedia = true
                self.uploadError = nil
                Task {
                    // 1. Intentar cargar como vídeo
                    if let movie = try? await newItem.loadTransferable(type: VideoTransferable.self),
                       let data = try? Data(contentsOf: movie.url) {
                        if data.count > 10 * 1024 * 1024 {
                            await MainActor.run {
                                self.isLoadingMedia = false
                                self.uploadError = "El vídeo supera el tamaño máximo permitido (10MB). Por favor recorta su duración."
                            }
                            return
                        }
                        let ext = movie.url.pathExtension.lowercased()
                        let isMov = ext == "mov"
                        await MainActor.run {
                            self.selectedData = data
                            self.mimeType = isMov ? "video/quicktime" : "video/mp4"
                            self.fileName = isMov ? "video_progreso.mov" : "video_progreso.mp4"
                            self.isVideo = true
                            self.isLoadingMedia = false
                        }
                        return
                    }
                    
                    // 2. Intentar cargar como Data directa (foto o vídeo)
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let isVid = newItem.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
                        if isVid {
                            if data.count > 10 * 1024 * 1024 {
                                await MainActor.run {
                                    self.isLoadingMedia = false
                                    self.uploadError = "El vídeo supera el tamaño máximo permitido (10MB). Por favor recorta su duración."
                                }
                                return
                            }
                            await MainActor.run {
                                self.selectedData = data
                                self.mimeType = "video/mp4"
                                self.fileName = "video_progreso.mp4"
                                self.isVideo = true
                                self.isLoadingMedia = false
                            }
                            return
                        } else {
                            if let uiImage = UIImage(data: data),
                               let compressed = resizeAndCompressImage(uiImage) {
                                await MainActor.run {
                                    self.selectedData = compressed
                                    self.mimeType = "image/jpeg"
                                    self.fileName = "foto_progreso.jpg"
                                    self.isVideo = false
                                    self.isLoadingMedia = false
                                }
                                return
                            } else {
                                if data.count > 10 * 1024 * 1024 {
                                    await MainActor.run {
                                        self.isLoadingMedia = false
                                        self.uploadError = "La foto supera el tamaño máximo de 10MB. Elige otra foto."
                                    }
                                    return
                                }
                                await MainActor.run {
                                    self.selectedData = data
                                    self.mimeType = "image/jpeg"
                                    self.fileName = "foto_progreso.jpg"
                                    self.isVideo = false
                                    self.isLoadingMedia = false
                                }
                                return
                            }
                        }
                    }
                    
                    await MainActor.run {
                        self.isLoadingMedia = false
                        self.uploadError = "No se pudo leer el archivo seleccionado. Prueba con otro archivo."
                    }
                }
            }
        }
    }
    
    /// Redimensiona y comprime la imagen a máx 1920px y calidad JPEG 0.82 (igual que en la webapp)
    private func resizeAndCompressImage(_ image: UIImage, maxDimension: CGFloat = 1920, quality: CGFloat = 0.82) -> Data? {
        let size = image.size
        var targetSize = size
        if size.width > maxDimension || size.height > maxDimension {
            if size.width > size.height {
                targetSize = CGSize(width: maxDimension, height: (size.height * maxDimension) / size.width)
            } else {
                targetSize = CGSize(width: (size.width * maxDimension) / size.height, height: maxDimension)
            }
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
    
    private func performUpload() {
        guard let data = selectedData else { return }
        if data.count > 10 * 1024 * 1024 {
            uploadError = "El archivo supera el tamaño máximo de 10MB permitido por el servidor."
            return
        }
        isUploading = true
        uploadError = nil
        pbManager.errorMessage = nil
        
        Task { @MainActor in
            let success = await pbManager.uploadProgressMedia(
                fileData: data,
                fileName: fileName,
                mimeType: mimeType,
                notes: notesText
            )
            isUploading = false
            if success {
                uploadSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            } else {
                uploadError = pbManager.errorMessage ?? "Error al enviar. Por favor comprueba tu conexión."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
