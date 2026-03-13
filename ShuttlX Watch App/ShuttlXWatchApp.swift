import SwiftUI
import WidgetKit
import os.log

@main
struct ShuttlXWatchApp: App {
    @StateObject private var sharedDataManager: SharedDataManager
    @StateObject private var workoutManager: WatchWorkoutManager
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "AppInitialization")
    
    init() {
        logger.info("ShuttlXWatchApp initialization starting")

        let dataManager = SharedDataManager.shared
        let manager = WatchWorkoutManager()
        manager.setSharedDataManager(dataManager)

        self._sharedDataManager = StateObject(wrappedValue: dataManager)
        self._workoutManager = StateObject(wrappedValue: manager)

        logger.info("ShuttlXWatchApp initialization completed")
    }
    
    var body: some Scene {
        logger.info("Building WindowGroup scene")
        return WindowGroup {
            ContentView()
                .environment(ThemeManager.shared)
                .environmentObject(sharedDataManager)
                .environmentObject(workoutManager)
                .onOpenURL { url in
                    if url.scheme == "shuttlx" && url.host == "start-workout" {
                        logger.info("Deep link received — starting free-form workout")
                        if !workoutManager.isWorkoutActive {
                            workoutManager.startWorkout()
                        }
                    }
                }
                .onAppear {
                    logger.info("ContentView appeared")
                    // Request HealthKit permissions early (must be after window exists)
                    workoutManager.requestHealthKitPermissionsIfNeeded()
                    // Crash recovery: check for unsaved workout backup
                    if !workoutManager.isWorkoutActive, let recovered = workoutManager.recoverCrashedWorkout() {
                        logger.info("Recovering crashed workout session")
                        workoutManager.saveRecoveredSession(recovered)
                    }
                }
        }
    }
}