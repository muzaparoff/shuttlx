import Foundation

/// Pure rules for the phone <-> watch workout handshake (so `swift test` covers them).
///
/// The phone starts a workout and asks the watch to record it too (`phoneSessionId` in the start message).
/// The watch answers `workoutStarted` (+ its own `sessionId`) or `workoutStartIgnored` (it was already
/// recording something else). Only after `workoutStarted` is the watch "linked": pause / resume / stop /
/// discard may then reach it. A stop from an earlier watch workout must not end a newer phone workout.
public enum WatchLinkRules {
    public enum StartReply: Equatable, Sendable {
        case started(watchSessionId: String?)
        case ignored
    }

    /// How long the phone waits for the watch's answer before treating it as not linked.
    public static let replyTimeout: TimeInterval = 5

    /// The watch's answer to our start, or nil when the payload is something else (or answers another id).
    public static func startReply(_ payload: [String: Any], expecting phoneSessionId: String) -> StartReply? {
        guard let id = payload["phoneSessionId"] as? String, id == phoneSessionId,
              let action = payload["action"] as? String else { return nil }
        switch action {
        case "workoutStarted": return .started(watchSessionId: payload["sessionId"] as? String)
        case "workoutStartIgnored": return .ignored
        default: return nil
        }
    }

    /// One phone start waiting for the watch's answer. The answer can arrive twice (sendMessage and
    /// transferUserInfo) and late (the watch answers only after HealthKit authorization, which can outlast
    /// `replyTimeout`). A late "started" still links; a duplicate does nothing.
    public struct StartHandshake: Equatable, Sendable {
        public let phoneSessionId: String
        public private(set) var timedOut = false
        public private(set) var finished = false
        public init(phoneSessionId: String) { self.phoneSessionId = phoneSessionId }

        /// True the first time: the caller reports "not linked (yet)". Later answers may still arrive.
        public mutating func timeout() -> Bool {
            guard !finished, !timedOut else { return false }
            timedOut = true
            return true
        }

        /// The answer for this start, or nil when the payload is not for it or already handled.
        public mutating func receive(_ payload: [String: Any]) -> StartReply? {
            guard !finished, let reply = WatchLinkRules.startReply(payload, expecting: phoneSessionId) else { return nil }
            finished = true
            return reply
        }
    }

    /// True when a `workoutStopped` must be ignored because it belongs to an older workout.
    /// - both ids known and different: stale;
    /// - otherwise: stale when it was sent before the current workout started (`sentAt` / `timestamp`).
    public static func isStaleStop(stopSessionId: String?, currentWatchSessionId: String?,
                                   sentAt: TimeInterval?, workoutStart: Date?) -> Bool {
        if let stopSessionId, let currentWatchSessionId, stopSessionId != currentWatchSessionId { return true }
        if let sentAt, let workoutStart, sentAt < workoutStart.timeIntervalSince1970 { return true }
        return false
    }
}
