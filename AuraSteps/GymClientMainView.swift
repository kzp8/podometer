import SwiftUI

/// Vista contenedora principal de las 4 pestañas del cliente (Inicio, Mi Rutina, Galería, Subir) replicando exactamente la barra inferior de la app web.
@MainActor
struct GymClientMainView: View {
    @EnvironmentObject var pbManager: PocketBaseManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab: Int = 0
    @State private var showUploadSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Contenido de las Pestañas
            Group {
                switch selectedTab {
                case 0:
                    GymDashboardView(onNavigateToRoutine: {
                        selectedTab = 1
                    })
                case 1:
                    GymRoutineView()
                case 2:
                    GymGalleryView()
                default:
                    GymDashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Barra de Navegación Inferior Estilo Web App
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.1))
                
                HStack(alignment: .center) {
                    // 1. Inicio
                    Button(action: {
                        selectedTab = 0
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2.fill")
                                .font(.system(size: 20))
                            Text("Inicio")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == 0 ? .purple : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 2. Mi Rutina
                    Button(action: {
                        selectedTab = 1
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 20))
                            Text("Mi Rutina")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == 1 ? .purple : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 3. Galería
                    Button(action: {
                        selectedTab = 2
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 20))
                            Text("Galería")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == 2 ? .purple : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 4. Botón Flotante Púrpura "Subir"
                    Button(action: {
                        showUploadSheet = true
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.purple.opacity(0.4), radius: 6)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Subir")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(red: 0.06, green: 0.06, blue: 0.08))
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            GymProgressUploadView()
                .environmentObject(pbManager)
                .environmentObject(themeManager)
        }
    }
}
