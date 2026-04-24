import ActivityKit
import AppIntents
import Foundation
import os.log

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "LiveActivity")

    /// Tracks whether startActivity() previously failed, allowing retry on next call.
    private var startFailed = false

    /// Tracks whether we've already logged the auth-denied warning this session,
    /// to avoid flooding the log on every metric tick.
    private var loggedAuthDenied = false

    /// How long a content update remains "fresh" before iOS marks the activity stale.
    /// Set generously (10 min) to survive transient WatchConnectivity drops.
    private static let staleInterval: TimeInterval = 600

    /// Returns true if the user has enabled Live Activities in Settings.
    /// When false, silently-failed `.request(...)` calls are explained by this.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private init() {}

    /// Explicitly starts a Live Activity for the given workout type and start date.
    /// Using a concrete `workoutStartDate` lets the widget render a self-ticking
    /// `Text(timerInterval:)` that doesn't depend on per-second updates arriving.
    @discardableResult
    func startActivity(activityType: String, startDate: Date = Date()) -> Bool {
        guard areActivitiesEnabled else {
            if !loggedAuthDenied {
                logger.warning("Live Activities disabled in Settings → Notifications → \"ShuttlX\" — skipping start")
                loggedAuthDenied = true
            }
            return false
        }
        loggedAuthDenied = false

        // If an activity already exists and we haven't failed, skip.
        if currentActivity != nil && !startFailed {
            return true
        }

        let attributes = WorkoutActivityAttributes(
            workoutStartDate: startDate,
            activityType: activityType
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            startDate: startDate,
            elapsedTime: 0,
            heartRate: 0,
            distance: 0,
            calories: 0,
            currentActivity: activityType,
            isPaused: false,
            pace: 0
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(Self.staleInterval)
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            startFailed = false
            logger.info("Live Activity started: \(self.currentActivity?.id ?? "nil")")
            return true
        } catch {
            startFailed = true
            currentActivity = nil
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            return false
        }
    }

    func updateActivity(
        startDate: Date?,
        elapsedTime: TimeInterval,
        heartRate: Int,
        distance: Double,
        calories: Int,
        currentActivity activityType: String,
        isPaused: Bool,
        pace: TimeInterval
    ) {
        // If no current activity (or previous start failed), try to start one first.
        if currentActivity == nil || startFailed {
            let started = startActivity(activityType: activityType, startDate: startDate ?? Date())
            if !started { return }
        }

        guard let activity = currentActivity else { return }

        // Use the attributes' workoutStartDate if we don't have a fresher one —
        // it is the true anchor for the widget's timerInterval display.
        let anchorDate = startDate ?? activity.attributes.workoutStartDate

        let state = WorkoutActivityAttributes.ContentState(
            startDate: anchorDate,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
            currentActivity: activityType,
            isPaused: isPaused,
            pace: pace
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(Self.staleInterval)
        )

        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
        startFailed = false

        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            startDate: activity.attributes.workoutStartDate,
            elapsedTime: 0,
            heartRate: 0,
            distance: 0,
            calories: 0,
            currentActivity: "unknown",
            isPaused: false,
            pace: 0
        )

        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
            logger.info("Live Activity ended")
        }

        currentActivity = nil
    }

    func cleanupStaleActivities() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

// MARK: - Workout Focus Automation Hook
//
// iOS apps cannot directly activate a system Focus mode (e.g. Fitness Focus).
// Apple's Focus API only lets apps *respond* to an active Focus — it doesn't
// let third-party code set one. Apple's own Fitness app only turns Focus on
// because the user has configured "Fitness Focus → Auto-activate during
// workout" in Settings → Focus.
//
// The supported path for ShuttlX users is a Shortcut Automation:
//   1. Settings → Focus → Fitness → Add Automation
//   2. Choose "When Shortcut runs: ShuttlX Start Workout"
//   3. The intent below is what their automation listens for.
//
// The intent itself is a no-op — its job is to exist so Shortcuts can bind
// to it. When a workout begins on the Watch, `SharedDataManager` donates
// this intent so the automation fires.

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start ShuttlX Workout"
    static let description = IntentDescription(
        "Signals that a ShuttlX workout has begun. Use in a Shortcut automation to turn on Focus modes automatically."
    )
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        // Intentionally empty — the intent exists as a Shortcut automation hook.
        return .result()
    }
}

struct ShuttlXAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout with \(.applicationName)",
                "Begin \(.applicationName) workout"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.run"
        )
    }
}
