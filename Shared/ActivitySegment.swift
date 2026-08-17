import Foundation

public struct ActivitySegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var activityType: DetectedActivity
    public var startDate: Date
    public var endDate: Date?
    public var steps: Int?
    public var distance: Double?

    // MARK: - Per-phase energy (Phase 2, 2026-08 run+walk plan)
    //
    // Two independent numbers are kept side by side, deliberately:
    //
    // * `activeEnergyCalories` — Apple's own `activeEnergyBurned` samples summed
    //   over this segment's time range. Personally calibrated (HR + motion + the
    //   wearer's Health profile) but produced under the workout's single
    //   `HKWorkoutActivityType`, so a walk phase inside a `.running` session is
    //   costed by Apple's running model. **Currently the primary display value.**
    // * `estimatedCalories` — ShuttlX's MET estimate for this phase
    //   (`CalorieEstimationEngine`), which uses the *detected* activity's MET and
    //   is therefore phase-honest but population-average rather than personal.
    //   Nil when the wearer's body mass is unknown — never a 70 kg placeholder.
    //
    // Which one is promoted to primary is the open empirical question in plan
    // item 8; both are persisted so the on-device bias measurement can settle it
    // without re-recording workouts.

    /// Average heart rate (BPM) over this segment, paused time excluded.
    public var averageHeartRate: Double?
    /// ShuttlX's MET-based estimate for this phase, in kilocalories.
    public var estimatedCalories: Double?
    /// Apple's `activeEnergyBurned` summed over this phase, in kilocalories.
    public var activeEnergyCalories: Double?

    public var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    public init(id: UUID = UUID(),
                activityType: DetectedActivity,
                startDate: Date,
                endDate: Date? = nil,
                steps: Int? = nil,
                distance: Double? = nil,
                averageHeartRate: Double? = nil,
                estimatedCalories: Double? = nil,
                activeEnergyCalories: Double? = nil) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
        self.distance = distance
        self.averageHeartRate = averageHeartRate
        self.estimatedCalories = estimatedCalories
        self.activeEnergyCalories = activeEnergyCalories
    }
}
