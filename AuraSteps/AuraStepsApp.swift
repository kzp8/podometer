import SwiftUI

@main
struct AuraStepsApp: App {
    @State private var motionManager = StepMotionManager()
    @State private var deepLinkManager = DeepLinkManager()
    @State private var dispatcher = WebhookDispatcher()
    
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
            .environment(motionManager)
            .environment(deepLinkManager)
            .environment(dispatcher)
            .onOpenURL { url in
                deepLinkManager.handleURL(url)
            }
            .task {
                await motionManager.requestHealthKitAuthorization()
            }
        }
    }
}
