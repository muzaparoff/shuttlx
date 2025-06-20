import SwiftUI

@main
struct ShuttlXWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .onAppear {
                    setupWatchApp()
                }
        }
    }
    
    private func setupWatchApp() {
        // Initialize workout manager and load programs
        workoutManager.loadPrograms()
        
        // Request necessary permissions
        workoutManager.requestPermissions()
    }
}
