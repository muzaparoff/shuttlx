import Foundation

/// Speed/cadence classifier for a segment. Pure. Cycling vs on-foot is automatic;
/// run vs walk is only a suggestion (`confidence == .low` in the 6-9 km/h band).
/// Named `SpeedActivityClassifier` because the watch target already has its own
/// `ActivityClassifier` (CoreMotion confidence debouncer).
public enum SpeedActivityClassifier {
    public enum Confidence: String, Sendable { case low, high }

    public struct Result: Equatable, Sendable {
        public let activity: DetectedActivity
        public let confidence: Confidence
    }

    /// Minimum window the inputs must be averaged over.
    public static let minWindow: TimeInterval = 30

    /// - Parameters: sustained `speed` (m/s) and `cadence` (steps/min, nil if unknown)
    ///   averaged over `window` seconds. Returns nil while the window is too short.
    public static func classify(speed: Double, cadence: Double?, window: TimeInterval = minWindow) -> Result? {
        guard window >= minWindow, speed.isFinite, speed >= 0 else { return nil }
        if speed < 0.3 { return Result(activity: .stationary, confidence: .high) }
        if speed > 7 { return Result(activity: .cycling, confidence: .high) }
        if speed > 3.5, cadence.map({ $0 < 60 }) ?? true {
            return Result(activity: .cycling, confidence: .high)
        }
        let run = (cadence ?? 0) >= 140 || speed >= 2.2
        let ambiguous = speed >= 6.0 / 3.6 && speed <= 9.0 / 3.6   // 6-9 km/h
        return Result(activity: run ? .running : .walking, confidence: ambiguous ? .low : .high)
    }

    /// A new class must hold 30 s before it replaces the committed one; 60 s when the
    /// switch crosses cycling <-> on-foot. The first reading commits immediately.
    public struct Hysteresis: Sendable {
        public private(set) var committed: DetectedActivity?
        private var pending: DetectedActivity?
        private var pendingSince: Date?

        public init() {}

        @discardableResult
        public mutating func ingest(_ activity: DetectedActivity, at now: Date) -> DetectedActivity {
            guard let current = committed else { committed = activity; return activity }
            guard activity != current else { pending = nil; pendingSince = nil; return current }
            if pending != activity { pending = activity; pendingSince = now }
            let hold: TimeInterval = (activity == .cycling) != (current == .cycling) ? 60 : 30
            if let since = pendingSince, now.timeIntervalSince(since) >= hold {
                committed = activity; pending = nil; pendingSince = nil
            }
            return committed ?? activity
        }
    }
}
