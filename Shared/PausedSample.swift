import Foundation

/// Whether a heart-rate sample belongs to a pause, judged by the sample's own time and
/// not by when HealthKit delivered it (delivery lags seconds, sometimes minutes, so a
/// paused sample can arrive after the resume and an active one during the pause).
public enum PausedSample {
    /// - Parameters:
    ///   - closed: finished pause spans of this workout.
    ///   - openSince: start of the pause in progress, nil when running.
    public static func isPaused(_ date: Date, closed: [DateInterval], openSince: Date?) -> Bool {
        if let openSince, date >= openSince { return true }
        return closed.contains { $0.contains(date) }
    }
}
