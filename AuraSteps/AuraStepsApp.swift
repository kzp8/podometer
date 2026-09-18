import SwiftUI
import HealthKit

@main
struct AuraStepsApp: App {
    @StateObject private var motionManager = StepMotionManager()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var dispatcher = WebhookDispatcher()
    @StateObject private var userSettings = UserSettingsManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var achievementsManager = AchievementsManager()
    @StateObject private var pocketBaseManager = PocketBaseManager()
    
    @State private var selectedTab: Int = 0
    @State private var showOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                if pocketBaseManager.isLoggedIn {
                    GymDashboardView(onNavigateToRoutine: {
                        selectedTab = 2 // Mi Rutina
                    })
                    .tabItem {
                        Label("Inicio", systemImage: "house.fill")
                    }
                    .tag(0)
                    
                    DashboardView()
                        .tabItem {
                            Label("Pasos", systemImage: "figure.walk")
                        }
                        .tag(1)
                    
                    GymRoutineView()
                        .tabItem {
                            Label("Mi Rutina", systemImage: "dumbbell.fill")
                        }
                        .tag(2)
                    
                    GymGalleryView()
                        .tabItem {
                            Label("Galería", systemImage: "photo.stack.fill")
                        }
                        .tag(3)
                    
                    SettingsView()
                        .tabItem {
                            Label("Ajustes", systemImage: "gearshape.fill")
                        }
                        .tag(4)
                } else {
                    DashboardView()
                        .tabItem {
                            Label("Pasos", systemImage: "figure.walk")
                        }
                        .tag(0)
                    
                    SettingsView()
                        .tabItem {
                            Label("Ajustes", systemImage: "gearshape.fill")
                        }
                        .tag(1)
                }
            }
            .tint(themeManager.accentColor)
            .preferredColorScheme(.dark)
            .environmentObject(motionManager)
            .environmentObject(deepLinkManager)
            .environmentObject(dispatcher)
            .environmentObject(userSettings)
            .environmentObject(themeManager)
            .environmentObject(notificationManager)
            .environmentObject(achievementsManager)
            .environmentObject(pocketBaseManager)
            .onOpenURL { url in
                deepLinkManager.handleURL(url)
            }
            .onAppear {
                if !userSettings.hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                WelcomeOnboardingView {
                    showOnboarding = false
                }
                .environmentObject(userSettings)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .environmentObject(achievementsManager)
                .interactiveDismissDisabled(true)
            }
            .task {
                if HKHealthStore.isHealthDataAvailable() {
                    await motionManager.requestHealthKitAuthorization()
                }
            }
        }
    }
}
