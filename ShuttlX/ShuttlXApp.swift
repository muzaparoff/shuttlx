import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
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
        }
    }
}
