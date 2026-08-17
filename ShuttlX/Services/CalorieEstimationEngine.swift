import Foundation
import ShuttlXShared

/// iOS-side conveniences over the shared `CalorieEstimationEngine`.
///
/// The MET math itself moved to `Shared/CalorieEstimationEngine.swift` in Phase 2
/// of `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md` so the watch can call
/// it per detected segment while the workout is running. Only the overloads that
/// take a `TrainingSession` stay here: `TrainingSession` is still duplicated per
/// target (`.claude/rules/models.md`) and therefore cannot live in the package.
///
/// Every overload returns an **optional** — a nil body mass yields nil, never a
/// silent 70 kg placeholder (plan item 5).
extension CalorieEstimationEngine {

    /// Estimate from a session using its sport's default MET.
    static func estimate(
        for session: TrainingSession,
        weightKg: Double?,
        age: Int? = nil,
        maxHeartRate: Double? = nil
    ) -> Double? {
        let sport = session.sportType ?? .running
        return estimate(
            for: session,
            met: defaultMET(for: sport),
            weightKg: weightKg,
            age: age,
            maxHeartRate: maxHeartRate
        )
    }

    /// Estimate from a session using a device's effective MET.
    static func estimate(
        for session: TrainingSession,
        device: ExerciseDevice,
        weightKg: Double?,
        age: Int? = nil,
        maxHeartRate: Double? = nil
    ) -> Double? {
        estimate(
            for: session,
            met: device.effectiveMET,
            weightKg: weightKg,
            age: age,
            maxHeartRate: maxHeartRate
        )
    }

    private static func estimate(
        for session: TrainingSession,
        met: Double,
        weightKg: Double?,
        age: Int?,
        maxHeartRate: Double?
    ) -> Double? {
        guard let weight = weightKg, weight > 0 else { return nil }
        return estimate(
            met: met,
            weightKg: weight,
            durationSeconds: session.duration,
            averageHeartRate: session.averageHeartRate,
            age: age,
            maxHeartRate: maxHeartRate
        )
    }
}
