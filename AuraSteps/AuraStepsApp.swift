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
            ZStack {
                AppBackgroundView()
                
                ZStack {
                    if pocketBaseManager.isLoggedIn {
                        DashboardView()
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .scaleEffect(selectedTab == 0 ? 1 : 0.98)
                            .offset(y: selectedTab == 0 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 0)
                        
                        GymDashboardView(onNavigateToRoutine: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                selectedTab = 2 // Mi Rutina
                            }
                        })
                        .opacity(selectedTab == 1 ? 1 : 0)
                        .scaleEffect(selectedTab == 1 ? 1 : 0.98)
                        .offset(y: selectedTab == 1 ? 0 : 6)
                        .allowsHitTesting(selectedTab == 1)
                        
                        GymRoutineView()
                            .opacity(selectedTab == 2 ? 1 : 0)
                            .scaleEffect(selectedTab == 2 ? 1 : 0.98)
                            .offset(y: selectedTab == 2 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 2)
                        
                        GymGalleryView()
                            .opacity(selectedTab == 3 ? 1 : 0)
                            .scaleEffect(selectedTab == 3 ? 1 : 0.98)
                            .offset(y: selectedTab == 3 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 3)
                        
                        SettingsView()
                            .opacity(selectedTab == 4 ? 1 : 0)
                            .scaleEffect(selectedTab == 4 ? 1 : 0.98)
                            .offset(y: selectedTab == 4 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 4)
                    } else {
                        DashboardView()
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .scaleEffect(selectedTab == 0 ? 1 : 0.98)
                            .offset(y: selectedTab == 0 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 0)
                        
                        SettingsView()
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .scaleEffect(selectedTab == 1 ? 1 : 0.98)
                            .offset(y: selectedTab == 1 ? 0 : 6)
                            .allowsHitTesting(selectedTab == 1)
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedTab)
                .safeAreaInset(edge: .bottom) {
                    CustomAnimatedTabBar(selectedTab: $selectedTab, isLoggedIn: pocketBaseManager.isLoggedIn)
                }
            }
            .onChange(of: pocketBaseManager.isLoggedIn) { loggedIn in
                if !loggedIn && selectedTab > 1 {
                    selectedTab = 0
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

// MARK: - Barra de Pestañas Animada con Material Traslúcido

@MainActor
struct CustomAnimatedTabBar: View {
    @Binding var selectedTab: Int
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
                let isSelected = selectedTab == tab.tag
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedTab = tab.tag
                    }
                }) {
                    VStack(spacing: 3) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(themeManager.accentColor.opacity(0.18))
                                    .frame(width: 44, height: 28)
                                    .matchedGeometryEffect(id: "activeTabPill", in: tabAnimationNamespace)
                            }
                            
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                        }
                        
                        Text(tab.label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
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
