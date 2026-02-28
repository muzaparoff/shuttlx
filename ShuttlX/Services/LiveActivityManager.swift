import ActivityKit
import Foundation
import os.log

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "LiveActivity")

    private init() {}

    func startActivity(activityType: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled by user")
            return
        }

        guard currentActivity == nil else { return }

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

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(15))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            logger.info("Live Activity started: \(self.currentActivity?.id ?? "nil")")
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
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
        guard let activity = currentActivity else {
            startActivity(activityType: activityType)
            return
        }

        let state = WorkoutActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
            currentActivity: activityType,
            isPaused: isPaused,
            pace: pace
        )

        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15))

        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
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
