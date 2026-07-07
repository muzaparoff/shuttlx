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
        WindowGroup {
            #if DEBUG
            if let snapshot = ProcessInfo.processInfo.environment["SHUTTLX_SNAPSHOT"] {
                TrainingView()
                    .environment(ThemeManager.shared)
                    .environmentObject(sharedDataManager)
                    .environmentObject(workoutManager)
                    .task {
                        ThemeManager.shared.selectTheme(snapshot)
                        workoutManager.applyPreviewSnapshot()
                    }
            } else {
                appRoot
            }
            #else
            appRoot
            #endif
        }
    }

    @ViewBuilder
    private var appRoot: some View {
            ContentView()
                .environment(ThemeManager.shared)
                .environmentObject(sharedDataManager)
                .environmentObject(workoutManager)
                .onOpenURL { url in
                    guard url.scheme == "shuttlx" else { return }
                    switch url.host {
                    case "start-workout":
                        logger.info("Deep link received — starting free-form workout")
                        if !workoutManager.isWorkoutActive {
                            workoutManager.startWorkout()
                        }
                    default:
                        logger.info("Deep link received — opening home")
                    }
                }
                .onAppear {
                    logger.info("ContentView appeared")
                    // Request HealthKit permissions early (must be after window exists)
                    workoutManager.requestHealthKitPermissionsIfNeeded()
                    // Crash recovery: deferred off first render to avoid blocking the UI
                    Task {
                        // Finalize any HKWorkoutSession orphaned by a crash/kill so
                        // the workout still reaches HealthKit.
                        workoutManager.recoverOrphanedHKSession()
                        if !workoutManager.isWorkoutActive, let recovered = workoutManager.recoverCrashedWorkout() {
                            logger.info("Recovering crashed workout session")
                            workoutManager.saveRecoveredSession(recovered)
                        }
                    }
                }
    }
}