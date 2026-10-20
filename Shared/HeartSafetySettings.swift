import Foundation

/// Which sensor feeds heart rate. Intent only for `.airPods`.
public enum HeartRateSource: String, Codable, Sendable { case best, watch, airPods }

/// Heart limits and alert switches.
///
/// HEALTH DATA RULE: `onBetaBlocker` is medication data. It stays on the phone:
/// never sent to analytics, never written to Health metadata, never synced to the
/// watch. Use `watchPayload(age:)` for anything that leaves the device.
public struct HeartSafetySettings: Codable, Equatable, Sendable {
    /// nil = unanswered. "Not sure" is stored as true.
    public var onBetaBlocker: Bool?
    public var upperLimit: Int?
    /// nil = off.
    public var lowLimit: Int?
    public var alertAboveLimit: Bool
    public var alertBelowLow: Bool
    public var alertSignalLost: Bool
    public var alertNoMotion: Bool
    /// Intent only. unverified: needs device test (no public AirPods HR API in the SDK headers).
    public var useAirPodsHeartRate: Bool
    /// Alert on a rise of >= 40 bpm within 10 s.
    public var alertSuddenJump: Bool
    /// Seconds without heart rate and motion before auto-pause: 30 / 60 / 120.
    public var noMotionSeconds: Int
    /// "Use effort only": 0-10 scale, no heart-rate limit (no upper-limit alerts, no zone word).
    public var effortOnly: Bool
    public var showEffortOnWatch: Bool
    /// Run/walk and cycling auto-switch on the watch.
    public var autoSwitchActivity: Bool
    /// Intent only. unverified: needs device test.
    public var heartRateSource: HeartRateSource
    /// MEDICATION NOTES: phone only, stripped from `watchPayload`.
    public var medicineName: String?
    public var dailyDose: String?

    public init(onBetaBlocker: Bool? = nil, upperLimit: Int? = nil, lowLimit: Int? = nil,
                alertAboveLimit: Bool = true, alertBelowLow: Bool = true,
                alertSignalLost: Bool = true, alertNoMotion: Bool = true,
                useAirPodsHeartRate: Bool = false,
                alertSuddenJump: Bool = true, noMotionSeconds: Int = 60,
                effortOnly: Bool = false, showEffortOnWatch: Bool = true,
                autoSwitchActivity: Bool = true, heartRateSource: HeartRateSource = .best,
                medicineName: String? = nil, dailyDose: String? = nil) {
        self.onBetaBlocker = onBetaBlocker
        self.upperLimit = upperLimit
        self.lowLimit = lowLimit
        self.alertAboveLimit = alertAboveLimit
        self.alertBelowLow = alertBelowLow
        self.alertSignalLost = alertSignalLost
        self.alertNoMotion = alertNoMotion
        self.useAirPodsHeartRate = useAirPodsHeartRate
        self.alertSuddenJump = alertSuddenJump
        self.noMotionSeconds = noMotionSeconds
        self.effortOnly = effortOnly
        self.showEffortOnWatch = showEffortOnWatch
        self.autoSwitchActivity = autoSwitchActivity
        self.heartRateSource = heartRateSource
        self.medicineName = medicineName
        self.dailyDose = dailyDose
    }

    // Tolerant decoding: every key optional so older/newer JSON still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            onBetaBlocker: try c.decodeIfPresent(Bool.self, forKey: .onBetaBlocker),
            upperLimit: try c.decodeIfPresent(Int.self, forKey: .upperLimit),
            lowLimit: try c.decodeIfPresent(Int.self, forKey: .lowLimit),
            alertAboveLimit: try c.decodeIfPresent(Bool.self, forKey: .alertAboveLimit) ?? true,
            alertBelowLow: try c.decodeIfPresent(Bool.self, forKey: .alertBelowLow) ?? true,
            alertSignalLost: try c.decodeIfPresent(Bool.self, forKey: .alertSignalLost) ?? true,
            alertNoMotion: try c.decodeIfPresent(Bool.self, forKey: .alertNoMotion) ?? true,
            useAirPodsHeartRate: try c.decodeIfPresent(Bool.self, forKey: .useAirPodsHeartRate) ?? false,
            alertSuddenJump: try c.decodeIfPresent(Bool.self, forKey: .alertSuddenJump) ?? true,
            noMotionSeconds: try c.decodeIfPresent(Int.self, forKey: .noMotionSeconds) ?? 60,
            effortOnly: try c.decodeIfPresent(Bool.self, forKey: .effortOnly) ?? false,
            showEffortOnWatch: try c.decodeIfPresent(Bool.self, forKey: .showEffortOnWatch) ?? true,
            autoSwitchActivity: try c.decodeIfPresent(Bool.self, forKey: .autoSwitchActivity) ?? true,
            heartRateSource: (try? c.decodeIfPresent(HeartRateSource.self, forKey: .heartRateSource)) ?? .best,
            medicineName: try c.decodeIfPresent(String.self, forKey: .medicineName),
            dailyDose: try c.decodeIfPresent(String.self, forKey: .dailyDose))
    }

    // MARK: Limits

    /// Estimate only: (220 - age), times 0.81 on a beta-blocker. nil without an age.
    public func estimatedUpperLimit(age: Int?) -> Int? {
        guard let age, age > 0 else { return nil }
        let base = Double(220 - age)
        return Int((onBetaBlocker == true ? base * 0.81 : base).rounded())
    }

    /// The user's own limit always wins over the estimate.
    public func effectiveUpperLimit(age: Int?) -> Int? {
        effortOnly ? nil : (upperLimit ?? estimatedUpperLimit(age: age))
    }

    /// Effort 0-10 is always on with a beta-blocker or effort-only mode.
    public var effortAlwaysOn: Bool { onBetaBlocker == true || effortOnly }

    /// EASY < 70% / STEADY < 90% / HARD of the limit. nil when no limit is known.
    public func zoneWord(hr: Int, age: Int? = nil) -> String? {
        guard let limit = effectiveUpperLimit(age: age), limit > 0 else { return nil }
        let ratio = Double(hr) / Double(limit)
        return ratio < 0.7 ? "EASY" : ratio < 0.9 ? "STEADY" : "HARD"
    }

    // MARK: Watch

    /// Resolved numbers + flags only. Medication answer stripped; the limit is the
    /// effective one (own or estimated) so the watch needs no age or medication.
    public func watchPayload(age: Int?) -> HeartSafetySettings {
        var p = self
        p.upperLimit = effectiveUpperLimit(age: age)
        p.onBetaBlocker = nil
        p.useAirPodsHeartRate = false
        p.heartRateSource = .best
        p.medicineName = nil
        p.dailyDose = nil
        p.showEffortOnWatch = showEffortOnWatch || effortAlwaysOn
        return p
    }

    // MARK: Storage (App Group UserDefaults, JSON)

    public static let defaultsKey = "heartSafetySettings"
    private static let suite = "group.com.shuttlx.shared"

    public static func load() -> HeartSafetySettings {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: defaultsKey),
              let s = try? JSONDecoder().decode(HeartSafetySettings.self, from: data)
        else { return HeartSafetySettings() }
        return s
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.suite)?.set(data, forKey: Self.defaultsKey)
    }
}
