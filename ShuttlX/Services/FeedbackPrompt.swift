import Foundation
import StoreKit
import UIKit
import os.log

/// Guarded App Store rating prompt.
///
/// Call `recordHappyMoment()` whenever the user experiences a success moment
/// (a completed `TrainingSession` landing on the iPhone). The helper counts
/// moments and only surfaces the system review sheet via the modern
/// `AppStore.requestReview(in:)` API when ALL of the following hold:
///
/// - at least 3 happy moments have been recorded
/// - at least 14 days have passed since the first recorded moment
/// - no review ask happened in the last 90 days
/// - no review ask has happened for the current marketing version
///
/// The system itself may still throttle or suppress the sheet — the guards
/// here only bound how often we *ask* StoreKit.
enum FeedbackPrompt {

    private enum Keys {
        static let happyMomentCount = "com.shuttlx.feedback.happyMomentCount"
        static let firstHappyMomentDate = "com.shuttlx.feedback.firstHappyMomentDate"
        static let lastAskDate = "com.shuttlx.feedback.lastAskDate"
        static let lastAskVersion = "com.shuttlx.feedback.lastAskVersion"
    }

    private static let minHappyMoments = 3
    private static let minDaysSinceFirstMoment: TimeInterval = 14 * 24 * 60 * 60
    private static let minDaysBetweenAsks: TimeInterval = 90 * 24 * 60 * 60

    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "FeedbackPrompt")

    /// Records one happy moment and, if every guard passes, requests the
    /// system review sheet in the active foreground scene.
    @MainActor
    static func recordHappyMoment(now: Date = Date()) {
        let defaults = UserDefaults.standard

        let count = defaults.integer(forKey: Keys.happyMomentCount) + 1
        defaults.set(count, forKey: Keys.happyMomentCount)
        if defaults.object(forKey: Keys.firstHappyMomentDate) == nil {
            defaults.set(now, forKey: Keys.firstHappyMomentDate)
        }

        guard count >= minHappyMoments else { return }

        guard let firstMoment = defaults.object(forKey: Keys.firstHappyMomentDate) as? Date,
              now.timeIntervalSince(firstMoment) >= minDaysSinceFirstMoment else { return }

        if let lastAsk = defaults.object(forKey: Keys.lastAskDate) as? Date,
           now.timeIntervalSince(lastAsk) < minDaysBetweenAsks {
            return
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        guard defaults.string(forKey: Keys.lastAskVersion) != version else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        defaults.set(now, forKey: Keys.lastAskDate)
        defaults.set(version, forKey: Keys.lastAskVersion)
        logger.info("Requesting App Store review (happy moments: \(count), version: \(version))")
        AppStore.requestReview(in: scene)
    }
}
