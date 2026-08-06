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
                // SHUTTLX_SNAPSHOT_HR overrides the seeded heart rate (the seed of
                // 138 is above 70% of the 190 fallback max, so it always shows the
                // "Ease off" banner — pass e.g. 118 to capture the banner-free
                // layout). SHUTTLX_SNAPSHOT_PACE overrides pace in sec/km, or
                // "none" for the nil case that renders "—".
                // SHUTTLX_SNAPSHOT_PAUSED=1 freezes the seeded workout the way
                // pauseWorkout() does (isPaused + nil timerReferenceDate) so the
                // paused presentation can be captured — it is the only state
                // signal on the free-run screen now that the FREE RUN header,
                // which used to blink amber, is interval-only.
                let env = ProcessInfo.processInfo.environment
                let freeRunElapsed = env["SHUTTLX_SNAPSHOT_ELAPSED"].flatMap(Double.init)
                let hrOverride = env["SHUTTLX_SNAPSHOT_HR"].flatMap(Int.init)
                let paceOverride = env["SHUTTLX_SNAPSHOT_PACE"]
                let pausedOverride = env["SHUTTLX_SNAPSHOT_PAUSED"] == "1"
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
                        if let hrOverride { workoutManager.heartRate = hrOverride }
                        if let paceOverride {
                            workoutManager.currentPace = paceOverride == "none"
                                ? nil
                                : Double(paceOverride)
                        }
                        if pausedOverride { workoutManager.applyPausedPreviewState() }
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