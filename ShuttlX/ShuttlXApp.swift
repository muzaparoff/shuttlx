import SwiftUI

@main
struct ShuttlXApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Initialize CloudKit and load data
        dataManager.loadFromCloudKit()
        
        // Create sample data if no programs exist (for testing)
        #if DEBUG
        if dataManager.programs.isEmpty {
            dataManager.createSampleData()
        }
        #endif
    }
}
