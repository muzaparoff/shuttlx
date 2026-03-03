import SwiftUI

@main
struct ShuttlXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager.shared
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var planManager = PlanManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var cloudKitSync = CloudKitSyncManager.shared
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch)
                } else {
                    ContentView()
                }
            }
            .environment(themeManager)
            .environmentObject(dataManager)
            .environmentObject(sharedDataManager)
            .environmentObject(templateManager)
            .environmentObject(planManager)
            .environmentObject(authManager)
            .environmentObject(cloudKitSync)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dataManager.loadSessionsFromAppGroup()
                sharedDataManager.reconcileWithDataManager()
                if authManager.isSignedIn {
                    cloudKitSync.performFullSync(dataManager: dataManager)
                }
            }
        }
    }
}
