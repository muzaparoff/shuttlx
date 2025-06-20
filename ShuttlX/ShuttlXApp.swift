import SwiftUI

// Simple data management for the app
class SimpleDataManager: ObservableObject {
    @Published var programs: [String] = ["Sample Program 1", "Sample Program 2"]
}

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = SimpleDataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
