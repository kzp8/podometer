import SwiftUI

@main
struct AuraStepsApp: App {
    @StateObject private var motionManager = StepMotionManager()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var dispatcher = WebhookDispatcher()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Pasos", systemImage: "figure.walk")
                    }
                
                ConnectionsView()
                    .tabItem {
                        Label("Conexiones", systemImage: "network")
                    }
            }
            .tint(Color(red: 163/255, green: 230/255, blue: 53/255))
            .preferredColorScheme(.dark)
            .environmentObject(motionManager)
            .environmentObject(deepLinkManager)
            .environmentObject(dispatcher)
            .onOpenURL { url in
                deepLinkManager.handleURL(url)
            }
            .task {
                await motionManager.requestHealthKitAuthorization()
            }
        }
    }
}
