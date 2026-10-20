import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    let workoutStartDate: Date
    let activityType: String

    struct Part: Codable, Hashable {
        var activity: String   // "running" / "walking" / other
        var seconds: Int
    }

    struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var heartRate: Int
        var distance: Double
        var calories: Int
        var currentActivity: String
        var isPaused: Bool
        var pace: TimeInterval
        /// Why it is paused, e.g. "noMotion" (watch auto-pause). nil = user pause / running.
        var pauseReason: String? = nil
        /// EASY / STEADY / HARD from `HeartSafetySettings`; nil when no limit or no HR.
        var zoneWord: String? = nil
        /// Ribbon of parts so far (run-length, merged, capped at 24 so the payload stays ~1 KB).
        var parts: [Part]? = nil

        /// Start-date-adjusted-for-pauses reference for a system-rendered
        /// ticking timer (`Text(timerInterval:countsDown:)`). Computed each
        /// update as `now - elapsedTime`, so it self-corrects on every
        /// broadcast from the Watch (roughly every 3s) rather than drifting
        /// between updates like the old pre-formatted `elapsedTime` string
        /// did. Only meaningful while `!isPaused` — render views must fall
        /// back to a static formatted string while paused, since the Watch
        /// stops broadcasting and this reference would otherwise go stale.
        var timerReferenceDate: Date
    }
}
