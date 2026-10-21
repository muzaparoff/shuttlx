import SwiftUI
import WatchKit
import WidgetKit
import os.log
import ShuttlXShared

/// watchOS relaunches the app after a crash mid-workout and calls
/// `handleActiveWorkoutRecovery()` — possibly in the background, before any view
/// appears (so the onAppear recovery trigger alone could fire much later).
/// `beginLaunchRecovery()` is idempotent; whichever caller is first wins.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    /// Set by `ShuttlXWatchApp.init`, which runs before any delegate callback.
    @MainActor static weak var workoutManager: WatchWorkoutManager?

    func handleActiveWorkoutRecovery() {
        Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "AppInitialization")
            .warning("handleActiveWorkoutRecovery — recovering live HKWorkoutSession")
        Self.workoutManager?.beginLaunchRecovery()
    }
}

@main
struct ShuttlXWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var sharedDataManager: WatchSyncCoordinator
    @StateObject private var workoutManager: WatchWorkoutManager
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "AppInitialization")
    
    init() {
        logger.info("ShuttlXWatchApp initialization starting")

        let dataManager = WatchSyncCoordinator.shared
        let manager = WatchWorkoutManager()
        manager.setSharedDataManager(dataManager)
        dataManager.setWorkoutManager(manager)
        WatchAppDelegate.workoutManager = manager

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
                // 138 is STEADY against the 190 fallback max; with no synced limit
                // the "Ease off" banner needs HARD, i.e. >= 90% — pass e.g. 175). SHUTTLX_SNAPSHOT_PACE overrides pace in sec/km, or
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
                // SHUTTLX_SNAPSHOT_SCREEN=home|summary|effort renders those screens
                // instead of the workout. SHUTTLX_SNAPSHOT_OVERLAY=toast|unusual|autopaused|nohr
                // raises a workout overlay, SHUTTLX_SNAPSHOT_LIMIT=<bpm> fakes a synced
                // heart limit (heart-limit mode), SHUTTLX_SNAPSHOT_TAB=<n> opens a page,
                // SHUTTLX_SNAPSHOT_ACTIVITY=running|walking|cycling sets the tag,
                // SHUTTLX_SNAPSHOT_HEALTHFAIL=1 shows the summary's "Not saved to Health".
                let screen = env["SHUTTLX_SNAPSHOT_SCREEN"]
                if screen == "home" {
                    NavigationStack { StartTrainingView() }
                        .environment(ThemeManager.shared)
                        .environmentObject(sharedDataManager)
                        .environmentObject(workoutManager)
                } else if screen == "summary" || screen == "effort" {
                    Group {
                        if let summary = workoutManager.pendingSummary {
                            WorkoutSummaryView(summary: summary, startOnEffort: screen == "effort") {}
                        } else {
                            Color.black
                        }
                    }
                    .environment(ThemeManager.shared)
                    .environmentObject(sharedDataManager)
                    .environmentObject(workoutManager)
                    .task { workoutManager.applySummaryPreview(healthSaveFailed: env["SHUTTLX_SNAPSHOT_HEALTHFAIL"] == "1") }
                } else {
                TrainingView()
                    .environment(ThemeManager.shared)
                    .environment(\.isLuminanceReduced, env["SHUTTLX_SNAPSHOT_AOD"] == "1")
                    .environmentObject(sharedDataManager)
                    .environmentObject(workoutManager)
                    .task {
                        ThemeManager.shared.selectTheme(snapshot)
                        if let limit = env["SHUTTLX_SNAPSHOT_LIMIT"].flatMap(Int.init) {
                            sharedDataManager.applyPreviewHeartSafety(HeartSafetySettings(upperLimit: limit))
                        }
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
                        if let a = env["SHUTTLX_SNAPSHOT_ACTIVITY"].flatMap(DetectedActivity.init(rawValue:)) {
                            workoutManager.currentActivity = a
                        }
                        if let overlay = env["SHUTTLX_SNAPSHOT_OVERLAY"] {
                            workoutManager.applyPreviewOverlay(overlay)
                        }
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