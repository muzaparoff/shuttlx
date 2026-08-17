import Foundation

/// Timestamped side-channel for the metrics that only matter *per phase*.
///
/// `WatchWorkoutManager` keeps O(1) running accumulators for the whole-session
/// averages (`heartRateSampleSum`, `totalCaloriesAccumulated`) — those throw the
/// sample timestamps away, which is fine for a session average and useless for
/// Phase 2 of `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md`, where each
/// closed `ActivitySegment` needs *its own* average HR and *its own* share of
/// Apple's `activeEnergyBurned`.
///
/// So this ledger keeps the time axis, cheaply:
/// * **Heart rate** is bucketed at `hrBucketSeconds` (sum + count per bucket). A
///   2-hour workout is ~1,440 buckets regardless of sample rate; per-second
///   precision buys nothing when the consumer is a MET adjustment.
/// * **Energy** keeps real spans, because attribution across a segment boundary
///   is proportional to the overlap and that needs the sample's own start/end.
///   Beyond `maxEnergySpans` the oldest half is coalesced pairwise — totals stay
///   exact, only boundary precision degrades, and memory stays bounded on a
///   multi-hour session.
/// * **Pauses** are recorded so a segment that straddles a pause is costed on its
///   *active* duration. Segments are closed at resume, not at pause, so paused
///   time really does sit inside a segment's span.
///
/// Pure value type, no HealthKit/CoreMotion import — same rationale as
/// `ActivityClassifier` and `RecoverySegmenter`: the arithmetic is traceable in
/// isolation.
struct SegmentMetricsLedger {

    /// HR resolution. 5s is well under the 10s minimum segment length
    /// (`SegmentHygiene.minimumSegmentDuration`), so every kept segment lands at
    /// least one bucket.
    static let hrBucketSeconds: TimeInterval = 5
    /// ~24 bytes per span; 4,000 spans ≈ 96 KB worst case.
    static let maxEnergySpans = 4_000

    struct Span: Sendable {
        var start: Date
        var end: Date
        var kcal: Double
    }

    private struct Bucket {
        var sum: Double = 0
        var count: Int = 0
    }

    private var hrBuckets: [Int: Bucket] = [:]
    private var energySpans: [Span] = []
    private var pauses: [(start: Date, end: Date)] = []

    /// True once any energy sample has been seen — distinguishes "Apple reported
    /// zero for this phase" from "Apple reported nothing at all".
    private(set) var hasEnergySamples = false

    // MARK: - Recording

    mutating func reset() {
        hrBuckets.removeAll(keepingCapacity: false)
        energySpans.removeAll(keepingCapacity: false)
        pauses.removeAll(keepingCapacity: false)
        hasEnergySamples = false
    }

    private static func bucketIndex(for date: Date) -> Int {
        Int((date.timeIntervalSinceReferenceDate / hrBucketSeconds).rounded(.down))
    }

    private static func bucketStart(_ index: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(index) * hrBucketSeconds)
    }

    mutating func recordHeartRate(bpm: Double, at date: Date) {
        guard bpm > 0 else { return }
        let index = Self.bucketIndex(for: date)
        var bucket = hrBuckets[index] ?? Bucket()
        bucket.sum += bpm
        bucket.count += 1
        hrBuckets[index] = bucket
    }

    mutating func recordEnergy(kcal: Double, from start: Date, to end: Date) {
        hasEnergySamples = true
        guard kcal > 0 else { return }
        energySpans.append(Span(start: start, end: max(end, start), kcal: kcal))
        if energySpans.count > Self.maxEnergySpans {
            compactEnergySpans()
        }
    }

    mutating func recordPause(from start: Date, to end: Date) {
        guard end > start else { return }
        pauses.append((start: start, end: end))
    }

    /// Halve the span count by merging neighbours. Sum is preserved exactly.
    private mutating func compactEnergySpans() {
        energySpans.sort { $0.start < $1.start }
        var merged: [Span] = []
        merged.reserveCapacity(energySpans.count / 2 + 1)
        var index = 0
        while index < energySpans.count {
            if index + 1 < energySpans.count {
                let a = energySpans[index], b = energySpans[index + 1]
                merged.append(Span(start: min(a.start, b.start),
                                   end: max(a.end, b.end),
                                   kcal: a.kcal + b.kcal))
                index += 2
            } else {
                merged.append(energySpans[index])
                index += 1
            }
        }
        energySpans = merged
    }

    // MARK: - Queries

    /// Average BPM over `[from, to)`. Nil when no sample landed in the window.
    func averageHeartRate(from: Date, to: Date) -> Double? {
        guard to > from else { return nil }
        let first = Self.bucketIndex(for: from)
        let last = Self.bucketIndex(for: to)
        var sum: Double = 0
        var count = 0
        var index = first
        while index <= last {
            if let bucket = hrBuckets[index], bucket.count > 0 {
                let start = Self.bucketStart(index)
                // Bucket belongs to the window when its start falls inside it;
                // the boundary bucket is claimed by whichever segment contains
                // its start, so no sample is double counted across segments.
                if start >= from && start < to {
                    sum += bucket.sum
                    count += bucket.count
                }
            }
            index += 1
        }
        if count == 0 {
            // Sub-bucket window (or one that sits entirely inside a bucket):
            // fall back to the bucket containing `from`.
            if let bucket = hrBuckets[first], bucket.count > 0 {
                return bucket.sum / Double(bucket.count)
            }
            return nil
        }
        return sum / Double(count)
    }

    /// Apple's active energy attributed to `[from, to)`, proportional to each
    /// sample's overlap with the window. Nil when no energy sample was ever
    /// delivered (HealthKit read denied, simulator, etc.).
    func activeEnergy(from: Date, to: Date) -> Double? {
        guard hasEnergySamples else { return nil }
        guard to > from else { return 0 }
        var total: Double = 0
        for span in energySpans {
            let overlapStart = max(span.start, from)
            let overlapEnd = min(span.end, to)
            let spanDuration = span.end.timeIntervalSince(span.start)
            if spanDuration <= 0 {
                // Instantaneous sample: attribute wholly to the window holding it.
                if span.start >= from && span.start < to { total += span.kcal }
                continue
            }
            let overlap = overlapEnd.timeIntervalSince(overlapStart)
            guard overlap > 0 else { continue }
            total += span.kcal * (overlap / spanDuration)
        }
        return total
    }

    func pausedDuration(from: Date, to: Date) -> TimeInterval {
        guard to > from else { return 0 }
        var total: TimeInterval = 0
        for pause in pauses {
            let overlap = min(pause.end, to).timeIntervalSince(max(pause.start, from))
            if overlap > 0 { total += overlap }
        }
        return total
    }

    /// Wall-clock span minus any paused time inside it.
    func activeDuration(from: Date, to: Date) -> TimeInterval {
        guard to > from else { return 0 }
        return max(0, to.timeIntervalSince(from) - pausedDuration(from: from, to: to))
    }
}
