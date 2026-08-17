import Foundation
import ShuttlXShared

/// Fused walk / run / stationary classifier for free-run (and gym-recovery)
/// sessions.
///
/// Deliberately a **pure value type**: no CoreMotion, HealthKit, timer or
/// logging dependency. `WatchWorkoutManager` owns all I/O — it maps
/// `CMMotionActivity` into `ingest(...)` and calls `evaluate(...)` once per
/// display tick — which keeps the decision logic reasonable in isolation and
/// exercisable off-device (the same reason `RecoverySegmenter` is a struct).
///
/// Phase 1 of `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md` (CE1):
/// before this type, classification read only the raw
/// `CMMotionActivity.running/.walking/.stationary` booleans — `confidence` was
/// ignored and cadence, already computed for display, never fed back in.
///
/// Decision model (three gates, all must pass to commit a transition):
/// 1. **Confidence gate** — `.low` readings are dropped on the floor. They do
///    not start the pending clock, do not extend it and do not cancel it.
/// 2. **Debounce gate** — the proposal must persist for `debounceInterval`
///    (5 s, unchanged from the original implementation).
/// 3. **Corroboration gate** — cadence must not actively contradict the
///    proposal. If it does (e.g. motion says "running" at 96 spm), the
///    transition only commits when *every* reading in the pending window was
///    `.high` confidence.
struct ActivityClassifier {

    // MARK: - Confidence

    /// Mirror of `CMMotionActivityConfidence` — kept CoreMotion-free so this
    /// file compiles (and can be traced) anywhere.
    enum Confidence: Int, Comparable, Sendable {
        case low = 0
        case medium = 1
        case high = 2

        static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            }
        }
    }

    // MARK: - Cadence corroboration

    /// Community-established run/walk discriminator is ~130–140 spm. We treat
    /// the band itself as a grey zone rather than picking a single knife-edge
    /// value: above `runCadenceFloor` running is corroborated, below
    /// `walkCadenceCeiling` walking is, and in between cadence abstains.
    static let runCadenceFloor: Int = 140
    static let walkCadenceCeiling: Int = 130
    /// Below this the wearer is not stepping at all.
    static let stationaryCadenceCeiling: Int = 20
    /// Above this, "stationary" is contradicted outright.
    static let stationaryCadenceContradiction: Int = 40

    enum CadenceCheck: String, Sendable {
        case agrees
        case contradicts
        /// No cadence sample yet (pedometer warmup is ~30 s) or the value sits
        /// in the 130–140 spm grey band. Neither confirms nor denies.
        case inconclusive
    }

    static func cadenceCheck(for activity: DetectedActivity, cadence: Int?) -> CadenceCheck {
        guard let cadence = cadence else { return .inconclusive }
        switch activity {
        case .running:
            if cadence >= runCadenceFloor { return .agrees }
            if cadence < walkCadenceCeiling { return .contradicts }
            return .inconclusive
        case .walking:
            if cadence > runCadenceFloor { return .contradicts }
            // A zero/near-zero reading is pedometer lag, not evidence against
            // walking — abstain rather than contradict.
            if cadence >= stationaryCadenceCeiling && cadence <= walkCadenceCeiling { return .agrees }
            return .inconclusive
        case .stationary:
            if cadence <= stationaryCadenceCeiling { return .agrees }
            if cadence > stationaryCadenceContradiction { return .contradicts }
            return .inconclusive
        case .unknown:
            return .inconclusive
        }
    }

    // MARK: - Outcomes

    /// What `ingest` did with a reading — logging fodder only.
    enum Ingest: Sendable, Equatable {
        case droppedLowConfidence(DetectedActivity)
        /// Motion reported none of running/walking/stationary (e.g. automotive,
        /// or nothing at all). Absence of a classification is not a
        /// classification — we hold the last committed activity.
        case droppedUnclassified
        case startedPending(DetectedActivity)
        case continuedPending(DetectedActivity)
        /// Reading matched the committed activity — any pending proposal is off.
        case confirmedCurrent(DetectedActivity)
    }

    struct Decision: Sendable {
        let activity: DetectedActivity
        let previous: DetectedActivity
        /// Weakest reading seen during the pending window (all `.low` readings
        /// were dropped before they got here).
        let minConfidence: Confidence
        let maxConfidence: Confidence
        let cadence: Int?
        let cadenceCheck: CadenceCheck
        let heldFor: TimeInterval
        /// True when this decision re-opens a segment for an unchanged activity
        /// (workout start / resume-from-pause), rather than a real transition.
        let isReconfirmation: Bool
    }

    struct Hold: Sendable {
        let activity: DetectedActivity
        let minConfidence: Confidence
        let cadence: Int?
        let heldFor: TimeInterval
    }

    enum Evaluation: Sendable {
        case idle
        /// Debounce satisfied but cadence contradicts and confidence is not
        /// uniformly `.high`. Surfaced once per pending window for logging.
        case holding(Hold)
        case commit(Decision)
    }

    // MARK: - State

    private struct Pending {
        var activity: DetectedActivity
        var since: Date
        var minConfidence: Confidence
        var maxConfidence: Confidence
        var holdReported: Bool = false
    }

    let debounceInterval: TimeInterval

    /// Last committed classification. Mirrors `WatchWorkoutManager.currentActivity`.
    private(set) var committed: DetectedActivity = .unknown
    /// When true the next confident reading commits **even if it equals**
    /// `committed`. Set at workout start and on resume-from-pause so a segment
    /// is opened from fresh evidence instead of stale pre-pause state (CE2).
    private(set) var needsReconfirmation: Bool = true
    private var pending: Pending?

    init(debounceInterval: TimeInterval) {
        self.debounceInterval = debounceInterval
    }

    /// Full reset — workout start.
    mutating func reset() {
        committed = .unknown
        needsReconfirmation = true
        pending = nil
    }

    /// Resume-from-pause: keep the last activity for display continuity but
    /// force it to be re-earned before a segment is opened against it.
    mutating func requireReconfirmation() {
        needsReconfirmation = true
        pending = nil
    }

    // MARK: - Input

    @discardableResult
    mutating func ingest(activity: DetectedActivity, confidence: Confidence, now: Date) -> Ingest {
        guard activity != .unknown else { return .droppedUnclassified }
        guard confidence >= .medium else { return .droppedLowConfidence(activity) }

        if activity == committed && !needsReconfirmation {
            pending = nil
            return .confirmedCurrent(activity)
        }

        if var current = pending, current.activity == activity {
            current.minConfidence = min(current.minConfidence, confidence)
            current.maxConfidence = max(current.maxConfidence, confidence)
            pending = current
            return .continuedPending(activity)
        }

        pending = Pending(activity: activity, since: now, minConfidence: confidence, maxConfidence: confidence)
        return .startedPending(activity)
    }

    // MARK: - Evaluation (called once per display tick)

    mutating func evaluate(cadence: Int?, now: Date) -> Evaluation {
        guard var current = pending else { return .idle }

        let held = now.timeIntervalSince(current.since)
        guard held >= debounceInterval else { return .idle }

        let check = Self.cadenceCheck(for: current.activity, cadence: cadence)
        if check == .contradicts && current.minConfidence < .high {
            // Motion and the pedometer disagree and motion isn't certain —
            // keep waiting rather than persisting a probable misclassification.
            guard !current.holdReported else {
                pending = current
                return .idle
            }
            current.holdReported = true
            pending = current
            return .holding(Hold(activity: current.activity,
                                 minConfidence: current.minConfidence,
                                 cadence: cadence,
                                 heldFor: held))
        }

        let decision = Decision(
            activity: current.activity,
            previous: committed,
            minConfidence: current.minConfidence,
            maxConfidence: current.maxConfidence,
            cadence: cadence,
            cadenceCheck: check,
            heldFor: held,
            isReconfirmation: current.activity == committed
        )
        committed = current.activity
        needsReconfirmation = false
        pending = nil
        return .commit(decision)
    }
}
