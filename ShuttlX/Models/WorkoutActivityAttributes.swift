import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    let workoutStartDate: Date
    let activityType: String

    struct ContentState: Codable, Hashable {
        /// Anchor for `Text(timerInterval:)` rendering. Set when a workout starts
        /// and kept stable across updates so the widget's timer ticks locally
        /// even if update frequency varies.
        var startDate: Date
        var elapsedTime: TimeInterval
        var heartRate: Int
        var distance: Double
        var calories: Int
        var currentActivity: String
        var isPaused: Bool
        var pace: TimeInterval
    }
}
