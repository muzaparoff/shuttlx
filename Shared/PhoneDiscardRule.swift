import Foundation

/// What the watch does with a phone `discardWorkout` message. Pure.
/// Discard applies ONLY to the workout the phone itself started (same
/// `phoneSessionId`), so a phone Discard can never drop a watch-started workout.
public enum PhoneDiscardRule {
    public enum Decision: Equatable, Sendable {
        case apply
        /// The matching workout is still starting; apply when the start finishes.
        case hold
        case ignore(reason: String)
    }

    /// A copy older than this is a late transferUserInfo delivery.
    public static let maxAge: TimeInterval = 120

    public static func decide(phoneSessionId: String?, sentAt: Date?, now: Date,
                              runningPhoneSessionId: String?,
                              isStarting: Bool, isActive: Bool) -> Decision {
        guard let phoneSessionId else { return .ignore(reason: "no phoneSessionId") }
        if let sentAt, now.timeIntervalSince(sentAt) > maxAge { return .ignore(reason: "stale") }
        guard phoneSessionId == runningPhoneSessionId else { return .ignore(reason: "not the running workout") }
        if isStarting { return .hold }
        return isActive ? .apply : .ignore(reason: "no workout running")
    }
}
