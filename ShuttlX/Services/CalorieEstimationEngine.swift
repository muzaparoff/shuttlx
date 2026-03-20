import Foundation
import os.log

enum CalorieEstimationEngine {
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "CalorieEstimation")

    // MARK: - Default METs per Sport

    static func defaultMET(for sport: WorkoutSport) -> Double {
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

    // MARK: - Estimation

    /// Estimate calories: MET x weight(kg) x duration(hours)
    /// - Parameters:
    ///   - met: Metabolic equivalent (use device MET or sport default)
    ///   - weightKg: User weight in kilograms (defaults to 70 if nil)
    ///   - durationSeconds: Workout duration in seconds
    ///   - averageHeartRate: Optional average HR for MET adjustment
    ///   - age: Optional user age for HR-adjusted MET
    /// - Returns: Estimated kilocalories
    static func estimate(
        met: Double,
        weightKg: Double?,
        durationSeconds: TimeInterval,
        averageHeartRate: Double? = nil,
        age: Int? = nil
    ) -> Double {
        let weight = weightKg ?? 70.0
        let hours = durationSeconds / 3600.0
        let adjustedMET = hrAdjustedMET(baseMET: met, averageHR: averageHeartRate, age: age)
        let kcal = adjustedMET * weight * hours
        logger.debug("Calorie estimate: MET=\(adjustedMET, privacy: .public) weight=\(weight)kg duration=\(hours, privacy: .public)h → \(kcal, privacy: .public) kcal")
        return kcal
    }

    /// Convenience: estimate from a TrainingSession using sport default MET
    static func estimate(
        for session: TrainingSession,
        weightKg: Double?,
        age: Int? = nil
    ) -> Double {
        let sport = session.sportType ?? .running
        let met = defaultMET(for: sport)
        return estimate(
            met: met,
            weightKg: weightKg,
            durationSeconds: session.duration,
            averageHeartRate: session.averageHeartRate,
            age: age
        )
    }

    /// Convenience: estimate using a device's effective MET
    static func estimate(
        for session: TrainingSession,
        device: ExerciseDevice,
        weightKg: Double?,
        age: Int? = nil
    ) -> Double {
        return estimate(
            met: device.effectiveMET,
            weightKg: weightKg,
            durationSeconds: session.duration,
            averageHeartRate: session.averageHeartRate,
            age: age
        )
    }

    // MARK: - HR-Adjusted MET

    /// Adjusts base MET using average heart rate and age.
    /// Uses a simplified Swain formula adjustment factor.
    private static func hrAdjustedMET(baseMET: Double, averageHR: Double?, age: Int?) -> Double {
        guard let hr = averageHR, let age = age, hr > 0, age > 0 else {
            return baseMET
        }

        let maxHR = 220.0 - Double(age)
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
