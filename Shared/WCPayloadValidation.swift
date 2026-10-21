import Foundation

/// Sanity checks for what arrives over WatchConnectivity (a paired watch, but also an old or damaged build).
/// Limits are generous on purpose: a real workout must never be rejected, only absurd or non-finite values.
public enum WCPayloadValidation {
    /// Largest encoded session accepted (a 6000-point route is well under 2 MB).
    public static let maxSessionBytes = 8_000_000

    public static func finite(_ v: Double, in range: ClosedRange<Double>) -> Bool {
        v.isFinite && range.contains(v)
    }

    /// nil when the value is missing, NaN/infinite or outside `range`.
    public static func checked(_ v: Any?, in range: ClosedRange<Double>) -> Double? {
        let d: Double?
        switch v {
        case let x as Double: d = x
        case let x as Int: d = Double(x)
        default: d = nil
        }
        guard let d, finite(d, in: range) else { return nil }
        return d
    }

    // MARK: Sessions

    public static func isSaneSession(startDate: Date, duration: TimeInterval, distanceKm: Double?, calories: Double?,
                                     averageHR: Double?, maxHR: Double?, segmentCount: Int, routeCount: Int,
                                     now: Date = Date()) -> Bool {
        guard startDate.timeIntervalSince1970 > 946_684_800,            // after 2000-01-01
              startDate < now.addingTimeInterval(86_400),
              finite(duration, in: 0...(72 * 3600)),
              segmentCount <= 2_000, routeCount <= 200_000 else { return false }
        if let d = distanceKm, !finite(d, in: 0...5_000) { return false }
        if let c = calories, !finite(c, in: 0...100_000) { return false }
        if let h = averageHR, !finite(h, in: 0...300) { return false }
        if let h = maxHR, !finite(h, in: 0...300) { return false }
        return true
    }

    // MARK: Effort and alerts

    public static func isValidEffort(sessionId: String, rpe: Int) -> Bool {
        UUID(uuidString: sessionId) != nil && (0...10).contains(rpe)
    }

    /// Alert value (bpm); anything outside 0...300 is dropped, the alert itself still shows.
    public static func alertValue(_ v: Any?) -> Int? {
        checked(v, in: 0...300).map { Int($0) }
    }

    // MARK: Live metrics

    public struct LiveMetrics: Equatable {
        public var elapsedTime: TimeInterval
        public var heartRate: Int
        public var distance: Double
        public var calories: Int
        public var steps: Int
        public var pace: TimeInterval
        public var currentActivity: String
        public var workoutName: String
        public var isPaused: Bool
        public var latitude: Double?
        public var longitude: Double?
    }

    private static let allowedActivities: Set<String> = ["running", "walking", "cycling", "stationary", "unknown"]

    /// nil when the elapsed time is missing or absurd (the snapshot is ignored). Other bad numbers become 0.
    public static func liveMetrics(_ m: [String: Any]) -> LiveMetrics? {
        guard let elapsed = checked(m["elapsedTime"], in: 0...(72 * 3600)) else { return nil }
        let activity = (m["currentActivity"] as? String).flatMap { allowedActivities.contains($0) ? $0 : nil } ?? "unknown"
        let name = String(((m["workoutName"] as? String) ?? activity).prefix(60))
        var lat = checked(m["latitude"], in: -90...90)
        var lon = checked(m["longitude"], in: -180...180)
        if lat == nil || lon == nil { lat = nil; lon = nil }
        return LiveMetrics(
            elapsedTime: elapsed,
            heartRate: checked(m["heartRate"], in: 0...300).map { Int($0) } ?? 0,
            distance: checked(m["distance"], in: 0...5_000) ?? 0,
            calories: checked(m["calories"], in: 0...100_000).map { Int($0) } ?? 0,
            steps: checked(m["steps"], in: 0...1_000_000).map { Int($0) } ?? 0,
            pace: checked(m["pace"], in: 0...7_200) ?? 0,
            currentActivity: activity,
            workoutName: name,
            isPaused: m["isPaused"] as? Bool ?? false,
            latitude: lat, longitude: lon)
    }
}
