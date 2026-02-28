import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    let workoutStartDate: Date
    let activityType: String

    struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var heartRate: Int
        var distance: Double
        var calories: Int
        var currentActivity: String
        var isPaused: Bool
        var pace: TimeInterval
    }
}
