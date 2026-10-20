import Foundation

/// Pure rules for importing Apple Health workouts as sessions (no HealthKit types,
/// so they are unit-testable with `swift test`).
public enum HealthImportRules {
    /// Minimal identity of a session already in the app.
    public struct Known: Sendable {
        public let id: UUID
        public let start: Date
        public let duration: TimeInterval
        public init(id: UUID, start: Date, duration: TimeInterval) {
            self.id = id; self.start = start; self.duration = duration
        }
    }

    /// Same rules as SyncDebugView: external UUID == session id, else start within
    /// +-2 min and duration within 5%.
    public static func isAlreadyPresent(externalUUID: UUID?, workoutUUID: UUID,
                                        start: Date, duration: TimeInterval,
                                        known: [Known]) -> Bool {
        known.contains { s in
            if s.id == (externalUUID ?? workoutUUID) { return true }
            return abs(s.start.timeIntervalSince(start)) <= 120
                && abs(s.duration - duration) <= max(duration, 1) * 0.05
        }
    }

    /// Session id: the watch's external UUID when valid, else the HKWorkout uuid.
    public static func sessionID(externalUUIDString: String?, workoutUUID: UUID) -> UUID {
        externalUUIDString.flatMap(UUID.init(uuidString:)) ?? workoutUUID
    }

    /// Evenly thins `items` to at most `limit`, always keeping first and last.
    public static func downsample<T>(_ items: [T], limit: Int) -> [T] {
        guard limit > 1, items.count > limit else { return items }
        let step = Double(items.count - 1) / Double(limit - 1)
        return (0..<limit).map { items[Int((Double($0) * step).rounded())] }
    }

    /// Phase metadata written by the watch (`com.shuttlx.phase`) wins; otherwise the
    /// HK activity type decides (running/walking), anything else is `.unknown`.
    public static func activity(phaseMetadata: String?, sport: WorkoutSport) -> DetectedActivity {
        if let phaseMetadata, let a = DetectedActivity(rawValue: phaseMetadata) { return a }
        switch sport {
        case .running: return .running
        case .walking: return .walking
        default: return .unknown
        }
    }

    /// Workouts that ended very recently are left for WatchConnectivity (which carries
    /// richer data and never gets overwritten by an import).
    public static let gracePeriod: TimeInterval = 600
    public static func isPastGrace(end: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(end) >= gracePeriod
    }
}
