import Foundation

/// Platform-agnostic haptic effects. The shared `IntervalEngine` fires these
/// on step transitions / countdown beats / completion. Each app target plugs
/// in a concrete impl:
///
///   - watchOS — `WatchHapticPlayer` mapping to `WKInterfaceDevice.current().play(...)`
///   - iOS     — `iPhoneHapticPlayer` mapping to `UIImpactFeedbackGenerator` /
///                `UINotificationFeedbackGenerator`
///
/// Tests use `nil` (no player) to keep the engine fully exercise-able in a
/// Foundation-only SPM test target with no UIKit/WatchKit linkage.
public protocol HapticPlayer: Sendable {
    func play(_ kind: HapticKind)
}

public enum HapticKind: Sendable {
    /// A short tick — fired on the +5s countdown beat before each interval transition.
    case countdownTick
    /// Strong start cue — fired when entering a `.work` interval step.
    case workStart
    /// Soft cue — fired when entering a `.rest` step.
    case restStart
    /// Subtle click — used for warmup/cooldown transitions.
    case stepTransition
    /// Success — fired when the workout completes successfully.
    case complete
}
