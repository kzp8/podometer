import SwiftUI
import AVFoundation

/// Vista para la gestión de vinculación mediante Deep Links, escaneo de QR y purgado de datos.
struct ConnectionsView: View {
    @Environment(DeepLinkManager.self) private var deepLinkManager
    @Environment(StepMotionManager.self) private var motionManager
    @Environment(WebhookDispatcher.self) private var dispatcher
    
    @State private var isPresentingQRScanner = false
    @State private var showDeleteConfirmation = false
    @State private var pingResultMessage: String? = nil
    
    private let backgroundColor = Color(red: 9/255, green: 9/255, blue: 11/255)
    private let cardColor = Color(red: 18/255, green: 18/255, blue: 22/255)
    private let accentColor = Color(red: 163/255, green: 230/255, blue: 53/255)
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - Estado de Vinculación Actual
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "network")
                                    .font(.title3)
                                    .foregroundColor(accentColor)
                                
                                Text("Servidor de Tercero")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                StatusBadge(isConnected: deepLinkManager.activeConfig != nil, accentColor: accentColor)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            if let config = deepLinkManager.activeConfig {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Plataforma:")
                                            .foregroundColor(.gray)
                                        Text(config.appName)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    HStack {
                                        Text("Endpoint HTTPS:")
                                            .foregroundColor(.gray)
                                        Text(config.endpoint.absoluteString)
                                            .font(.caption)
                                            .foregroundColor(accentColor)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    HStack {
                                        Text("Token Cliente:")
                                            .foregroundColor(.gray)
                                        Text(maskedToken(config.token))
                                            .font(.caption)
                                            .monospaced()
                                            .foregroundColor(.white)
                                    }
                                }
                                .font(.subheadline)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Sin conexión activa")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Text("Escanea un código QR provisto por tu gimnasio o abre un enlace 'aurasteps://connect' para compartir tus métricas de forma directa.")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(20)
                        .background(cardColor)
                        .cornerRadius(24)
                        .padding(.horizontal)
                        
                        // MARK: - Acciones de Conexión
                        VStack(spacing: 12) {
                            Button(action: {
                                isPresentingQRScanner = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title3)
                                    Text("Escanear Código QR")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(accentColor)
                                .cornerRadius(16)
                            }
                            
                            if let config = deepLinkManager.activeConfig {
                                Button(action: {
                                    Task {
                                        let success = await dispatcher.dispatchMetrics(
                                            config: config,
                                            motionManager: motionManager,
                                            isManualPing: true
                                        )
                                        if success {
                                            pingResultMessage = " Sincronización de prueba enviada con éxito (HTTP 200)."
                                        } else {
                                            pingResultMessage = " Error en la sincronización de prueba."
                                        }
                                    }
                                }) {
                                    HStack {
                                        if dispatcher.isSyncing {
                                            ProgressView()
                                                .tint(.white)
                                                .padding(.trailing, 4)
                                        } else {
                                            Image(systemName: "paperplane.fill")
                                        }
                                        Text("Probar Envío (Ping)")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(16)
                                }
                                .disabled(dispatcher.isSyncing)
                            }
                            
                            if let pingMsg = pingResultMessage {
                                Text(pingMsg)
                                    .font(.caption)
                                    .foregroundColor(pingMsg.contains("éxito") ? accentColor : .red)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Zona de Privacidad y Supresión Integral de Datos (Guideline 5.1.1(v))
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "shield.trianglebadge.exclamationmark.fill")
                                    .foregroundColor(.red)
                                Text("Zona de Privacidad")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Puedes revocar todos los permisos y purgar completamente el historial de pasos, métricas temporales y credenciales de vinculación del dispositivo.")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Restablecer y Borrar Todos los Datos")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(20)
                        .background(cardColor)
                        .cornerRadius(24)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Conexiones")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPresentingQRScanner) {
                QRScannerSheet { scannedString in
                    isPresentingQRScanner = false
                    if let url = URL(string: scannedString) {
                        deepLinkManager.handleURL(url)
                    }
                }
            }
            .sheet(isPresented: Bindable(deepLinkManager).isShowingConsentModal) {
                if let pending = deepLinkManager.pendingConfig {
                    ConsentModalView(config: pending, onConfirm: {
                        deepLinkManager.confirmPendingConfig()
                    }, onReject: {
                        deepLinkManager.rejectPendingConfig()
                    })
                }
            }
            .alert("¿Restablecer y Borrar Todos los Datos?", isPresented: $showDeleteConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Borrar Todo", role: .destructive) {
                    // Purgado atómico completo
                    deepLinkManager.deleteKeychainConfig()
                    motionManager.clearAllData()
                    pingResultMessage = nil
                }
            } message: {
                Text("Esta acción eliminará de forma irreversible todas las métricas de pasos en memoria local y las credenciales guardadas en Keychain.")
            }
        }
    }
    
    private func maskedToken(_ token: String) -> String {
        guard token.count > 6 else { return "••••••" }
        let prefix = token.prefix(4)
        return "\(prefix)••••••••"
    }
}

struct StatusBadge: View {
    let isConnected: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? accentColor : Color.gray)
                .frame(width: 8, height: 8)
            Text(isConnected ? "VINCULADO" : "SIN CONEXIÓN")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(isConnected ? accentColor : Color.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background((isConnected ? accentColor : Color.gray).opacity(0.12))
        .cornerRadius(12)
    }
}

/// Modal nativo de consentimiento explícito (Guideline 5.1.1(i))
struct ConsentModalView: View {
    let config: ConnectionConfig
    let onConfirm: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        ZStack {
            Color(red: 18/255, green: 18/255, blue: 22/255).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 54))
                    .foregroundColor(Color(red: 163/255, green: 230/255, blue: 53/255))
                    .padding(.top, 24)
                
                Text("Solicitud de Vinculación")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("¿Deseas compartir tus métricas de actividad (pasos, distancia, calorías) con **\(config.appName)**?")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detalles de la conexión:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("Endpoint:")
                            .foregroundColor(.gray)
                        Text(config.endpoint.absoluteString)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Autorizar y Conectar")
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 163/255, green: 230/255, blue: 53/255))
                            .cornerRadius(16)
                    }
                    
                    Button(action: onReject) {
                        Text("Cancelar")
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding()
        }
    }
}

/// Lector de QR integrado nativamente con AVFoundation
struct QRScannerSheet: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var onScan: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        
        let session = AVCaptureSession()
        if session.canAddInput(input) { session.addInput(input) }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession?.stopRunning()
            onScan?(stringValue)
        }
    }
}
