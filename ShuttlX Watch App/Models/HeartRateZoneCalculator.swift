import Foundation

/// Calculates personalized heart rate zones using the Tanaka formula.
///
/// The Tanaka formula gives a more accurate max HR estimate than the classic 220-age:
///   maxHR = 208 - (0.7 × age)
///
/// Zones are defined as percentage bands of estimated or user-provided max HR:
///   Zone 1 (Easy):    50–60%
///   Zone 2 (Fat Burn): 60–70%
///   Zone 3 (Cardio):  70–80%
///   Zone 4 (Hard):    80–90%
///   Zone 5 (Peak):    90–100%
///
/// Both targets share this identical file — do not let the copies diverge.
struct HeartRateZoneCalculator: Codable {

    // MARK: - Constants

    /// UserDefaults key used in the App Group shared container.
    static let userDefaultsMaxHRKey = "userMaxHeartRate"

    /// Conservative fallback when no age or manual max HR is available.
    /// 190 BPM errs on the safe side for most adult users.
    static let fallbackMaxHR: Double = 190

    /// Warning threshold as a fraction of max HR (85%).
    static let highIntensityThreshold: Double = 0.85

    // MARK: - Stored Properties

    /// User-supplied age in years. Optional — may be read from HealthKit.
    var age: Int?

    /// Manually overridden max HR (e.g. from a lab test). Takes precedence over the formula.
    var manualMaxHR: Double?

    // MARK: - Computed Properties

    /// Effective max HR: manual override → Tanaka formula → fallback.
    var estimatedMaxHR: Double {
        if let manual = manualMaxHR, manual > 0 {
            return manual
        }
        if let age = age, age > 0 {
            return 208.0 - (0.7 * Double(age))
        }
        return Self.fallbackMaxHR
    }

    /// True when no age or manual max HR is available and we are using the fallback value.
    var isUsingFallback: Bool {
        manualMaxHR == nil && age == nil
    }

    // MARK: - Zone Lookup

    /// Returns the zone number (1–5) for a given heart rate.
    /// Returns 0 when the heart rate is zero or negative.
    func zone(for heartRate: Double) -> Int {
        guard heartRate > 0 else { return 0 }
        let pct = heartRate / estimatedMaxHR
        switch pct {
        case ..<0.60: return 1
        case 0.60..<0.70: return 2
        case 0.70..<0.80: return 3
        case 0.80..<0.90: return 4
        default: return 5
        }
    }

    /// Returns a human-readable zone name for a given heart rate.
    func zoneName(for heartRate: Double) -> String {
        switch zone(for: heartRate) {
        case 1: return "Zone 1 Easy"
        case 2: return "Zone 2 Fat Burn"
        case 3: return "Zone 3 Cardio"
        case 4: return "Zone 4 Hard"
        case 5: return "Zone 5 Peak"
        default: return ""
        }
    }

    /// Returns the BPM boundaries for each zone, calculated from `estimatedMaxHR`.
    /// Useful for displaying zone charts and tooltips.
    func zoneBoundaries() -> [(zone: Int, name: String, lower: Int, upper: Int)] {
        let max = estimatedMaxHR
        return [
            (1, "Zone 1 Easy",    Int((max * 0.50).rounded()), Int((max * 0.60).rounded()) - 1),
            (2, "Zone 2 Fat Burn", Int((max * 0.60).rounded()), Int((max * 0.70).rounded()) - 1),
            (3, "Zone 3 Cardio",  Int((max * 0.70).rounded()), Int((max * 0.80).rounded()) - 1),
            (4, "Zone 4 Hard",    Int((max * 0.80).rounded()), Int((max * 0.90).rounded()) - 1),
            (5, "Zone 5 Peak",    Int((max * 0.90).rounded()), Int(max.rounded()))
        ]
    }

    /// Returns `true` when the heart rate exceeds 85% of estimated max HR.
    ///
    /// This is a cardiac safety indicator. A person exercising above this threshold
    /// is working at very high relative intensity — which may be dangerous for older users
    /// if displayed zones do not reflect their actual physiology.
    func isHighIntensityWarning(heartRate: Double) -> Bool {
        guard heartRate > 0 else { return false }
        return heartRate / estimatedMaxHR > Self.highIntensityThreshold
    }

    // MARK: - Persistence

    /// Loads the saved max HR from the App Group UserDefaults.
    static func loadSavedMaxHR() -> Double? {
        guard let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared") else { return nil }
        let value = defaults.double(forKey: userDefaultsMaxHRKey)
        return value > 0 ? value : nil
    }

    /// Persists a max HR value to the App Group UserDefaults so it is shared
    /// between the iOS app, watchOS app, and widgets without requiring HealthKit access.
    ///
    /// Pass 0 or a negative value to clear a manual override (reverts to Tanaka formula / HealthKit age).
    static func saveMaxHR(_ maxHR: Double) {
        guard let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared") else { return }
        if maxHR > 0 {
            defaults.set(maxHR, forKey: userDefaultsMaxHRKey)
        } else {
            defaults.removeObject(forKey: userDefaultsMaxHRKey)
        }
    }

    // MARK: - Factory

    /// Creates a calculator pre-populated from App Group UserDefaults.
    /// Falls back to the fallback max HR when nothing is stored.
    static func fromSharedDefaults(age: Int? = nil) -> HeartRateZoneCalculator {
        let savedMaxHR = loadSavedMaxHR()
        return HeartRateZoneCalculator(age: age, manualMaxHR: savedMaxHR)
    }
}
