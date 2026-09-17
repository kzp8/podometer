import SwiftUI
import AVFoundation

/// Vista para la gestión de vinculación mediante Deep Links, escaneo de QR y prueba de transmisión (iOS 16+).
struct ConnectionsView: View {
    @EnvironmentObject private var deepLinkManager: DeepLinkManager
    @EnvironmentObject private var motionManager: StepMotionManager
    @EnvironmentObject private var dispatcher: WebhookDispatcher
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var isPresentingQRScanner = false
    @State private var pingResultMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        connectionStatusCard
                        connectionActions
                    }
                    .padding(.vertical)
                }
            }
            .id(themeManager.themeId)
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
            .sheet(isPresented: $deepLinkManager.isShowingConsentModal) {
                if let pending = deepLinkManager.pendingConfig {
                    ConsentModalView(config: pending, onConfirm: {
                        deepLinkManager.confirmPendingConfig()
                    }, onReject: {
                        deepLinkManager.rejectPendingConfig()
                    })
                }
            }
        }
    }
    
    // MARK: - Subvistas Modularizadas
    
    @ViewBuilder
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                
                Text("Servidor de Tercero")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                StatusBadge(isConnected: deepLinkManager.activeConfig != nil, accentColor: themeManager.accentColor)
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
                            .foregroundColor(themeManager.accentColor)
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
        .background(themeManager.cardColor)
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var connectionActions: some View {
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
                .background(themeManager.accentColor)
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
                    .foregroundColor(pingMsg.contains("éxito") ? themeManager.accentColor : .red)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
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

struct ConsentModalView: View {
    let config: ConnectionConfig
    let onConfirm: () -> Void
    let onReject: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.cardColor.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 54))
                    .foregroundColor(themeManager.accentColor)
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
                            .background(themeManager.accentColor)
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
