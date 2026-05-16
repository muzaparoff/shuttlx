import UIKit
import ShuttlXShared

/// iOS implementation of `ShuttlXShared.HapticPlayer`. Maps each abstract
/// `HapticKind` to a UIKit haptic generator. Reuses prepared generators so
/// the first tap doesn't pay the engine-startup cost.
@MainActor
final class iPhoneHapticPlayer: HapticPlayer, @unchecked Sendable {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    nonisolated init() {}

    /// Prepare all generators ahead of an active workout so the first beat
    /// fires with minimal latency. Call once on workout start.
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }

    nonisolated func play(_ kind: HapticKind) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch kind {
            case .countdownTick:    self.lightImpact.impactOccurred()
            case .workStart:        self.heavyImpact.impactOccurred()
            case .restStart:        self.mediumImpact.impactOccurred()
            case .stepTransition:   self.lightImpact.impactOccurred()
            case .complete:         self.notification.notificationOccurred(.success)
            }
        }
    }
}
