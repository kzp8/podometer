import SwiftUI
import Combine

/// Gestiona la navegación y los eventos de scroll a la parte superior entre pestañas.
@MainActor
public final class TabScrollManager: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var scrollEvent: TabScrollEvent? = nil
    
    // Rutas de navegación independientes para las pestañas del entrenador
    @Published public var clientsPath: NavigationPath = NavigationPath()
    @Published public var galleryPath: NavigationPath = NavigationPath()
    @Published public var routinesPath: NavigationPath = NavigationPath()
    
    public struct TabScrollEvent: Equatable {
        public let tab: Int
        public let animated: Bool
        public let id = UUID()
        
        public static func == (lhs: TabScrollEvent, rhs: TabScrollEvent) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public init() {}
    
    /// Cambia a la pestaña indicada.
    /// Al cambiar manualmente o volver a pulsar la pestaña activa, se reinicia la pila de navegación de esa pestaña a la raíz.
    public func selectTab(_ tab: Int) {
        // Reiniciar la navegación de la pestaña seleccionada a su pantalla base
        resetPathForTab(tab)
        
        if selectedTab == tab {
            scrollEvent = TabScrollEvent(tab: tab, animated: true)
        } else {
            scrollEvent = TabScrollEvent(tab: tab, animated: false)
            selectedTab = tab
        }
    }
    
    public func resetPathForTab(_ tab: Int) {
        switch tab {
        case 2:
            clientsPath = NavigationPath()
        case 3:
            routinesPath = NavigationPath()
        case 4:
            galleryPath = NavigationPath()
        default:
            break
        }
    }
    
    /// Navega a la pestaña de Clientes y abre el detalle de un cliente específico.
    public func navigateToClientInClientsTab(_ client: GymUser) {
        var newPath = NavigationPath()
        newPath.append(client)
        clientsPath = newPath
        selectedTab = 2 // Pestaña Clientes
    }
    
    /// Navega a la pestaña de Galería, navegando primero al cliente y luego a la entrega de media concreta.
    public func navigateToUploadInGalleryTab(_ upload: GymProgressUpload, client: GymUser?) {
        var newPath = NavigationPath()
        if let client = client {
            newPath.append(client)
        }
        newPath.append(upload)
        galleryPath = newPath
        selectedTab = 4 // Pestaña Galería
    }
    
    public func requestScrollToTop(_ tab: Int, animated: Bool = true) {
        scrollEvent = TabScrollEvent(tab: tab, animated: animated)
    }
}
