import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    var body: some Scene {
        WindowGroup {
            if isFirstLaunch {
                // Temporarily use ContentView until OnboardingView is properly added to the project
                ContentView()
                    .environmentObject(dataManager)
                    .environmentObject(sharedDataManager)
                    .onAppear {
                        // Uncomment the following line once OnboardingView is added to project
                        // isFirstLaunch = false
                    }
            } else {
                ContentView()
                    .environmentObject(dataManager)
                    .environmentObject(sharedDataManager)
            }
        }
    }
}
