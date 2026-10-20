import Foundation

/// Pure threshold logic for the long-workout "Still training?" safety prompt.
///
/// Driven by ACTIVE (pause-excluded) elapsed time only: the prompt never fires
/// while paused, and the no-answer timeout freezes while paused too, so a
/// paused workout can never be auto-ended underneath the wearer.
///
/// First prompt at 3h50m; Continue re-arms it 60 min after the answer; no
/// answer within 5 active minutes => `.autoEnd`.
public struct SafetyPromptSchedule: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case showPrompt
        case autoEnd
    }

    public static let defaultFirstPromptAt: TimeInterval = 3 * 3600 + 50 * 60

    public let repeatInterval: TimeInterval
    public let responseTimeout: TimeInterval
    public private(set) var nextPromptAt: TimeInterval
    /// Active elapsed time at which the visible prompt appeared; nil when hidden.
    public private(set) var promptShownAt: TimeInterval?

    public var isPromptShowing: Bool { promptShownAt != nil }

    public init(firstPromptAt: TimeInterval = SafetyPromptSchedule.defaultFirstPromptAt,
                repeatInterval: TimeInterval = 3600,
                responseTimeout: TimeInterval = 300) {
        self.nextPromptAt = firstPromptAt
        self.repeatInterval = repeatInterval
        self.responseTimeout = responseTimeout
    }

    /// Call once per tick with the current active elapsed time.
    public mutating func evaluate(activeElapsed: TimeInterval) -> Action {
        if let shownAt = promptShownAt {
            return activeElapsed - shownAt >= responseTimeout ? .autoEnd : .none
        }
        guard activeElapsed >= nextPromptAt else { return .none }
        promptShownAt = activeElapsed
        return .showPrompt
    }

    /// The wearer tapped Continue: hide the prompt and re-arm it one hour later.
    public mutating func acknowledge(activeElapsed: TimeInterval) {
        promptShownAt = nil
        nextPromptAt = activeElapsed + repeatInterval
    }
}
