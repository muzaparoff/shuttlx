import Foundation

/// Watch free-run heart-limit page (audit W3, pick 3A). On at `enter` (90 %) of the limit, off only
/// below `exit` (85 %), so a heart rate sitting on the edge does not swap the page on every sample.
public enum HeartLimitMode {
    public static let enter = 0.90
    public static let exit = 0.85

    /// `wasOn`: the page showed heart-limit mode before this sample.
    public static func isOn(hr: Int, limit: Int?, wasOn: Bool) -> Bool {
        guard let limit, limit > 0, hr > 0 else { return false }
        return Double(hr) / Double(limit) >= (wasOn ? exit : enter)
    }
}

/// 3-2-1 lead-in before an interval step changes: one click as the countdown reaches 3, 2 and 1 s.
public enum StepCountdownCue {
    /// True when the countdown went from `previous` to `remaining` across 3, 2 or 1 s. Several beats
    /// skipped by a late tick give one click, not a burst.
    public static func shouldClick(previous: TimeInterval, remaining: TimeInterval) -> Bool {
        let beat = remaining.rounded(.up)
        return beat >= 1 && beat <= 3 && previous > beat
    }
}
