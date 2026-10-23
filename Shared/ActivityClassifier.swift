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
    /// With no cadence there is no step evidence either way, so only a speed no one
    /// sustains on foot counts as cycling: 6.5 m/s = 23.4 km/h.
    public static let unknownCadenceCyclingSpeed: Double = 6.5
    /// A CoreMotion reading older than this no longer says what the wearer is doing.
    public static let motionFreshness: TimeInterval = 60

    /// - Parameters: sustained `speed` (m/s) and `cadence` (steps/min, nil if unknown)
    ///   averaged over `window` seconds. Returns nil while the window is too short.
    public static func classify(speed: Double, cadence: Double?, window: TimeInterval = minWindow) -> Result? {
        guard window >= minWindow, speed.isFinite, speed >= 0 else { return nil }
        if speed < 0.3 { return Result(activity: .stationary, confidence: .high) }
        if speed > 7 { return Result(activity: .cycling, confidence: .high) }
        if let cadence {
            if speed > 3.5, cadence < 60 { return Result(activity: .cycling, confidence: .high) }
        } else if speed >= unknownCadenceCyclingSpeed {
            return Result(activity: .cycling, confidence: .high)
        }
        let run = (cadence ?? 0) >= 140 || speed >= 2.2
        let ambiguous = speed >= 6.0 / 3.6 && speed <= 9.0 / 3.6   // 6-9 km/h
        return Result(activity: run ? .running : .walking, confidence: ambiguous ? .low : .high)
    }

    /// For after-the-fact segments (Fix a part). Same answer as `classify`, but with no cadence a
    /// speed in 3.5...6.5 m/s could be a fast run or a bike, so the guess is `.low`.
    /// The watch keeps using `classify`.
    public static func classifyForReview(speed: Double, cadence: Double?, window: TimeInterval) -> Result? {
        guard let r = classify(speed: speed, cadence: cadence, window: window) else { return nil }
        if cadence == nil, speed >= 3.5, speed < unknownCadenceCyclingSpeed, r.confidence == .high {
            return Result(activity: r.activity, confidence: .low)
        }
        return r
    }

    /// Longest gap between fixes (or from the newest fix to now) for the window to
    /// count as covered. Walking with the 10 m distance filter gives a fix every ~7 s.
    public static let maxFixGap: TimeInterval = 15

    /// Mean GPS speed of the fixes in the last `window` seconds of `points` (oldest
    /// first). Walks backwards and stops at the first fix past the window edge, so
    /// the per-tick call allocates nothing. nil unless the fixes COVER the window:
    /// history reaches past it and no gap exceeds `maxFixGap` (a fresh resume or a
    /// GPS dropout must not classify on the 2-3 fixes since). Coverage, not a fix
    /// count: at walking pace there are only ~4 fixes in 30 s.
    public static func averageSpeed(of points: [RoutePoint], now: Date,
                                    window: TimeInterval = minWindow,
                                    minFixes: Int = 2) -> (speed: Double, fixes: Int)? {
        var sum = 0.0, fixes = 0, spansWindow = false, newer = now
        for point in points.reversed() {
            guard newer.timeIntervalSince(point.timestamp) <= maxFixGap else { return nil }
            if now.timeIntervalSince(point.timestamp) > window { spansWindow = true; break }
            newer = point.timestamp
            if let speed = point.speed { sum += speed; fixes += 1 }
        }
        guard spansWindow, fixes >= minFixes else { return nil }
        return (sum / Double(fixes), fixes)
    }

    /// Speed has just handed the segment back from cycling to on foot. Returns the
    /// run/walk to commit straight away from `speedVerdict` when CoreMotion has no
    /// fresh reading (it calls back only on a change, so it may never speak again),
    /// or nil when its fresh reading should re-earn run/walk instead.
    public static func footFallback(speedVerdict: DetectedActivity, motionReadingAt: Date?,
                                    now: Date) -> DetectedActivity? {
        if let at = motionReadingAt, now.timeIntervalSince(at) <= motionFreshness { return nil }
        return speedVerdict == .running ? .running : .walking
    }

    /// Cycling by speed, but `averageSpeed` returns nil: a slow walk with the 10 m
    /// distance filter gives a fix only every 15+ s, so the window is never covered and
    /// the segment would stay CYCLE. Returns the on-foot class to feed the hysteresis
    /// instead: a fresh CoreMotion walking/running reading, else step cadence of at
    /// least 60 spm (the same line `classify` uses). A stop (red light) or a GPS
    /// dropout while riding has neither, so it returns nil and cycling stays.
    public static func gapVerdict(motion: DetectedActivity?, motionReadingAt: Date?,
                                  cadence: Double?, now: Date) -> DetectedActivity? {
        if let motion, motion == .walking || motion == .running,
           let at = motionReadingAt, now.timeIntervalSince(at) <= motionFreshness { return motion }
        guard let cadence, cadence >= 60 else { return nil }
        return cadence >= 140 ? .running : .walking
    }

    /// A new class must hold 30 s before it replaces the committed one; 60 s when the
    /// switch crosses cycling <-> on-foot. The first on-foot reading commits
    /// immediately; a first cycling reading never does — it must hold 60 s like any
    /// other switch into cycling.
    public struct Hysteresis: Sendable {
        public private(set) var committed: DetectedActivity?
        private var pending: DetectedActivity?
        private var pendingSince: Date?

        public init() {}

        @discardableResult
        public mutating func ingest(_ activity: DetectedActivity, at now: Date) -> DetectedActivity? {
            guard let current = committed else {
                guard activity == .cycling else { committed = activity; pending = nil; pendingSince = nil; return activity }
                if pending != .cycling { pending = .cycling; pendingSince = now }
                if let since = pendingSince, now.timeIntervalSince(since) >= 60 {
                    committed = .cycling; pending = nil; pendingSince = nil
                }
                return committed
            }
            guard activity != current else { pending = nil; pendingSince = nil; return current }
            if pending != activity { pending = activity; pendingSince = now }
            let hold: TimeInterval = (activity == .cycling) != (current == .cycling) ? 60 : 30
            if let since = pendingSince, now.timeIntervalSince(since) >= hold {
                committed = activity; pending = nil; pendingSince = nil
            }
            return committed
        }
    }
}
