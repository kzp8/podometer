import SwiftUI
import Combine

/// Gestiona la navegación y los eventos de scroll a la parte superior entre pestañas.
@MainActor
public final class TabScrollManager: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var scrollEvent: TabScrollEvent? = nil
    
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
    /// Si ya estamos en ella, hace scroll suave arriba.
    /// Si venimos de otra pestaña, reubica arriba inmediatamente para que al entrar se muestre la cabecera.
    public func selectTab(_ tab: Int) {
        if selectedTab == tab {
            scrollEvent = TabScrollEvent(tab: tab, animated: true)
        } else {
            scrollEvent = TabScrollEvent(tab: tab, animated: false)
            selectedTab = tab
        }
    }
    
    public func requestScrollToTop(_ tab: Int, animated: Bool = true) {
        scrollEvent = TabScrollEvent(tab: tab, animated: animated)
    }
}
