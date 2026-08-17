import Foundation
import HealthKit
import ShuttlXShared
import os.log

#if os(watchOS)

/// Phase 3 of `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md` (items 9-11):
/// publishes ShuttlX's detected walk/run phase timeline **into the HKWorkout**, so
/// any other HealthKit-reading app can see the interval structure and query
/// per-phase statistics.
///
/// ## What Apple's API actually allows (verified against the watchOS 26.5 SDK headers)
///
/// * `HKWorkoutActivity.allStatistics` / `statisticsForType:` are documented as
///   *"statistics ... for all of the samples that have been added to the workout
///   **within the date interval of this activity**"* (`HKWorkoutActivity.h`). The
///   statistics are derived from the activity's date range, **not** from how the
///   activity was created. So a closed activity handed to
///   `HKWorkoutBuilder.addWorkoutActivity(_:completion:)` yields exactly the same
///   queryable artifact as one opened live via
///   `HKWorkoutSession.beginNewActivity(configuration:date:metadata:)`.
/// * `HKWorkoutEvent` of type `.segment` is one of only two event types that
///   *"support a nonzero duration"* (`HKWorkout.h`), so each phase is written as a
///   real spanning interval rather than a zero-length marker.
/// * HealthKit metadata is **stricter than a property list**: *"Keys must be
///   NSString and values must be either NSString, NSNumber, NSDate, or
///   HKQuantity"* (`HKObject.h`). No arrays, no dictionaries — hence the JSON
///   **string** for the structured per-phase blob and NSNumber scalars for the
///   roll-ups.
///
/// ## Why the session-level `beginNewActivity` route is deliberately NOT used
///
/// 1. `beginNewActivityWithConfiguration:date:metadata:` documents that
///    *"Sensor algorithms to generate data would be updated to match the new
///    activity"* (`HKWorkoutSession.h`). Re-arming the sensor algorithms at every
///    walk/run transition would perturb precisely the HR / distance / active-energy
///    stream that Phase 2's calorie attribution — and plan item 8's walk-vs-run
///    bias measurement — are built on.
/// 2. It is asynchronous and reports failure only through the session delegate.
///    `WatchWorkoutManager+HealthKitDelegates.swift` treats
///    `workoutSession(_:didFailWithError:)` as fatal: it saves and tears the
///    workout down. A single rejected activity call would therefore END the user's
///    workout. `addWorkoutActivity(_:completion:)` reports errors in its own
///    completion handler with zero session impact.
/// 3. A live-opened activity has a nil end date until explicitly closed. An app
///    kill mid-workout would leave that activity open for the orphan-recovery path
///    (`WatchWorkoutManager.recoverOrphanedHKSession()`) to inherit. Only fully
///    closed activities are ever written here, so that state is unreachable.
///
/// ## Why everything is written at finalization, not at each segment close
///
/// The app-side timeline is only settled after `SegmentHygiene.finalize` (sub-10s
/// blips absorbed, same-type neighbours coalesced) and the per-phase energy
/// annotation. Emitting live would publish blips to HealthKit that ShuttlX itself
/// later merges away — two contradicting timelines for the same workout. Because
/// every event and activity carries its own date interval, *when* the call is made
/// has no effect on the recorded timeline; only the workout having not yet been
/// finished matters (`addWorkoutEvents` / `addWorkoutActivity` are documented as an
/// error only *after* `finishWorkout`).
enum WorkoutPhaseHealthKitWriter {

    // MARK: - Metadata keys
    //
    // All namespaced under `com.shuttlx.` so they can never collide with Apple's
    // `HKMetadataKey*` constants (which are all `HKxxx`-prefixed).

    enum Key {
        static let schemaVersion = "com.shuttlx.phaseSchemaVersion"
        static let phaseCount = "com.shuttlx.phaseCount"
        /// JSON array of per-phase objects — see `PhaseRecord`.
        static let phases = "com.shuttlx.phases"
        /// How many phases the JSON blob actually contains. Present only when it
        /// is shorter than `phaseCount`, i.e. the blob was truncated to fit the
        /// byte budget — a reader must not assume the two agree.
        static let phasesEncoded = "com.shuttlx.phasesEncoded"

        static let runSeconds = "com.shuttlx.runSeconds"
        static let walkSeconds = "com.shuttlx.walkSeconds"
        static let otherSeconds = "com.shuttlx.otherSeconds"

        static let runKilocaloriesShuttlX = "com.shuttlx.runKilocaloriesShuttlX"
        static let walkKilocaloriesShuttlX = "com.shuttlx.walkKilocaloriesShuttlX"
        static let runKilocaloriesApple = "com.shuttlx.runKilocaloriesApple"
        static let walkKilocaloriesApple = "com.shuttlx.walkKilocaloriesApple"

        // Per-activity / per-event keys
        static let phase = "com.shuttlx.phase"
        static let phaseIndex = "com.shuttlx.phaseIndex"
        static let averageHeartRate = "com.shuttlx.averageHeartRate"
        static let kilocaloriesShuttlX = "com.shuttlx.kilocaloriesShuttlX"
        static let kilocaloriesApple = "com.shuttlx.kilocaloriesApple"
        static let distanceKilometers = "com.shuttlx.distanceKilometers"
        static let steps = "com.shuttlx.steps"
    }

    /// Bump when the meaning of any key above changes, so a future reader can
    /// tell an old workout's encoding from a new one.
    static let schemaVersion = 1

    /// Hard ceiling on how many phases are published as activities/events.
    ///
    /// Two reasons it exists. (1) A well-behaved session produces tens of phases;
    /// anything past this is detector pathology and must not become an unbounded
    /// write loop against HealthKit. (2) Every activity is one awaited IPC round
    /// trip that sits *between* `session.end()` and `builder.finishWorkout()` —
    /// keeping the count bounded keeps the workout's finalization latency bounded,
    /// which matters because that window is when the app is losing its
    /// workout-processing background runtime. The app's own
    /// `TrainingSession.segments` keeps every phase regardless.
    static let maxPublishedPhases = 100

    /// Byte budget for the `com.shuttlx.phases` JSON string. HealthKit publishes
    /// no metadata size limit, so an unbounded blob is a bad idea on principle;
    /// past this the structured blob is dropped and the scalar roll-ups (which are
    /// what a reader most likely wants anyway) still go through.
    static let maxPhasesJSONBytes = 8_192

    /// A workout with a single phase gains nothing from an activity/event that
    /// merely restates the workout's own span, so only the summary metadata is
    /// written in that case.
    static let minimumPhasesForActivities = 2

    struct Bounds {
        /// Builder start (`beginCollection`), never the manager's
        /// `workoutStartTime` — the latter is a few ms earlier and HealthKit
        /// requires events/activities to sit inside the workout.
        let start: Date
        /// The date `endCollection(at:)` will be called with.
        let end: Date
    }

    /// A phase clamped into the workout's own bounds.
    struct Phase {
        let segment: ActivitySegment
        let interval: DateInterval
    }

    // MARK: - Pure derivation

    /// Clamps each segment into `bounds`, dropping anything that ends up
    /// degenerate (zero/negative length, or entirely outside the workout).
    static func phases(from segments: [ActivitySegment], bounds: Bounds) -> [Phase] {
        guard bounds.end > bounds.start else { return [] }
        var result: [Phase] = []
        result.reserveCapacity(segments.count)
        for segment in segments {
            let rawEnd = segment.endDate ?? bounds.end
            let start = max(segment.startDate, bounds.start)
            let end = min(rawEnd, bounds.end)
            guard end > start else { continue }
            result.append(Phase(segment: segment, interval: DateInterval(start: start, end: end)))
        }
        return result
    }

    /// Metadata attached to a single phase's `HKWorkoutActivity` and to its
    /// `.segment` event. Only non-nil measurements are included — an absent key
    /// reads as "not measured", which a zero would misreport.
    static func metadata(for phase: Phase, index: Int) -> [String: Any] {
        var metadata: [String: Any] = [
            Key.phase: phase.segment.activityType.rawValue,
            Key.phaseIndex: NSNumber(value: index)
        ]
        if let hr = phase.segment.averageHeartRate {
            metadata[Key.averageHeartRate] = NSNumber(value: rounded(hr))
        }
        if let kcal = phase.segment.estimatedCalories {
            metadata[Key.kilocaloriesShuttlX] = NSNumber(value: rounded(kcal))
        }
        if let kcal = phase.segment.activeEnergyCalories {
            metadata[Key.kilocaloriesApple] = NSNumber(value: rounded(kcal))
        }
        if let km = phase.segment.distance {
            metadata[Key.distanceKilometers] = NSNumber(value: rounded(km, places: 3))
        }
        if let steps = phase.segment.steps {
            metadata[Key.steps] = NSNumber(value: steps)
        }
        return metadata
    }

    /// Workout-level walk/run split (plan item 10). Durations are the phases'
    /// clamped wall-clock spans; the calorie totals are Phase 2's two independent
    /// estimates kept side by side, exactly as `ActivitySegment` documents them.
    static func summaryMetadata(for phases: [Phase], workoutStart: Date) -> [String: Any] {
        var metadata: [String: Any] = [
            Key.schemaVersion: NSNumber(value: schemaVersion),
            Key.phaseCount: NSNumber(value: phases.count)
        ]

        func seconds(_ predicate: (DetectedActivity) -> Bool) -> Double {
            phases.filter { predicate($0.segment.activityType) }
                .reduce(0) { $0 + $1.interval.duration }
        }
        func kilocalories(_ activity: DetectedActivity,
                          _ pick: (ActivitySegment) -> Double?) -> Double? {
            let values = phases.filter { $0.segment.activityType == activity }
                .compactMap { pick($0.segment) }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        }

        metadata[Key.runSeconds] = NSNumber(value: rounded(seconds { $0 == .running }))
        metadata[Key.walkSeconds] = NSNumber(value: rounded(seconds { $0 == .walking }))
        metadata[Key.otherSeconds] = NSNumber(value: rounded(seconds { $0 != .running && $0 != .walking }))

        if let value = kilocalories(.running, { $0.estimatedCalories }) {
            metadata[Key.runKilocaloriesShuttlX] = NSNumber(value: rounded(value))
        }
        if let value = kilocalories(.walking, { $0.estimatedCalories }) {
            metadata[Key.walkKilocaloriesShuttlX] = NSNumber(value: rounded(value))
        }
        if let value = kilocalories(.running, { $0.activeEnergyCalories }) {
            metadata[Key.runKilocaloriesApple] = NSNumber(value: rounded(value))
        }
        if let value = kilocalories(.walking, { $0.activeEnergyCalories }) {
            metadata[Key.walkKilocaloriesApple] = NSNumber(value: rounded(value))
        }

        if let encoded = phasesJSON(for: phases, workoutStart: workoutStart) {
            metadata[Key.phases] = encoded.json
            if encoded.count < phases.count {
                metadata[Key.phasesEncoded] = NSNumber(value: encoded.count)
            }
        }
        return metadata
    }

    /// One JSON object per phase. HealthKit metadata cannot hold an array, so the
    /// structured form travels as a single String value (the simplest encoding
    /// that survives HealthKit's value-type restriction unambiguously).
    /// `start` is an offset in seconds from the workout start — timezone-proof and
    /// far more compact than absolute dates.
    ///
    /// Over the byte budget the blob is **truncated** rather than dropped: a
    /// pathological phase count would otherwise cost a reader the entire timeline
    /// (measured: 100 phases ≈ 9 KB, just past the 8 KB budget). The returned
    /// `count` is how many phases made it in, and the caller publishes it under
    /// `Key.phasesEncoded` whenever it is short of the real total.
    static func phasesJSON(for phases: [Phase], workoutStart: Date) -> (json: String, count: Int)? {
        guard !phases.isEmpty else { return nil }
        let records = phases.prefix(maxPublishedPhases).map { phase in
            PhaseRecord(
                type: phase.segment.activityType.rawValue,
                start: rounded(phase.interval.start.timeIntervalSince(workoutStart)),
                duration: rounded(phase.interval.duration),
                bpm: phase.segment.averageHeartRate.map { rounded($0) },
                kcalShuttlX: phase.segment.estimatedCalories.map { rounded($0) },
                kcalApple: phase.segment.activeEnergyCalories.map { rounded($0) },
                km: phase.segment.distance.map { rounded($0, places: 3) },
                steps: phase.segment.steps
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var count = records.count
        while count > 0 {
            guard let data = try? encoder.encode(Array(records.prefix(count))) else { return nil }
            if data.count <= maxPhasesJSONBytes, let json = String(data: data, encoding: .utf8) {
                return (json, count)
            }
            // Records are near-uniform in size, so scaling to the budget lands in
            // one or two iterations instead of walking down one phase at a time.
            let scaled = Int(Double(count) * Double(maxPhasesJSONBytes) / Double(data.count))
            count = min(count - 1, max(0, scaled))
        }
        return nil
    }

    private struct PhaseRecord: Encodable {
        let type: String
        let start: Double
        let duration: Double
        let bpm: Double?
        let kcalShuttlX: Double?
        let kcalApple: Double?
        let km: Double?
        let steps: Int?
    }

    private static func rounded(_ value: Double, places: Int = 1) -> Double {
        let factor = pow(10.0, Double(places))
        return (value * factor).rounded() / factor
    }

    // MARK: - Write

    /// Publishes the phase timeline to `builder`. **Never throws and never
    /// aborts the caller** — every HealthKit call is individually error-logged,
    /// because this is optional interop and the mandatory
    /// `addMetadata` → `endCollection` → `finishWorkout` sequence that actually
    /// saves the user's workout must not be put at risk by it.
    ///
    /// Must be called before `finishWorkout()`; both `addWorkoutActivity` and
    /// `addWorkoutEvents` are documented as an error only after that point.
    @MainActor
    static func write(segments: [ActivitySegment],
                      configuration: HKWorkoutConfiguration,
                      builder: HKLiveWorkoutBuilder,
                      bounds: Bounds,
                      logger: Logger) async {
        let all = phases(from: segments, bounds: bounds)
        guard !all.isEmpty else {
            logger.info("HK PHASE: no phases to publish")
            return
        }

        let published = Array(all.prefix(maxPublishedPhases))
        if published.count < all.count {
            logger.warning("HK PHASE: \(all.count) phases exceeds the \(maxPublishedPhases) publish ceiling — writing the first \(published.count)")
        }

        // 1. Item 9 — one same-type HKWorkoutActivity per phase, so other apps can
        //    call statistics(for:) over each interval. The configuration is the
        //    builder's own, which guarantees the type matches the containing
        //    workout (HealthKit only permits differing types under .swimBikeRun).
        if published.count >= minimumPhasesForActivities {
            var written = 0
            for (index, phase) in published.enumerated() {
                let activity = HKWorkoutActivity(
                    workoutConfiguration: configuration,
                    start: phase.interval.start,
                    end: phase.interval.end,
                    metadata: metadata(for: phase, index: index)
                )
                do {
                    try await builder.addWorkoutActivity(activity)
                    written += 1
                } catch {
                    // One rejection means the rest will be rejected the same way;
                    // stop rather than log the identical failure N times.
                    logger.error("HK PHASE: addWorkoutActivity failed at phase \(index) — \(error.localizedDescription); skipping remaining activities")
                    break
                }
            }
            logger.info("HK PHASE: wrote \(written)/\(published.count) HKWorkoutActivity intervals")

            // 2. Item 10 — .segment events spanning the same ranges. Redundant with
            //    the activities by design: readers split between the two channels,
            //    and .segment is the older, more widely consumed one. Apple Fitness
            //    renders neither (confirmed in the plan's research).
            let events = published.enumerated().map { index, phase in
                HKWorkoutEvent(type: .segment,
                               dateInterval: phase.interval,
                               metadata: metadata(for: phase, index: index))
            }
            do {
                try await builder.addWorkoutEvents(events)
                logger.info("HK PHASE: wrote \(events.count) .segment events")
            } catch {
                logger.error("HK PHASE: addWorkoutEvents failed — \(error.localizedDescription)")
            }
        } else {
            logger.info("HK PHASE: single-phase workout — activities/events skipped, summary metadata only")
        }

        // 3. Item 10 — the walk/run split as workout metadata. Added in its own
        //    call, ahead of the mandatory metadata in saveWorkoutData(): if
        //    HealthKit rejects any key here, "the builder's metadata property will
        //    remain unchanged" (HKWorkoutBuilder.h) and the workout still saves
        //    with its required metadata intact.
        let summary = summaryMetadata(for: published, workoutStart: bounds.start)
        let runSeconds = (summary[Key.runSeconds] as? NSNumber)?.doubleValue ?? 0
        let walkSeconds = (summary[Key.walkSeconds] as? NSNumber)?.doubleValue ?? 0
        do {
            try await builder.addMetadata(summary)
            logger.info("HK PHASE: summary metadata written (run \(Int(runSeconds))s / walk \(Int(walkSeconds))s over \(published.count) phases)")
        } catch {
            logger.error("HK PHASE: addMetadata(phase summary) failed — \(error.localizedDescription)")
        }
    }
}

#endif
