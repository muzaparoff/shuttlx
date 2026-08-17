import Foundation
import os.log

/// Personal anthropometrics used by the calorie model.
///
/// Resolution order is the caller's job (manual Settings entry beats HealthKit);
/// this type only carries the result. `weightKg` is **optional on purpose**: the
/// energy equation is linear in body mass, so a missing weight cannot be papered
/// over with a 70 kg placeholder without inventing a number the wearer never gave
/// us. `CalorieEstimationEngine.estimate(for:)` returns `nil` in that case and the
/// UI asks for the weight instead.
public struct Anthropometrics: Sendable, Equatable {
    public enum BiologicalSex: String, Sendable, Codable {
        case female, male, other, unspecified
    }

    public var weightKg: Double?
    public var age: Int?
    /// Calibrated max HR (manual override or Tanaka from age). `nil` falls back to
    /// the classic `220 - age` inside the HR adjustment.
    public var maxHeartRate: Double?
    /// Read for completeness of the health profile (plan item 5). The MET model
    /// below is sex-agnostic — this is carried so a future sex-specific model
    /// (e.g. Keytel) does not need another authorization prompt.
    public var biologicalSex: BiologicalSex

    public var hasBodyMass: Bool { (weightKg ?? 0) > 0 }

    public init(weightKg: Double? = nil,
                age: Int? = nil,
                maxHeartRate: Double? = nil,
                biologicalSex: BiologicalSex = .unspecified) {
        self.weightKg = weightKg
        self.age = age
        self.maxHeartRate = maxHeartRate
        self.biologicalSex = biologicalSex
    }
}

/// MET-based energy estimation: `kcal = hrAdjustedMET × weightKg × hours`.
///
/// Lives in the shared package (not the iOS target) since Phase 2 of
/// `docs/plans/2026-08-runwalk-dynamic-sessions-plan.md` calls it **in-session on
/// the watch**, once per closed `ActivitySegment`, so a walk phase inside a run is
/// costed at a walking MET instead of inheriting Apple's whole-workout running
/// model. The iOS `TrainingSession` conveniences stay in
/// `ShuttlX/Services/CalorieEstimationEngine.swift` as an extension because
/// `TrainingSession` is still a per-target duplicated model.
public enum CalorieEstimationEngine {
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "CalorieEstimation")

    // MARK: - Default METs per Sport

    public static func defaultMET(for sport: WorkoutSport) -> Double {
        switch sport {
        case .running: return 9.8
        case .walking: return 3.5
        case .cycling: return 7.5
        case .swimming: return 8.0
        case .hiking: return 6.0
        case .elliptical: return 5.0
        case .crossTraining: return 6.0
        case .other: return 4.0
        }
    }

    /// Compendium value for standing/resting between efforts.
    public static let stationaryMET: Double = 1.3

    /// Sports where a detected run/walk phase is a real gait change rather than
    /// noise from a wrist bobbing on handlebars or in a pool.
    private static func isFootSport(_ sport: WorkoutSport) -> Bool {
        switch sport {
        case .running, .walking, .hiking: return true
        case .cycling, .swimming, .elliptical, .crossTraining, .other: return false
        }
    }

    /// MET for a **detected phase** inside a session of a given sport.
    ///
    /// This is the per-activity table Phase 2 needs: the same 20-minute session
    /// yields 9.8 MET over its run segments and 3.5 over its walk segments, which
    /// is precisely the distinction Apple's single-activity-type workout cannot
    /// make. For non-foot sports the detector's gait guess is meaningless, so the
    /// sport's own MET is used throughout.
    public static func met(for activity: DetectedActivity, sport: WorkoutSport) -> Double {
        switch activity {
        case .running:
            return isFootSport(sport) ? defaultMET(for: .running) : defaultMET(for: sport)
        case .walking:
            return isFootSport(sport) ? defaultMET(for: .walking) : defaultMET(for: sport)
        case .stationary:
            return stationaryMET
        case .unknown:
            return defaultMET(for: sport)
        }
    }

    // MARK: - Estimation

    /// Core estimate. Weight is **required** — see `Anthropometrics.weightKg`.
    /// - Parameters:
    ///   - met: Metabolic equivalent (sport/activity default or a device's MET)
    ///   - weightKg: Body mass in kilograms
    ///   - durationSeconds: Active duration (exclude paused time)
    ///   - averageHeartRate: Average BPM over the same span, for MET adjustment
    ///   - age: Used to derive max HR when `maxHeartRate` is nil
    ///   - maxHeartRate: Calibrated max HR, preferred over the age formula
    /// - Returns: Kilocalories
    public static func estimate(
        met: Double,
        weightKg: Double,
        durationSeconds: TimeInterval,
        averageHeartRate: Double? = nil,
        age: Int? = nil,
        maxHeartRate: Double? = nil
    ) -> Double {
        guard weightKg > 0, durationSeconds > 0 else { return 0 }
        let hours = durationSeconds / 3600.0
        let adjustedMET = hrAdjustedMET(baseMET: met,
                                        averageHR: averageHeartRate,
                                        age: age,
                                        maxHeartRate: maxHeartRate)
        let kcal = adjustedMET * weightKg * hours
        logger.debug("Calorie estimate: MET=\(adjustedMET, privacy: .public) weight=\(weightKg)kg duration=\(hours, privacy: .public)h → \(kcal, privacy: .public) kcal")
        return kcal
    }

    /// Estimate for one detected phase. Returns `nil` when body mass is unknown —
    /// the caller surfaces "add your weight in Health" rather than a fabricated
    /// number.
    public static func estimateSegment(
        activity: DetectedActivity,
        sport: WorkoutSport,
        activeDurationSeconds: TimeInterval,
        averageHeartRate: Double?,
        anthropometrics: Anthropometrics
    ) -> Double? {
        guard let weight = anthropometrics.weightKg, weight > 0 else { return nil }
        guard activeDurationSeconds > 0 else { return nil }
        return estimate(
            met: met(for: activity, sport: sport),
            weightKg: weight,
            durationSeconds: activeDurationSeconds,
            averageHeartRate: averageHeartRate,
            age: anthropometrics.age,
            maxHeartRate: anthropometrics.maxHeartRate
        )
    }

    // MARK: - HR-Adjusted MET

    /// Adjusts base MET using average heart rate relative to max HR.
    /// Simplified Swain-style adjustment: ~1.0× at 70% of max, scaling up above.
    private static func hrAdjustedMET(baseMET: Double,
                                      averageHR: Double?,
                                      age: Int?,
                                      maxHeartRate: Double?) -> Double {
        guard let hr = averageHR, hr > 0 else { return baseMET }

        let maxHR: Double
        if let calibrated = maxHeartRate, calibrated > 0 {
            maxHR = calibrated
        } else if let age = age, age > 0 {
            maxHR = 220.0 - Double(age)
        } else {
            return baseMET
        }
        guard maxHR > 0 else { return baseMET }

        let hrReserveRatio = hr / maxHR

        // Clamp to reasonable range
        guard hrReserveRatio > 0.3, hrReserveRatio < 1.0 else {
            return baseMET
        }

        // Scale factor: if HR is high relative to predicted max, bump MET up slightly
        // At ~70% maxHR the factor is ~1.0, above that it increases
        let adjustmentFactor = 0.5 + (hrReserveRatio * 0.7)
        return baseMET * adjustmentFactor
    }
}
