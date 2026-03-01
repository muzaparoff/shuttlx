import SwiftUI

@main
struct ShuttlXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
    @StateObject private var templateManager = TemplateManager()
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
            .environmentObject(dataManager)
            .environmentObject(sharedDataManager)
            .environmentObject(templateManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dataManager.loadSessionsFromAppGroup()
                sharedDataManager.reconcileWithDataManager()
            }
        }
    }
}
