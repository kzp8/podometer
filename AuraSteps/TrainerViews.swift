import SwiftUI

// MARK: - Componente de Cabecera Común del Entrenador

@MainActor
struct TrainerHeaderView: View {
    let title: String
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono / Logo con resplandor
            ZStack {
                Circle()
                    .fill(themeManager.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.accentColor)
            }
            
            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - 1. PESTAÑA INICIO (DASHBOARD ENTRENADOR)

@MainActor
struct TrainerDashboardView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    var onGoToGallery: () -> Void = {}
    var onGoToClients: () -> Void = {}
    
    @State private var recentClientsLimit: Int = 3
    @State private var recentUploadsLimit: Int = 3
    @State private var showCreateClientSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    TrainerHeaderView(title: "Dashboard")
                    
                    ScrollView {
                        VStack(spacing: 18) {
                            // Banner superior "Tienes X vídeos pendientes de revisar"
                            pendingVideosBanner
                            
                            // Grid 2x2 Métricas
                            metricsGrid
                            
                            // Sección Clientes Recientes
                            recentClientsSection
                            
                            // Sección Últimos Archivos Recibidos
                            recentUploadsSection
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateClientSheet) {
                TrainerCreateClientSheet()
            }
        }
    }
    
    // MARK: - Banner de Pendientes
    @ViewBuilder
    private var pendingVideosBanner: some View {
        let pending = pbManager.pendingReviewsCount
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Buenos días, \(pbManager.currentUser?.displayName ?? "Admin")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.accentColor)
                    Text("👋")
                }
                
                Text(pending > 0 ? "Tienes \(pending) vídeos pendientes de revisar" : "¡Todo al día! Sin revisiones pendientes")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
            }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onGoToGallery()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                    Text("Revisar ahora")
                        .fontWeight(.bold)
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeManager.accentColor)
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Grid 2x2 Métricas
    @ViewBuilder
    private var metricsGrid: some View {
        let activeClients = pbManager.trainerClients.filter { $0.isActive }.count
        let totalClients = pbManager.trainerClients.count
        let routinesCount = pbManager.trainerRoutines.count
        let totalVideos = pbManager.trainerUploads.filter { $0.isVideo }.count
        let pendingVideos = pbManager.trainerUploads.filter { $0.isVideo && $0.seen_by_admin != true }.count
        let retention = totalClients > 0 ? Int((Double(activeClients) / Double(totalClients)) * 100) : 100
        
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Tarjeta 1: Clientes Activos
            metricCard(
                icon: "person.2.fill",
                iconColor: themeManager.accentColor,
                iconBg: themeManager.accentColor.opacity(0.3),
                value: "\(activeClients)",
                title: "Clientes activos",
                subtitle: "\(totalClients) total"
            )
            
            // Tarjeta 2: Rutinas Creadas
            metricCard(
                icon: "dumbbell.fill",
                iconColor: Color(hex: "38BDF8"),
                iconBg: Color(hex: "0284C7").opacity(0.3),
                value: "\(routinesCount)",
                title: "Rutinas creadas",
                subtitle: "Disponibles"
            )
            
            // Tarjeta 3: Vídeos recibidos
            metricCard(
                icon: "video.fill",
                iconColor: themeManager.accentColor,
                iconBg: themeManager.accentColor.opacity(0.3),
                value: "\(totalVideos)",
                title: "Vídeos recibidos",
                subtitle: "\(pendingVideos) pendientes"
            )
            
            // Tarjeta 4: Retención
            metricCard(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Color(hex: "34D399"),
                iconBg: Color(hex: "059669").opacity(0.3),
                value: "\(retention)%",
                title: "Clientes activos",
                subtitle: "De retención 🔥"
            )
        }
    }
    
    private func metricCard(icon: String, iconColor: Color, iconBg: Color, value: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    // MARK: - Clientes Recientes
    @ViewBuilder
    private var recentClientsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Clientes recientes")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: { showCreateClientSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Nuevo")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(themeManager.accentColor)
                    .cornerRadius(10)
                }
                
                Button(action: onGoToClients) {
                    HStack(spacing: 2) {
                        Text("Ver todos")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)
                }
            }
            
            if pbManager.trainerClients.isEmpty {
                Text("No tienes clientes registrados todavía.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
            } else {
                let visibleClients = Array(pbManager.trainerClients.prefix(recentClientsLimit))
                ForEach(visibleClients) { client in
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        tabScrollManager.navigateToClientInClientsTab(client)
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor)
                                    .frame(width: 44, height: 44)
                                Text(client.initials)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text(client.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(client.isActive ? "activo" : "inactivo")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(client.isActive ? Color(hex: "34D399") : .gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((client.isActive ? Color(hex: "059669") : Color.gray).opacity(0.2))
                                .cornerRadius(12)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                
                if pbManager.trainerClients.count > recentClientsLimit {
                    Button(action: { recentClientsLimit += 3 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                            Text("Ver más clientes (\(pbManager.trainerClients.count - recentClientsLimit) restantes)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(themeManager.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Últimos Archivos Recibidos
    @ViewBuilder
    private var recentUploadsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Últimos archivos recibidos")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onGoToGallery) {
                    HStack(spacing: 2) {
                        Text("Ver todos")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)
                }
            }
            
            if pbManager.trainerUploads.isEmpty {
                Text("No has recibido fotos ni vídeos todavía.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
            } else {
                let visibleUploads = Array(pbManager.trainerUploads.prefix(4))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(visibleUploads) { upload in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            let targetClient = pbManager.trainerClients.first { $0.id == upload.client } ?? upload.expand?.client
                            tabScrollManager.navigateToUploadInGalleryTab(upload, client: targetClient)
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    if let fileName = upload.file,
                                       let url = pbManager.getFileURL(recordId: upload.id, fileName: fileName) {
                                        if upload.isVideo {
                                            GymVideoThumbnailView(url: url, authToken: pbManager.authToken)
                                                .frame(height: 100)
                                                .cornerRadius(10)
                                        } else {
                                            GymImageView(url: url, authToken: pbManager.authToken)
                                                .frame(height: 100)
                                                .cornerRadius(10)
                                                .clipped()
                                        }
                                    }
                                    
                                    // Punto indicador de nuevo
                                    if upload.seen_by_admin != true {
                                        Circle()
                                            .fill(themeManager.accentColor)
                                            .frame(width: 8, height: 8)
                                            .padding(6)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(upload.clientDisplayName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(upload.formattedUploadDate)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if pbManager.trainerUploads.count > 4 {
                    Button(action: onGoToGallery) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Ver más entregas en Galería (\(pbManager.trainerUploads.count - 4) restantes)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(themeManager.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - 2. PESTAÑA CLIENTES (TRAINER CLIENTS VIEW)

@MainActor
struct TrainerClientsView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    @State private var searchText: String = ""
    @State private var statusFilter: String = "Todos" // "Todos", "Activo", "Inactivo"
    @State private var showNewClientSheet: Bool = false
    
    var filteredClients: [GymUser] {
        pbManager.trainerClients.filter { client in
            let matchesSearch = searchText.isEmpty ||
                client.displayName.localizedCaseInsensitiveContains(searchText) ||
                client.email.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus: Bool
            if statusFilter == "Activo" {
                matchesStatus = client.isActive
            } else if statusFilter == "Inactivo" {
                matchesStatus = !client.isActive
            } else {
                matchesStatus = true
            }
            return matchesSearch && matchesStatus
        }
    }
    
    var body: some View {
        NavigationStack(path: $tabScrollManager.clientsPath) {
            ZStack {
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    TrainerHeaderView(title: "Clientes")
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Cabecera con Conteo y Botón "+ Nuevo"
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Clientes")
                                        .font(.system(size: 22, weight: .black))
                                        .foregroundColor(.white)
                                    Text("\(pbManager.trainerClients.count) registrados")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Button(action: {
                                    showNewClientSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Nuevo")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(themeManager.accentColor)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Barra de búsqueda
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Buscar cliente...", text: $searchText)
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            
                            // Filtros de píldoras
                            HStack(spacing: 8) {
                                ForEach(["Todos", "Activo", "Inactivo"], id: \.self) { pill in
                                    let isSelected = statusFilter == pill
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        statusFilter = pill
                                    }) {
                                        Text(pill)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 7)
                                            .background(isSelected ? themeManager.accentColor : Color.white.opacity(0.08))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            
                            // Lista de Clientes
                            if filteredClients.isEmpty {
                                Text(searchText.isEmpty ? "No tienes clientes aún." : "No se encontraron clientes con esa búsqueda.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 20)
                            } else {
                                ForEach(filteredClients) { client in
                                    NavigationLink(value: client) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(themeManager.accentColor)
                                                    .frame(width: 48, height: 48)
                                                Text(client.initials)
                                                    .font(.system(size: 16, weight: .heavy))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(client.displayName)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text(client.email)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(client.isActive ? "activo" : "inactivo")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(client.isActive ? Color(hex: "34D399") : .gray)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background((client.isActive ? Color(hex: "059669") : Color.gray).opacity(0.2))
                                                .cornerRadius(12)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(18)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GymUser.self) { client in
                TrainerClientDetailView(client: client)
            }
            .sheet(isPresented: $showNewClientSheet) {
                TrainerCreateClientSheet()
            }
        }
    }
}

// MARK: - Detalle del Cliente (Asignar Rutina, Dejar Nota, Ver Historial)

@MainActor
struct TrainerClientDetailView: View {
    let client: GymUser
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var clientUploads: [GymProgressUpload] = []
    @State private var clientNotesList: [GymClientNote] = []
    @State private var activeRoutine: GymRoutine? = nil
    @State private var isLoadingActiveRoutine: Bool = true
    @State private var isLoadingNotes: Bool = true
    
    @State private var notesLimit: Int = 3
    @State private var mediaLimit: Int = 3
    
    @State private var newNoteText: String = ""
    @State private var isSendingNote: Bool = false
    @State private var selectedRoutineToAssign: String = ""
    @State private var isAssigningRoutine: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var isActive: Bool = true
    @State private var isTogglingStatus: Bool = false
    @State private var showChangePasswordSheet: Bool = false
    @State private var showDeleteClientSheet: Bool = false
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Tarjeta Principal del Cliente
                    clientHeaderCard
                    
                    // Rutina Asignada Actual
                    activeRoutineCard
                    
                    // Asignar / Cambiar Rutina a este Cliente
                    assignRoutineCard
                    
                    // Dejar Nota / Feedback
                    leaveNoteCard
                    
                    // Historial de Notas del Cliente
                    clientNotesSection
                    
                    // Entregas de Media de este Cliente
                    clientUploadsSection
                }
                .padding()
                .padding(.bottom, 60)
            }
        }
        .navigationTitle(client.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isActive = client.isActive
            await loadClientData()
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            TrainerChangeClientPasswordSheet(client: client)
        }
        .sheet(isPresented: $showDeleteClientSheet) {
            TrainerDeleteClientSheet(client: client, onDeleted: {
                dismiss()
            })
        }
        .alert("Aviso", isPresented: $showAlert) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var clientHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isActive ? themeManager.accentColor : Color.gray.opacity(0.4))
                        .frame(width: 60, height: 60)
                    Text(client.initials)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(client.displayName)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                        // Píldora de estado
                        Text(isActive ? "Activo" : "Inactivo")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isActive ? .black : .white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isActive ? themeManager.accentColor : Color.red.opacity(0.7))
                            .cornerRadius(6)
                    }
                    Text(client.email)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text("Registrado: \(client.formattedJoinedDate)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            // Botones de acción del cliente
            HStack(spacing: 8) {
                // Botón toggle activar/desactivar
                Button(action: toggleClientStatus) {
                    HStack(spacing: 4) {
                        if isTogglingStatus {
                            ProgressView().tint(isActive ? .white : .black)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: isActive ? "person.slash.fill" : "person.fill.checkmark")
                            Text(isActive ? "Desactivar" : "Activar")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(isActive ? Color.orange.opacity(0.8) : themeManager.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isTogglingStatus)
                
                // Botón Cambiar Contraseña
                Button(action: { showChangePasswordSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text("Contraseña")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
                
                // Botón Eliminar Cliente
                Button(action: { showDeleteClientSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Eliminar")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private var activeRoutineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(themeManager.accentColor)
                Text("Rutina Actual Asignada")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            
            if isLoadingActiveRoutine {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if let routine = activeRoutine {
                NavigationLink(destination: TrainerRoutineDetailView(routine: routine)) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.accentColor)
                                .frame(width: 44, height: 44)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(routine.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            if let desc = routine.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                Text(routine.level ?? "General")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                                Text("•")
                                    .foregroundColor(.gray)
                                Text("\(routine.daysCount ?? 0) días")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text("Este alumno no tiene ninguna rutina activa asignada.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private var assignRoutineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Asignar / Cambiar Rutina")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            if pbManager.trainerRoutines.isEmpty {
                Text("No tienes rutinas creadas todavía para asignar.")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Picker("Seleccionar Rutina", selection: $selectedRoutineToAssign) {
                            Text("Seleccionar Rutina...").tag("")
                            ForEach(pbManager.trainerRoutines) { r in
                                Text(r.name).tag(r.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(themeManager.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    
                    Button(action: assignRoutine) {
                        HStack {
                            if isAssigningRoutine {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Asignar Rutina")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedRoutineToAssign.isEmpty ? Color.gray.opacity(0.5) : themeManager.accentColor)
                        .cornerRadius(12)
                    }
                    .disabled(selectedRoutineToAssign.isEmpty || isAssigningRoutine)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private var leaveNoteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dejar Nota al Cliente")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            TextField("Ej: Muy buena técnica en peso muerto...", text: $newNoteText, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .foregroundColor(.white)
            
            Button(action: sendNote) {
                HStack {
                    if isSendingNote {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Enviar Nota")
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeManager.accentColor)
                .cornerRadius(12)
            }
            .disabled(newNoteText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingNote)
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private func clientNoteRow(note: GymClientNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.content ?? "")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Text(note.formattedCreatedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Spacer()
                if note.seen == true {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("Leída por cliente")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var clientNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notas del Cliente (\(clientNotesList.count))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if isLoadingNotes {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if clientNotesList.isEmpty {
                Text("Aún no le has enviado notas a este cliente.")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                let visibleNotes = Array(clientNotesList.prefix(notesLimit))
                ForEach(visibleNotes) { note in
                    clientNoteRow(note: note)
                }
                
                if clientNotesList.count > notesLimit {
                    Button(action: { notesLimit += 3 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                            Text("Ver más notas (\(clientNotesList.count - notesLimit) restantes)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(themeManager.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    @ViewBuilder
    private var clientUploadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entregas de este cliente (\(clientUploads.count))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if clientUploads.isEmpty {
                Text("Este cliente aún no ha subido fotos ni vídeos.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let visibleUploads = Array(clientUploads.prefix(mediaLimit))
                ForEach(visibleUploads) { upload in
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        tabScrollManager.navigateToUploadInGalleryTab(upload, client: client)
                    }) {
                        HStack(spacing: 12) {
                            if let fileName = upload.file,
                               let url = pbManager.getFileURL(recordId: upload.id, fileName: fileName) {
                                if upload.isVideo {
                                    GymVideoThumbnailView(url: url, authToken: pbManager.authToken)
                                        .frame(width: 80, height: 60)
                                        .cornerRadius(8)
                                } else {
                                    GymImageView(url: url, authToken: pbManager.authToken)
                                        .frame(width: 80, height: 60)
                                        .cornerRadius(8)
                                        .clipped()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(upload.note ?? "Sin comentario")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(upload.formattedUploadDate)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(upload.seen_by_admin == true ? "Visto" : "Nuevo")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(upload.seen_by_admin == true ? .gray : themeManager.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                if clientUploads.count > mediaLimit {
                    Button(action: { mediaLimit += 3 }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                            Text("Ver más entregas (\(clientUploads.count - mediaLimit) restantes)")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(themeManager.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
    
    // MARK: - Actions
    
    private func loadClientData() async {
        if pbManager.trainerRoutines.isEmpty {
            _ = await pbManager.fetchTrainerRoutines()
        }
        
        self.clientUploads = pbManager.trainerUploads.filter { $0.client == client.id }
        
        // Cargar rutina activa del cliente
        self.isLoadingActiveRoutine = true
        self.activeRoutine = await pbManager.fetchActiveRoutineForClient(clientId: client.id)
        self.isLoadingActiveRoutine = false
        
        // Cargar notas del cliente
        self.isLoadingNotes = true
        self.clientNotesList = await pbManager.fetchNotesForClient(clientId: client.id)
        self.isLoadingNotes = false
    }
    
    private func toggleClientStatus() {
        isTogglingStatus = true
        let newStatus = isActive ? "inactivo" : "activo"
        Task {
            let res = await pbManager.setClientStatus(clientId: client.id, status: newStatus)
            await MainActor.run {
                isTogglingStatus = false
                if res.success {
                    isActive = !isActive
                    let estado = isActive ? "activado" : "desactivado"
                    alertMessage = "Cliente \(estado) correctamente."
                    showAlert = true
                } else {
                    alertMessage = res.message ?? "No se pudo cambiar el estado del cliente."
                    showAlert = true
                }
            }
        }
    }
    
    private func sendNote() {
        isSendingNote = true
        Task {
            let ok = await pbManager.sendNoteToClient(clientId: client.id, content: newNoteText)
            let freshNotes = await pbManager.fetchNotesForClient(clientId: client.id)
            await MainActor.run {
                isSendingNote = false
                if ok {
                    newNoteText = ""
                    clientNotesList = freshNotes
                    alertMessage = "Nota enviada al cliente con éxito."
                    showAlert = true
                } else {
                    alertMessage = "No se pudo enviar la nota."
                    showAlert = true
                }
            }
        }
    }
    
    private func assignRoutine() {
        guard !selectedRoutineToAssign.isEmpty else { return }
        isAssigningRoutine = true
        Task {
            let ok = await pbManager.assignRoutineToClient(clientId: client.id, routineId: selectedRoutineToAssign)
            let updatedRoutine = await pbManager.fetchActiveRoutineForClient(clientId: client.id)
            await MainActor.run {
                isAssigningRoutine = false
                if ok {
                    activeRoutine = updatedRoutine
                    alertMessage = "Rutina asignada correctamente."
                    showAlert = true
                } else {
                    alertMessage = "Error al asignar la rutina."
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Modal Crear Nuevo Cliente

@MainActor
struct TrainerCreateClientSheet: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedColorKey: String = "from-blue-500 to-blue-700"
    @State private var isCreating: Bool = false
    @State private var errorText: String? = nil
    
    struct AvatarColorOption: Identifiable {
        let id: String
        let name: String
        let colors: [Color]
    }
    
    private var colorOptions: [AvatarColorOption] {
        [
            AvatarColorOption(id: "from-blue-500 to-blue-700", name: "Azul", colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")]),
            AvatarColorOption(id: "from-purple-500 to-purple-700", name: "Púrpura", colors: [Color(hex: "A855F7"), Color(hex: "7E22CE")]),
            AvatarColorOption(id: "from-emerald-500 to-emerald-700", name: "Esmeralda", colors: [Color(hex: "10B981"), Color(hex: "047857")]),
            AvatarColorOption(id: "from-orange-500 to-orange-700", name: "Naranja", colors: [Color(hex: "F97316"), Color(hex: "C2410C")]),
            AvatarColorOption(id: "from-rose-500 to-rose-700", name: "Rosa", colors: [Color(hex: "F43F5E"), Color(hex: "BE123C")]),
            AvatarColorOption(id: "from-brand to-accent-dark", name: "Dorado", colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.65)])
        ]
    }
    
    private var computedInitials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let f = parts[0].first, let s = parts[1].first {
            return "\(f)\(s)".uppercased()
        } else if let f = trimmed.first {
            return "\(f)".uppercased()
        }
        return "?"
    }
    
    private var selectedColors: [Color] {
        colorOptions.first(where: { $0.id == selectedColorKey })?.colors ?? [Color.blue, Color.cyan]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Crear Nuevo Alumno")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                        
                        // Vista Previa de Avatar & Color
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: selectedColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)
                                    .shadow(color: selectedColors.first?.opacity(0.4) ?? .clear, radius: 8)
                                
                                Text(computedInitials)
                                    .font(.system(size: 24, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Foto de Perfil (Web)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Degradado e iniciales para el avatar del alumno")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        
                        // Selector de colores del avatar
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color del avatar")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 12) {
                                ForEach(colorOptions) { opt in
                                    Button(action: {
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        selectedColorKey = opt.id
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: opt.colors,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 36, height: 36)
                                            
                                            if selectedColorKey == opt.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColorKey == opt.id ? Color.white : Color.clear, lineWidth: 2)
                                                .padding(-2)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Campos de Formulario
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nombre completo")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Carlos Martínez", text: $name)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email de acceso")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("alumno@gym.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Contraseña inicial (temporal)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            SecureField("••••••••", text: $password)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                            Text("Al iniciar sesión por primera vez con esta clave temporal, se le exigirá al alumno cambiarla.")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        
                        if let err = errorText {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: createClient) {
                            HStack {
                                if isCreating {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("Crear y Asignar a mi Cuenta")
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.accentColor)
                            .cornerRadius(14)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || email.isEmpty || password.count < 8 || isCreating)
                        .opacity((name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || email.isEmpty || password.count < 8 || isCreating) ? 0.6 : 1.0)
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func createClient() {
        isCreating = true
        errorText = nil
        Task {
            let result = await pbManager.createClient(
                email: email,
                name: name,
                password: password,
                color: selectedColorKey
            )
            await MainActor.run {
                isCreating = false
                if result.success {
                    dismiss()
                } else {
                    errorText = result.message ?? "Error al crear cliente. Verifica que el email no esté repetido."
                }
            }
        }
    }
}

// MARK: - Sheet para cambiar la contraseña de un cliente por parte del Administrador

@MainActor
struct TrainerChangeClientPasswordSheet: View {
    let client: GymUser
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorText: String? = nil
    @State private var isSubmitting: Bool = false
    @State private var successText: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cambiar contraseña de \(client.displayName)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("La nueva contraseña será temporal y se le exigirá cambiarla al cliente la próxima vez que inicie sesión.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nueva Contraseña Temporal")
                            .font(.caption)
                            .foregroundColor(.gray)
                        SecureField("Mínimo 8 caracteres", text: $newPassword)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirmar Nueva Contraseña")
                            .font(.caption)
                            .foregroundColor(.gray)
                        SecureField("Repite la contraseña", text: $confirmPassword)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    if let err = errorText {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if let succ = successText {
                        Text(succ)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button(action: changePassword) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "key.fill")
                                Text("Guardar Nueva Contraseña")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentColor)
                        .cornerRadius(14)
                    }
                    .disabled(newPassword.count < 8 || newPassword != confirmPassword || isSubmitting)
                    .opacity((newPassword.count < 8 || newPassword != confirmPassword || isSubmitting) ? 0.6 : 1.0)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorText = "Las contraseñas no coinciden."
            return
        }
        
        isSubmitting = true
        errorText = nil
        successText = nil
        
        Task {
            let res = await pbManager.changeClientPassword(clientId: client.id, newPassword: newPassword)
            await MainActor.run {
                isSubmitting = false
                if res.success {
                    successText = res.message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                } else {
                    errorText = res.message
                }
            }
        }
    }
}

// MARK: - Sheet para eliminar un cliente de forma permanente con confirmación explícita

@MainActor
struct TrainerDeleteClientSheet: View {
    let client: GymUser
    var onDeleted: () -> Void = {}
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var confirmInput: String = ""
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    
    var canDelete: Bool {
        confirmInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "confirmar"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Eliminar Cliente")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.white)
                            Text(client.displayName)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    Text("Esta acción eliminará de forma PERMANENTE al usuario '\(client.displayName)' y todos sus registros del servidor. No se puede deshacer.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Escribe 'confirmar' manualmente para habilitar el borrado:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        
                        TextField("Escribe 'confirmar'", text: $confirmInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(canDelete ? Color.red : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button(action: deleteClient) {
                        HStack {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Eliminar de forma permanente")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canDelete ? Color.red : Color.red.opacity(0.3))
                        .cornerRadius(14)
                    }
                    .disabled(!canDelete || isDeleting)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func deleteClient() {
        isDeleting = true
        errorMessage = nil
        Task {
            let res = await pbManager.deleteClientAccount(clientId: client.id)
            await MainActor.run {
                isDeleting = false
                if res.success {
                    onDeleted()
                    dismiss()
                } else {
                    errorMessage = res.message
                }
            }
        }
    }
}

// MARK: - 3. PESTAÑA RUTINAS (TRAINER ROUTINES VIEW)

@MainActor
struct TrainerRoutinesView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    @State private var searchText: String = ""
    @State private var showCreateRoutineSheet: Bool = false
    @State private var routineToDelete: GymRoutine? = nil
    @State private var showDeleteConfirm: Bool = false
    
    var filteredRoutines: [GymRoutine] {
        if searchText.isEmpty {
            return pbManager.trainerRoutines
        }
        return pbManager.trainerRoutines.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack(path: $tabScrollManager.routinesPath) {
            ZStack {
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    TrainerHeaderView(title: "Rutinas")
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Cabecera con Conteo y Botón "+ Crear"
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Rutinas")
                                        .font(.system(size: 22, weight: .black))
                                        .foregroundColor(.white)
                                    Text("\(pbManager.trainerRoutines.count) disponibles")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Button(action: {
                                    showCreateRoutineSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Crear")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(themeManager.accentColor)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Barra de Búsqueda
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Buscar rutina...", text: $searchText)
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(14)
                            
                            // Lista de Rutinas
                            if filteredRoutines.isEmpty {
                                Text(searchText.isEmpty ? "No tienes rutinas creadas todavía." : "No se encontraron rutinas.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 20)
                            } else {
                                ForEach(filteredRoutines) { routine in
                                    NavigationLink(destination: TrainerRoutineDetailView(routine: routine)) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(themeManager.accentColor)
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: "dumbbell.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(routine.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                if let desc = routine.description, !desc.isEmpty {
                                                    Text(desc)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                }
                                                
                                                HStack(spacing: 4) {
                                                    Text(routine.level ?? "Intermedio")
                                                    Text("•")
                                                    Text("\(routine.daysCount ?? 0) días")
                                                }
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            // Acciones: Borrar
                                            Button(action: {
                                                routineToDelete = routine
                                                showDeleteConfirm = true
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.gray)
                                                    .padding(8)
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(18)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await pbManager.fetchTrainerRoutines()
            }
            .sheet(isPresented: $showCreateRoutineSheet) {
                TrainerCreateRoutineSheet()
            }
            .alert("¿Eliminar rutina?", isPresented: $showDeleteConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Eliminar", role: .destructive) {
                    if let r = routineToDelete {
                        Task { _ = await pbManager.deleteRoutine(routineId: r.id) }
                    }
                }
            } message: {
                Text("Se eliminará la rutina '\(routineToDelete?.name ?? "")' permanentemente.")
            }
        }
    }
}

// MARK: - Detalle de Rutina (Días y Ejercicios)

@MainActor
struct TrainerRoutineDetailView: View {
    let routine: GymRoutine
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var days: [GymRoutineDay] = []
    @State private var isLoading: Bool = true
    @State private var showAddDaySheet: Bool = false
    @State private var editingDay: GymRoutineDay? = nil
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header de la rutina
                    VStack(alignment: .leading, spacing: 6) {
                        Text(routine.name)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                        if let desc = routine.description {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        HStack(spacing: 8) {
                            Text(routine.level ?? "General")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.accentColor)
                                .cornerRadius(8)
                            Text("\(days.count) días configurados")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(18)
                    
                    // Lista de Días
                    HStack {
                        Text("Días de entrenamiento")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showAddDaySheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Añadir Día")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.accentColor)
                            .cornerRadius(10)
                        }
                    }
                    
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if days.isEmpty {
                        Text("Esta rutina no tiene días configurados todavía.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(days) { day in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(day.title)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(themeManager.accentColor)
                                    Spacer()
                                    Button(action: { editingDay = day }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "pencil")
                                            Text("Editar")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                if let content = day.content, !content.isEmpty {
                                    Text(content)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 60)
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadDays()
        }
        .sheet(isPresented: $showAddDaySheet) {
            TrainerAddRoutineDaySheet(routineId: routine.id) {
                loadDays()
            }
        }
        .sheet(item: $editingDay) { day in
            TrainerEditRoutineDaySheet(day: day) {
                loadDays()
            }
        }
    }
    
    private func loadDays() {
        isLoading = true
        Task {
            let loaded = await pbManager.fetchRoutineDaysForRoutine(routineId: routine.id)
            await MainActor.run {
                self.days = loaded
                self.isLoading = false
            }
        }
    }
}

// MARK: - Modal Crear Rutina

@MainActor
struct TrainerCreateRoutineSheet: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var level: String = "Intermedio"
    @State private var isCreating: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(alignment: .leading, spacing: 18) {
                    Text("Crear Nueva Rutina")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre de la rutina")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Ej: Push Pull Legs", text: $name)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Descripción")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Rutina de hipertrofia y fuerza...", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nivel")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Picker("Nivel", selection: $level) {
                            ForEach(["Principiante", "Intermedio", "Avanzado"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Spacer()
                    
                    Button(action: createRoutine) {
                        HStack {
                            if isCreating {
                                ProgressView().tint(.black)
                            } else {
                                Text("Guardar Rutina")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentColor)
                        .cornerRadius(14)
                    }
                    .disabled(name.isEmpty || isCreating)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func createRoutine() {
        isCreating = true
        Task {
            let ok = await pbManager.createRoutine(name: name, description: description, level: level)
            await MainActor.run {
                isCreating = false
                if ok { dismiss() }
            }
        }
    }
}

// MARK: - Modal Añadir Día a Rutina

@MainActor
struct TrainerAddRoutineDaySheet: View {
    let routineId: String
    var onSaved: () -> Void = {}
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var dayName: String = ""
    @State private var content: String = ""
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                VStack(alignment: .leading, spacing: 18) {
                    Text("Añadir Día de Entrenamiento")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre del día")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Ej: Día 1: Pecho y Tríceps", text: $dayName)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contenido y ejercicios")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $content)
                            .scrollContentBackground(.hidden)
                            .frame(height: 150)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: saveDay) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("Guardar Día")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentColor)
                        .cornerRadius(14)
                    }
                    .disabled(dayName.isEmpty || isSaving)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private func saveDay() {
        isSaving = true
        Task {
            let ok = await pbManager.addRoutineDay(routineId: routineId, dayName: dayName, content: content)
            await MainActor.run {
                isSaving = false
                if ok {
                    onSaved()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Modal Editar Día de Rutina

@MainActor
struct TrainerEditRoutineDaySheet: View {
    let day: GymRoutineDay
    var onSaved: () -> Void = {}
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var dayName: String = ""
    @State private var content: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Editar Día de Entrenamiento")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre del día")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Ej: Día 1: Pecho y Tríceps", text: $dayName)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contenido y ejercicios")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $content)
                            .scrollContentBackground(.hidden)
                            .frame(height: 180)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: saveDay) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("Guardar Cambios")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.accentColor)
                        .cornerRadius(14)
                    }
                    .disabled(dayName.isEmpty || isSaving)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            dayName = day.day_name ?? ""
            content = day.content ?? ""
        }
    }

    private func saveDay() {
        isSaving = true
        Task {
            let ok = await pbManager.updateRoutineDay(dayId: day.id, dayName: dayName, content: content)
            await MainActor.run {
                isSaving = false
                if ok {
                    onSaved()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - 4. PESTAÑA GALERÍA (TRAINER GALLERY VIEW)

@MainActor
struct TrainerGalleryView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabScrollManager: TabScrollManager
    
    @State private var filterState: String = "Pendiente" // "Todos", "Pendiente", "Visto"
    
    // Agrupar las entregas por cliente
    var clientsWithUploads: [(client: GymUser, uploads: [GymProgressUpload])] {
        let clients = pbManager.trainerClients
        var result: [(client: GymUser, uploads: [GymProgressUpload])] = []
        
        for client in clients {
            let clientUploads = pbManager.trainerUploads.filter { upload in
                guard upload.client == client.id else { return false }
                if filterState == "Pendiente" {
                    return upload.seen_by_admin != true
                } else if filterState == "Visto" {
                    return upload.seen_by_admin == true
                }
                return true
            }
            if !clientUploads.isEmpty {
                result.append((client: client, uploads: clientUploads))
            }
        }
        
        // Entregas de clientes no encontrados en la lista principal
        let knownClientIds = Set(clients.map { $0.id })
        let orphanUploads = pbManager.trainerUploads.filter { upload in
            guard let cid = upload.client, !knownClientIds.contains(cid) else { return false }
            if filterState == "Pendiente" {
                return upload.seen_by_admin != true
            } else if filterState == "Visto" {
                return upload.seen_by_admin == true
            }
            return true
        }
        
        if !orphanUploads.isEmpty {
            let dummyUser = GymUser(id: orphanUploads.first?.client ?? "unknown", email: "alumno@gym.com", name: orphanUploads.first?.clientDisplayName ?? "Alumno")
            result.append((client: dummyUser, uploads: orphanUploads))
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack(path: $tabScrollManager.galleryPath) {
            ZStack {
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    TrainerHeaderView(title: "Galería por Cliente")
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Cabecera
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Galería por Alumno")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.white)
                                Text("\(pbManager.pendingReviewsCount) pendientes de revisión")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            
                            // Píldoras de filtro (Todos, Pendiente, Visto)
                            HStack(spacing: 8) {
                                ForEach(["Todos", "Pendiente", "Visto"], id: \.self) { pill in
                                    let isSelected = filterState == pill
                                    Button(action: {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        filterState = pill
                                    }) {
                                        Text(pill)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 7)
                                            .background(isSelected ? themeManager.accentColor : Color.white.opacity(0.08))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            
                            // Lista de Clientes agrupados
                            if clientsWithUploads.isEmpty {
                                Text("No hay entregas en esta categoría.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(clientsWithUploads, id: \.client.id) { item in
                                    clientGalleryGroupCard(client: item.client, uploads: item.uploads)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GymUser.self) { client in
                TrainerClientGalleryView(client: client)
            }
            .navigationDestination(for: GymProgressUpload.self) { upload in
                TrainerUploadDetailView(upload: upload)
            }
        }
    }
    
    // Tarjeta del cliente agrupando sus entregas en la Galería
    @ViewBuilder
    private func clientGalleryGroupCard(client: GymUser, uploads: [GymProgressUpload]) -> some View {
        let pendingCount = uploads.filter { $0.seen_by_admin != true }.count
        
        VStack(alignment: .leading, spacing: 14) {
            // Cabecera del Cliente
            NavigationLink(value: client) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeManager.accentColor)
                            .frame(width: 44, height: 44)
                        Text(client.initials)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(uploads.count) entregas" + (pendingCount > 0 ? " • \(pendingCount) pendientes" : ""))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Ver álbum")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.accentColor)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Miniaturas de las entregas de este cliente (máximo 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(uploads.prefix(4)) { upload in
                    NavigationLink(value: upload) {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                if let fileName = upload.file,
                                   let url = pbManager.getFileURL(recordId: upload.id, fileName: fileName) {
                                    if upload.isVideo {
                                        GymVideoThumbnailView(url: url, authToken: pbManager.authToken)
                                            .frame(height: 110)
                                            .cornerRadius(12)
                                    } else {
                                        GymImageView(url: url, authToken: pbManager.authToken)
                                            .frame(height: 110)
                                            .cornerRadius(12)
                                            .clipped()
                                    }
                                }
                                
                                if upload.seen_by_admin != true {
                                    Text("Nuevo")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(themeManager.accentColor)
                                        .cornerRadius(6)
                                        .padding(6)
                                }
                            }
                            
                            Text(upload.formattedUploadDate)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
        .contentShape(Rectangle())
    }
}

// MARK: - Galería Individual de un Cliente

@MainActor
struct TrainerClientGalleryView: View {
    let client: GymUser
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var filterState: String = "Todos" // "Todos", "Pendiente", "Visto"
    
    var clientUploads: [GymProgressUpload] {
        pbManager.trainerUploads.filter { upload in
            guard upload.client == client.id else { return false }
            if filterState == "Pendiente" {
                return upload.seen_by_admin != true
            } else if filterState == "Visto" {
                return upload.seen_by_admin == true
            }
            return true
        }
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Cabecera Cliente
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 48, height: 48)
                            Text(client.initials)
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Galería de \(client.displayName)")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                            Text("\(clientUploads.count) entregas en total")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    
                    // Píldoras de filtro
                    HStack(spacing: 8) {
                        ForEach(["Todos", "Pendiente", "Visto"], id: \.self) { pill in
                            let isSelected = filterState == pill
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                filterState = pill
                            }) {
                                Text(pill)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? themeManager.accentColor : Color.white.opacity(0.08))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    
                    // Lista de entregas del cliente
                    if clientUploads.isEmpty {
                        Text("Este cliente no tiene entregas en esta categoría.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(clientUploads) { upload in
                            NavigationLink(value: upload) {
                                trainerUploadCard(upload: upload)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .padding(.bottom, 60)
            }
        }
        .navigationTitle(client.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func trainerUploadCard(upload: GymProgressUpload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if let fileName = upload.file,
                   let url = pbManager.getFileURL(recordId: upload.id, fileName: fileName) {
                    if upload.isVideo {
                        GymVideoThumbnailView(url: url, authToken: pbManager.authToken)
                            .frame(height: 200)
                            .cornerRadius(14)
                    } else {
                        GymImageView(url: url, authToken: pbManager.authToken)
                            .frame(height: 200)
                            .cornerRadius(14)
                            .clipped()
                    }
                }
                
                if upload.seen_by_admin != true {
                    Text("Nuevo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(themeManager.accentColor)
                        .cornerRadius(8)
                        .padding(10)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(upload.formattedUploadDate)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    if let note = upload.notes, !note.isEmpty {
                        Text("\"\(note)\"")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            
            if upload.seen_by_admin != true {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    Task {
                        _ = await pbManager.markUploadAsSeen(uploadId: upload.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("Marcar como visto")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(themeManager.accentColor.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.accentColor.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.borderless)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "34D399"))
                    Text("Revisado por ti")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(18)
    }
}

// MARK: - Vista Detalle de Entrega (Reproducir y Enviar Feedback)

@MainActor
struct TrainerUploadDetailView: View {
    let upload: GymProgressUpload
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var feedbackText: String = ""
    @State private var isSendingFeedback: Bool = false
    @State private var feedbackSentSuccess: Bool = false
    @State private var isPresentingMediaViewer: Bool = false
    @State private var isSeen: Bool = false
    @State private var isMarkingSeen: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var isDeleting: Bool = false
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Estado de revisión (Insignia limpia sin botón duplicado)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isSeen ? Color(hex: "34D399") : .orange)
                                    .frame(width: 8, height: 8)
                                Text(isSeen ? "Estado: Revisado por ti" : "Estado: Pendiente de revisión")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(isSeen ? Color(hex: "34D399") : .orange)
                            }
                            Text(isSeen ? "Usa el botón superior derecho si deseas marcarlo como pendiente." : "Usa el botón superior derecho para marcar la entrega como revisada.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)


                    // Visor de foto o vídeo (al pulsar se abre el visor modal en pantalla completa)
                    if let fileName = upload.file,
                       let url = pbManager.getFileURL(recordId: upload.id, fileName: fileName) {
                        ZStack(alignment: .bottomTrailing) {
                            if upload.isVideo {
                                GymVideoThumbnailView(url: url, authToken: pbManager.authToken, showPlayButton: true)
                                    .frame(height: 320)
                                    .cornerRadius(16)
                                    .clipped()
                            } else {
                                GymImageView(url: url, authToken: pbManager.authToken)
                                    .frame(maxHeight: 320)
                                    .cornerRadius(16)
                                    .clipped()
                            }
                            
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                Text("Ver en grande")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding(10)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            isPresentingMediaViewer = true
                        }
                    }
                    
                    // Datos del cliente
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 44, height: 44)
                            Text(upload.clientDisplayName.prefix(2).uppercased())
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(upload.clientDisplayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Enviado el \(upload.formattedUploadDate)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    
                    // Comentario del cliente
                    if let note = upload.notes, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mensaje del Alumno")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                            Text("\"\(note)\"")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .italic()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(14)
                    }
                    
                    // Formulario de Feedback / Corrección del entrenador
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enviar Respuesta / Feedback")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        TextEditor(text: $feedbackText)
                            .scrollContentBackground(.hidden)
                            .frame(height: 110)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                        
                        Button(action: sendFeedback) {
                            HStack {
                                if isSendingFeedback {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Enviar Corrección al Alumno")
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeManager.accentColor)
                            .cornerRadius(12)
                        }
                        .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingFeedback)
                        
                        if feedbackSentSuccess {
                            Text("¡Feedback guardado y notificado al alumno!")
                                .font(.caption)
                                .foregroundColor(Color(hex: "34D399"))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)

                    // Zona de Administración: Botón Borrar Entrega
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView().tint(.red)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Borrar archivo permanentemente")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .disabled(isDeleting)
                }
                .padding()
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Revisión de Entrega")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    toggleReviewed()
                }) {
                    HStack(spacing: 5) {
                        if isMarkingSeen {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: isSeen ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(isSeen ? "Quitar visto" : "Marcar visto")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundColor(isSeen ? Color(hex: "34D399") : themeManager.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(isMarkingSeen)
            }
        }
        .alert("¿Eliminar archivo?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                deleteUpload()
            }
        } message: {
            Text("Esta acción eliminará de forma permanente esta foto o vídeo del servidor.")
        }
        .fullScreenCover(isPresented: $isPresentingMediaViewer) {
            GymMediaViewerModal(item: upload)
        }
        .onAppear {
            isSeen = upload.seen_by_admin == true
            if let existing = upload.admin_response {
                feedbackText = existing
            }
        }
    }
    
    private func deleteUpload() {
        isDeleting = true
        Task {
            let ok = await pbManager.deleteProgressUpload(id: upload.id)
            await MainActor.run {
                isDeleting = false
                if ok {
                    dismiss()
                }
            }
        }
    }
    
    private func toggleReviewed() {
        guard !isMarkingSeen else { return }
        isMarkingSeen = true
        let newValue = !isSeen
        withAnimation(.easeInOut(duration: 0.2)) {
            isSeen = newValue
        }
        Task {
            let ok = await pbManager.markUploadAsSeen(uploadId: upload.id, seen: newValue)
            await MainActor.run {
                isMarkingSeen = false
                if !ok {
                    withAnimation {
                        isSeen = !newValue
                    }
                }
            }
        }
    }
    
    private func sendFeedback() {
        isSendingFeedback = true
        Task {
            let ok = await pbManager.sendAdminFeedback(uploadId: upload.id, responseText: feedbackText)
            await MainActor.run {
                isSendingFeedback = false
                if ok {
                    feedbackSentSuccess = true
                    isSeen = true
                }
            }
        }
    }
}
