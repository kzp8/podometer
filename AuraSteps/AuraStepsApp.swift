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
    @StateObject private var tabScrollManager = TabScrollManager()
    
    @State private var showOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AppBackgroundView()
                
                ZStack {
                    if pocketBaseManager.isLoggedIn {
                        DashboardView()
                            .opacity(tabScrollManager.selectedTab == 0 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 0)
                        
                        GymDashboardView(onNavigateToRoutine: {
                            tabScrollManager.selectTab(2) // Mi Rutina
                        })
                        .opacity(tabScrollManager.selectedTab == 1 ? 1 : 0)
                        .allowsHitTesting(tabScrollManager.selectedTab == 1)
                        
                        GymRoutineView()
                            .opacity(tabScrollManager.selectedTab == 2 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 2)
                        
                        GymGalleryView()
                            .opacity(tabScrollManager.selectedTab == 3 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 3)
                        
                        SettingsView(tabIndex: 4)
                            .opacity(tabScrollManager.selectedTab == 4 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 4)
                    } else {
                        DashboardView()
                            .opacity(tabScrollManager.selectedTab == 0 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 0)
                        
                        SettingsView(tabIndex: 1)
                            .opacity(tabScrollManager.selectedTab == 1 ? 1 : 0)
                            .allowsHitTesting(tabScrollManager.selectedTab == 1)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: tabScrollManager.selectedTab)
                .safeAreaInset(edge: .bottom) {
                    CustomAnimatedTabBar(isLoggedIn: pocketBaseManager.isLoggedIn)
                }
            }
            .onChange(of: pocketBaseManager.isLoggedIn) { loggedIn in
                if !loggedIn && tabScrollManager.selectedTab > 1 {
                    tabScrollManager.selectTab(0)
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
            .environmentObject(tabScrollManager)
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

// MARK: - Barra de Pestañas Animada con Hitbox Ampliada y Material Traslúcido

@MainActor
struct CustomAnimatedTabBar: View {
    @EnvironmentObject var tabScrollManager: TabScrollManager
    let isLoggedIn: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @Namespace private var tabAnimationNamespace
    
    struct TabItemData: Identifiable {
        let tag: Int
        let label: String
        let icon: String
        var id: Int { tag }
    }
    
    var tabs: [TabItemData] {
        if isLoggedIn {
            return [
                TabItemData(tag: 0, label: "Pasos", icon: "figure.walk"),
                TabItemData(tag: 1, label: "Inicio", icon: "house.fill"),
                TabItemData(tag: 2, label: "Mi Rutina", icon: "dumbbell.fill"),
                TabItemData(tag: 3, label: "Galería", icon: "photo.stack.fill"),
                TabItemData(tag: 4, label: "Ajustes", icon: "gearshape.fill")
            ]
        } else {
            return [
                TabItemData(tag: 0, label: "Pasos", icon: "figure.walk"),
                TabItemData(tag: 1, label: "Ajustes", icon: "gearshape.fill")
            ]
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isSelected = tabScrollManager.selectedTab == tab.tag
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    tabScrollManager.selectTab(tab.tag)
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(themeManager.accentColor.opacity(0.18))
                                    .frame(width: 48, height: 28)
                                    .matchedGeometryEffect(id: "activeTabPill", in: tabAnimationNamespace)
                            }
                            
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                        }
                        
                        Text(tab.label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle()) // Área completa interactiva para pulsación cómoda
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .background(
            themeManager.backgroundColor.opacity(0.85)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}
