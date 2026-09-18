import SwiftUI
import PhotosUI

/// Vista nativa para grabar o seleccionar fotos y vídeos del carrete y subirlos al entrenador en PocketBase.
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
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Selector de archivo / vista previa
                        VStack(spacing: 12) {
                            if let data = selectedData, !isVideo, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 250)
                                    .cornerRadius(16)
                                    .shadow(radius: 8)
                            } else if selectedData != nil && isVideo {
                                VStack(spacing: 8) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(themeManager.accentColor)
                                    Text("Vídeo Seleccionado (\(fileName))")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.cardColor)
                                .cornerRadius(16)
                            } else {
                                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.circle.fill")
                                            .font(.system(size: 54))
                                            .foregroundColor(themeManager.accentColor)
                                        
                                        Text("Seleccionar Foto o Vídeo")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Formatos soportados: JPG, PNG, MP4, MOV (hasta 100MB)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .background(themeManager.cardColor)
                                    .cornerRadius(18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(themeManager.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    )
                                }
                            }
                            
                            if selectedData != nil {
                                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                                    Label("Cambiar Archivo", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                        .padding(.top)
                        
                        // Nota opcional para el entrenador
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nota para tu entrenador:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            TextField("Ej: Hoy me ha costado más la última serie de sentadillas...", text: $notesText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(14)
                                .background(themeManager.cardColor)
                                .cornerRadius(14)
                                .foregroundColor(.white)
                        }
                        
                        if let err = uploadError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Botón de Envío
                        Button(action: {
                            performUpload()
                        }) {
                            HStack {
                                if isUploading {
                                    ProgressView()
                                        .tint(.black)
                                    Text("Subiendo al servidor...")
                                        .fontWeight(.bold)
                                } else if uploadSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("¡Entregado con éxito!")
                                        .fontWeight(.bold)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Enviar Progreso a mi Entrenador")
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedData != nil && !isUploading ? themeManager.accentColor : Color.gray.opacity(0.4))
                            .cornerRadius(16)
                        }
                        .disabled(selectedData == nil || isUploading)
                    }
                    .padding(.horizontal)
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
                        // Detectar si es vídeo
                        if let mime = newItem?.supportedContentTypes.first?.preferredMIMEType {
                            self.mimeType = mime
                            self.isVideo = mime.contains("video")
                            self.fileName = isVideo ? "progress_video.mp4" : "progress_photo.jpg"
                        }
                    }
                }
            }
        }
    }
    
    private func performUpload() {
        guard let data = selectedData else { return }
        isUploading = true
        uploadError = nil
        
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
                uploadError = "Error al subir el archivo. Verifica tu conexión con el servidor."
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}
