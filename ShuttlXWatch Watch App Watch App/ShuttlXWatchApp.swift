import SwiftUI
import os.log

@main
struct ShuttlXWatchApp: App {
    @StateObject private var sharedDataManager: SharedDataManager
    @StateObject private var workoutManager: WatchWorkoutManager
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "AppInitialization")
    
    init() {
        logger.info("🚀 ShuttlXWatchApp initialization starting...")
        
        logger.info("📱 Creating SharedDataManager...")
        let dataManager = SharedDataManager()
        logger.info("✅ SharedDataManager created successfully")
        
        logger.info("⌚ Creating WatchWorkoutManager...")
        let manager = WatchWorkoutManager()
        logger.info("✅ WatchWorkoutManager created successfully")
        
        logger.info("🔗 Setting up dependency injection...")
        manager.setSharedDataManager(dataManager)
        logger.info("✅ Dependency injection completed")
        
        logger.info("🎯 Setting up StateObjects...")
        self._sharedDataManager = StateObject(wrappedValue: dataManager)
        self._workoutManager = StateObject(wrappedValue: manager)
        logger.info("✅ StateObjects initialized successfully")
        
        logger.info("🎉 ShuttlXWatchApp initialization completed successfully!")
    }
    
    var body: some Scene {
        logger.info("🏗️ Building WindowGroup scene...")
        return WindowGroup {
            ContentView()
                .environmentObject(sharedDataManager)
                .environmentObject(workoutManager)
                .onAppear {
                    logger.info("📺 ContentView appeared - app launched successfully!")
                }
        }
    }
}