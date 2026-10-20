import Foundation

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

    public init(onBetaBlocker: Bool? = nil, upperLimit: Int? = nil, lowLimit: Int? = nil,
                alertAboveLimit: Bool = true, alertBelowLow: Bool = true,
                alertSignalLost: Bool = true, alertNoMotion: Bool = true,
                useAirPodsHeartRate: Bool = false) {
        self.onBetaBlocker = onBetaBlocker
        self.upperLimit = upperLimit
        self.lowLimit = lowLimit
        self.alertAboveLimit = alertAboveLimit
        self.alertBelowLow = alertBelowLow
        self.alertSignalLost = alertSignalLost
        self.alertNoMotion = alertNoMotion
        self.useAirPodsHeartRate = useAirPodsHeartRate
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
            useAirPodsHeartRate: try c.decodeIfPresent(Bool.self, forKey: .useAirPodsHeartRate) ?? false)
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
        upperLimit ?? estimatedUpperLimit(age: age)
    }

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
