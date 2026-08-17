import Foundation
import ShuttlXShared

/// Pure finalisation pass over the recorded `ActivitySegment` timeline.
///
/// Phase 1 / CE2 of `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md`:
/// the detector can emit a single 5 s blip (one classifier misfire that survives
/// debounce) which used to persist as a real segment. This pass removes that
/// noise before the session is checkpointed or sent to the phone.
///
/// **Merge direction (documented choice):** a sub-minimum segment is absorbed by
/// its **preceding** neighbour — the activity you were already doing is assumed
/// to have continued through the blip. The preceding neighbour is a settled,
/// debounced classification; the blip is not. Only when there is no predecessor
/// (the blip opens the session) is it merged forward into the following segment.
/// After absorption, adjacent same-type segments are coalesced, so
/// `RUN 300s | WALK 6s | RUN 240s` collapses to a single `RUN 546s` rather than
/// leaving two abutting RUN rows.
///
/// Interval sessions skip the length filter entirely (`minimumDuration <= 0`):
/// their segments come from the template's step schedule, which is ground truth
/// and cannot be "noise" even when a step is short.
enum SegmentHygiene {

    /// Anything shorter than this from the detector is treated as a classifier blip.
    static let minimumSegmentDuration: TimeInterval = 10

    struct Result {
        var segments: [ActivitySegment]
        /// Segments folded into a neighbour because they were under the minimum.
        var absorbed: Int
        /// Adjacent same-type segments merged after absorption.
        var coalesced: Int
    }

    /// - Parameters:
    ///   - raw: segments as recorded, last one possibly still open.
    ///   - minimumDuration: `0` disables the length filter (interval mode).
    ///   - now: close-out timestamp for a still-open final segment.
    static func finalize(_ raw: [ActivitySegment],
                         minimumDuration: TimeInterval,
                         now: Date) -> Result {
        // 1. Close any open segment. A non-final open segment (shouldn't happen,
        //    but a crash checkpoint can catch one) ends where the next begins.
        var closed: [ActivitySegment] = []
        for (index, segment) in raw.enumerated() {
            var s = segment
            if s.endDate == nil {
                s.endDate = index + 1 < raw.count ? raw[index + 1].startDate : now
            }
            // 2. Drop degenerate / inverted spans outright.
            guard let end = s.endDate, end > s.startDate else { continue }
            closed.append(s)
        }

        guard minimumDuration > 0, closed.count > 1 else {
            return Result(segments: closed, absorbed: 0, coalesced: 0)
        }

        // 3. Absorb short segments (backwards by preference, forwards when the
        //    predecessor is on the other side of a pause gap).
        var kept: [ActivitySegment] = []
        var leadingBlips: [ActivitySegment] = []
        var absorbed = 0

        for segment in closed {
            if segment.duration < minimumDuration {
                if var previous = kept.last, isContiguous(previous, segment) {
                    previous.endDate = segment.endDate
                    previous.steps = sum(previous.steps, segment.steps)
                    previous.distance = sum(previous.distance, segment.distance)
                    kept[kept.count - 1] = previous
                    absorbed += 1
                } else {
                    // Head of the session, or the first thing after a pause —
                    // merging backwards would swallow the paused time.
                    leadingBlips.append(segment)
                }
                continue
            }

            var s = segment
            if let first = leadingBlips.first, let last = leadingBlips.last {
                // Only stretch the start back when the blips actually abut this
                // segment; otherwise just keep their steps/distance.
                if isContiguous(last, s) {
                    s.startDate = first.startDate
                }
                for blip in leadingBlips {
                    s.steps = sum(s.steps, blip.steps)
                    s.distance = sum(s.distance, blip.distance)
                }
                absorbed += leadingBlips.count
                leadingBlips.removeAll()
            }
            kept.append(s)
        }

        // Trailing blips that could not merge backwards (post-pause tail).
        if !kept.isEmpty, !leadingBlips.isEmpty {
            kept.append(contentsOf: leadingBlips)
            leadingBlips.removeAll()
        }

        // Degenerate case: every segment was under the minimum (a very short
        // session). Collapse to one segment spanning the whole thing, typed by
        // whichever activity held the most time.
        if kept.isEmpty, let first = leadingBlips.first, let last = leadingBlips.last {
            var totals: [DetectedActivity: TimeInterval] = [:]
            var steps: Int? = nil
            var distance: Double? = nil
            for blip in leadingBlips {
                totals[blip.activityType, default: 0] += blip.duration
                steps = sum(steps, blip.steps)
                distance = sum(distance, blip.distance)
            }
            let dominant = totals.max { $0.value < $1.value }?.key ?? first.activityType
            absorbed = max(0, leadingBlips.count - 1)
            return Result(
                segments: [ActivitySegment(activityType: dominant,
                                           startDate: first.startDate,
                                           endDate: last.endDate,
                                           steps: steps,
                                           distance: distance)],
                absorbed: absorbed,
                coalesced: 0
            )
        }

        // 4. Coalesce adjacent same-type segments — but never across a pause
        //    gap, which would fold paused time into the activity total.
        var merged: [ActivitySegment] = []
        var coalesced = 0
        for segment in kept {
            if var previous = merged.last,
               previous.activityType == segment.activityType,
               isContiguous(previous, segment) {
                previous.endDate = segment.endDate
                previous.steps = sum(previous.steps, segment.steps)
                previous.distance = sum(previous.distance, segment.distance)
                merged[merged.count - 1] = previous
                coalesced += 1
            } else {
                merged.append(segment)
            }
        }

        return Result(segments: merged, absorbed: absorbed, coalesced: coalesced)
    }

    // MARK: - Helpers

    /// Segments recorded back-to-back abut exactly; anything larger than this is
    /// a pause (or an un-classified hole) and must not be merged over.
    static let contiguityTolerance: TimeInterval = 1.0

    private static func isContiguous(_ lhs: ActivitySegment, _ rhs: ActivitySegment) -> Bool {
        guard let end = lhs.endDate else { return false }
        return rhs.startDate.timeIntervalSince(end) <= contiguityTolerance
    }

    /// `nil + nil == nil` (never recorded), anything else adds with 0 defaults.
    private static func sum(_ lhs: Int?, _ rhs: Int?) -> Int? {
        guard lhs != nil || rhs != nil else { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }

    private static func sum(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard lhs != nil || rhs != nil else { return nil }
        return (lhs ?? 0) + (rhs ?? 0)
    }
}
