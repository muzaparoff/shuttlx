import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    var body: some Scene {
        WindowGroup {
            if isFirstLaunch {
                OnboardingView(isFirstLaunch: $isFirstLaunch)
                    .environmentObject(dataManager)
                    .environmentObject(sharedDataManager)
            } else {
                ContentView()
                    .environmentObject(dataManager)
                    .environmentObject(sharedDataManager)
            }
        }
    }
}
