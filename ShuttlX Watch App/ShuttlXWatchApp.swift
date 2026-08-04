import SwiftUI
import WidgetKit
import os.log

@main
struct ShuttlXWatchApp: App {
    @StateObject private var sharedDataManager: WatchSyncCoordinator
    @StateObject private var workoutManager: WatchWorkoutManager
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "AppInitialization")
    
    init() {
        logger.info("ShuttlXWatchApp initialization starting")

        let dataManager = WatchSyncCoordinator.shared
        let manager = WatchWorkoutManager()
        manager.setSharedDataManager(dataManager)
        dataManager.setWorkoutManager(manager)

        self._sharedDataManager = StateObject(wrappedValue: dataManager)
        self._workoutManager = StateObject(wrappedValue: manager)

        logger.info("ShuttlXWatchApp initialization completed")
    }
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let snapshot = ProcessInfo.processInfo.environment["SHUTTLX_SNAPSHOT"] {
                // SHUTTLX_SNAPSHOT_ELAPSED (seconds) seeds a RUNNING free-run state
                // instead of the interval snapshot — used to capture the wall-clock
                // timer at 1h+ without waiting. SHUTTLX_SNAPSHOT_AOD=1 forces the
                // Always-On (reduced luminance) variant.
                let env = ProcessInfo.processInfo.environment
                let freeRunElapsed = env["SHUTTLX_SNAPSHOT_ELAPSED"].flatMap(Double.init)
                TrainingView()
                    .environment(ThemeManager.shared)
                    .environment(\.isLuminanceReduced, env["SHUTTLX_SNAPSHOT_AOD"] == "1")
                    .environmentObject(sharedDataManager)
                    .environmentObject(workoutManager)
                    .task {
                        ThemeManager.shared.selectTheme(snapshot)
                        if let freeRunElapsed {
                            workoutManager.applyFreeRunPreviewSnapshot(elapsed: freeRunElapsed)
                        } else {
                            workoutManager.applyPreviewSnapshot()
                        }
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
                        // onOpenURL can be delivered before onAppear on a cold launch.
                        // beginLaunchRecovery() is idempotent, and startWorkout() awaits
                        // the task it creates — calling it here guarantees the deep-link
                        // start is serialized behind orphan recovery either way.
                        workoutManager.beginLaunchRecovery()
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
                    // Crash recovery (orphaned HK session + crashed-workout backup)
                    // runs off first render. It is owned by the workout manager as a
                    // Task so that a workout started before it finishes — e.g. a
                    // complication deep link on a cold launch — awaits it instead of
                    // racing it (which left two live HK sessions and auto-stopped the
                    // new workout ~1 minute in).
                    workoutManager.beginLaunchRecovery()
                }
    }
}