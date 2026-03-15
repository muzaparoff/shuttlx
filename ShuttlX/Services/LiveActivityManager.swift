import ActivityKit
import Foundation
import os.log

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "LiveActivity")

    /// Tracks whether startActivity() previously failed, allowing retry on next call.
    private var startFailed = false

    private init() {}

    /// Explicitly starts a Live Activity for the given workout type.
    /// If `Activity.request()` throws, the error is logged and `startFailed` is set
    /// so that subsequent calls (e.g. from `updateActivity`) can retry.
    @discardableResult
    func startActivity(activityType: String) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled by user")
            return false
        }

        // If an activity already exists and we haven't failed, skip.
        if currentActivity != nil && !startFailed {
            return true
        }

        let attributes = WorkoutActivityAttributes(
            workoutStartDate: Date(),
            activityType: activityType
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            heartRate: 0,
            distance: 0,
            calories: 0,
            currentActivity: activityType,
            isPaused: false,
            pace: 0
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(60))

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
            let started = startActivity(activityType: activityType)
            if !started {
                // startFailed is already set; will retry on next metric update.
                logger.warning("updateActivity: no activity running, start failed — will retry next update")
                return
            }
        }

        guard let activity = currentActivity else { return }

        let state = WorkoutActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
            currentActivity: activityType,
            isPaused: isPaused,
            pace: pace
        )

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))

        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
        startFailed = false

        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
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
