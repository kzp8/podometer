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
    @State private var isUploading: Bool = false
    @State private var uploadSuccess: Bool = false
    @State private var uploadError: String?
    
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
                        
                        // Vista Previa de Selección
                        if let data = selectedData {
                            HStack(spacing: 10) {
                                Image(systemName: isVideo ? "video.circle.fill" : "photo.circle.fill")
                                    .foregroundColor(themeManager.accentColor)
                                Text("Archivo seleccionado: \(fileName)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
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
                                        Text("Enviar")
                                            .fontWeight(.bold)
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedData != nil || !notesText.isEmpty ? themeManager.accentColor : Color.white.opacity(0.08))
                                .cornerRadius(16)
                            }
                            .disabled(isUploading || (selectedData == nil && notesText.isEmpty))
                            
                            Text("Añade un archivo o escribe un mensaje")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
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
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        self.selectedData = data
                        if let mime = newItem?.supportedContentTypes.first?.preferredMIMEType {
                            self.mimeType = mime
                            self.isVideo = mime.contains("video")
                            self.fileName = isVideo ? "video_progreso.mp4" : "foto_progreso.jpg"
                        }
                    }
                }
            }
        }
    }
    
    private func performUpload() {
        isUploading = true
        uploadError = nil
        
        Task { @MainActor in
            let success = await pbManager.uploadProgressMedia(
                fileData: selectedData,
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
                uploadError = "Error al enviar. Por favor comprueba tu conexión."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
