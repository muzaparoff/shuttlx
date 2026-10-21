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
    /// Alert on a rise of >= 40 bpm within 10 s. Off by default: it can false-alarm (October 2026).
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
    /// Saved-data version. 0 = saved before versioning (sudden jump was on by default); see `currentVersion`.
    public var settingsVersion: Int

    /// 1: sudden-jump default changed from on to off; older saved settings are migrated once on decode.
    public static let currentVersion = 1

    public init(onBetaBlocker: Bool? = nil, upperLimit: Int? = nil, lowLimit: Int? = nil,
                alertAboveLimit: Bool = true, alertBelowLow: Bool = true,
                alertSignalLost: Bool = true, alertNoMotion: Bool = true,
                useAirPodsHeartRate: Bool = false,
                alertSuddenJump: Bool = false, noMotionSeconds: Int = 60,
                effortOnly: Bool = false, showEffortOnWatch: Bool = true,
                autoSwitchActivity: Bool = true, heartRateSource: HeartRateSource = .best,
                medicineName: String? = nil, dailyDose: String? = nil,
                settingsVersion: Int = HeartSafetySettings.currentVersion) {
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
        self.settingsVersion = settingsVersion
    }

    // Tolerant decoding: every key optional so older/newer JSON still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // One-time migration: settings saved before versioning had sudden jump ON by default. The user never
        // chose that, so it becomes OFF; a later explicit choice is saved with the new version and kept.
        let saved = try c.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 0
        self.init(
            onBetaBlocker: try c.decodeIfPresent(Bool.self, forKey: .onBetaBlocker),
            upperLimit: try c.decodeIfPresent(Int.self, forKey: .upperLimit),
            lowLimit: try c.decodeIfPresent(Int.self, forKey: .lowLimit),
            alertAboveLimit: try c.decodeIfPresent(Bool.self, forKey: .alertAboveLimit) ?? true,
            alertBelowLow: try c.decodeIfPresent(Bool.self, forKey: .alertBelowLow) ?? true,
            alertSignalLost: try c.decodeIfPresent(Bool.self, forKey: .alertSignalLost) ?? true,
            alertNoMotion: try c.decodeIfPresent(Bool.self, forKey: .alertNoMotion) ?? true,
            useAirPodsHeartRate: try c.decodeIfPresent(Bool.self, forKey: .useAirPodsHeartRate) ?? false,
            alertSuddenJump: saved < 1 ? false : (try c.decodeIfPresent(Bool.self, forKey: .alertSuddenJump) ?? false),
            noMotionSeconds: try c.decodeIfPresent(Int.self, forKey: .noMotionSeconds) ?? 60,
            effortOnly: try c.decodeIfPresent(Bool.self, forKey: .effortOnly) ?? false,
            showEffortOnWatch: try c.decodeIfPresent(Bool.self, forKey: .showEffortOnWatch) ?? true,
            autoSwitchActivity: try c.decodeIfPresent(Bool.self, forKey: .autoSwitchActivity) ?? true,
            heartRateSource: (try? c.decodeIfPresent(HeartRateSource.self, forKey: .heartRateSource)) ?? .best,
            medicineName: try c.decodeIfPresent(String.self, forKey: .medicineName),
            dailyDose: try c.decodeIfPresent(String.self, forKey: .dailyDose),
            settingsVersion: max(saved, Self.currentVersion))
    }

    // MARK: Limits

    /// Estimate only, see `HeartLimits`: 85 % of (220 - age), times 0.81 on a beta-blocker. nil without a valid age.
    public func estimatedUpperLimit(age: Int?) -> Int? {
        HeartLimits.estimate(age: age, betaBlocker: onBetaBlocker)
    }

    /// True when no upper limit is in force and the user did not choose "effort only".
    public func hasNoLimit(age: Int?) -> Bool {
        !effortOnly && effectiveUpperLimit(age: age) == nil
    }

    /// The user's own limit always wins over the estimate.
    public func effectiveUpperLimit(age: Int?) -> Int? {
        effortOnly ? nil : (upperLimit ?? estimatedUpperLimit(age: age))
    }

    /// The low limit moved into the range allowed under the RESOLVED upper limit (own or estimated), or nil if
    /// off. The watch applies the same range, so a low limit above it would be dropped there while the phone
    /// still showed it.
    public func clampedLowLimit(age: Int?) -> Int? {
        guard let low = lowLimit else { return nil }
        let r = HeartLimits.lowRange(upper: effectiveUpperLimit(age: age))
        return min(max(low, r.lowerBound), r.upperBound)
    }

    /// Moves a low limit that no longer fits (the age or Health date of birth changed the estimated upper
    /// limit) into range. Returns the note to show on the phone, or nil when nothing changed.
    public mutating func reconcileLowLimit(age: Int?) -> String? {
        guard let low = lowLimit, let fixed = clampedLowLimit(age: age), fixed != low else { return nil }
        lowLimit = fixed
        return "Low limit changed to \(fixed) bpm to stay \(HeartLimits.lowGap) below the upper limit."
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
        p.lowLimit = clampedLowLimit(age: age)
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

    /// Settings without the medication notes (see `loadForEditing`). Cheap enough for per-update use.
    /// An older build saved the notes inside this JSON: they are moved to `MedicineVault` once, here.
    public static func load() -> HeartSafetySettings {
        let defaults = UserDefaults(suiteName: suite)
        guard let data = defaults?.data(forKey: defaultsKey),
              var s = try? JSONDecoder().decode(HeartSafetySettings.self, from: data)
        else { return HeartSafetySettings() }
        if s.medicineName != nil || s.dailyDose != nil {
            // A value leaves the JSON only once the Keychain really holds it; otherwise the legacy copy stays
            // there and the move is retried on the next load.
            var left = s
            if let n = s.medicineName, MedicineVault.name != nil || MedicineVault.store("name", n) { left.medicineName = nil }
            if let d = s.dailyDose, MedicineVault.dose != nil || MedicineVault.store("dose", d) { left.dailyDose = nil }
            if left != s, let data = try? JSONEncoder().encode(left) {
                UserDefaults(suiteName: suite)?.set(data, forKey: defaultsKey)
            }
            s.medicineName = nil   // callers of load() never see the notes
            s.dailyDose = nil
        }
        return s.sanitized()
    }

    /// `load()` plus the medicine name and dose from the vault. Only screens that edit them need this.
    public static func loadForEditing() -> HeartSafetySettings {
        var s = load()
        s.medicineName = MedicineVault.name
        s.dailyDose = MedicineVault.dose
        return s
    }

    /// Drops saved limits outside the accepted ranges (older builds saved every keystroke, e.g. "1" or "12").
    public func sanitized() -> HeartSafetySettings {
        var s = self
        if let u = s.upperLimit, !HeartLimits.upperRange.contains(u) { s.upperLimit = nil }
        if let l = s.lowLimit {
            let r = HeartLimits.lowRange(upper: s.upperLimit)
            s.lowLimit = min(max(l, r.lowerBound), r.upperBound)
        }
        return s
    }

    /// Writes everything except the medication notes (they never go into UserDefaults). A legacy note that
    /// could not be moved to the vault yet (`load()`) stays in the JSON until it can be.
    public func save() { write(keepPendingLegacy: true) }

    private func write(keepPendingLegacy: Bool) {
        var stripped = self
        stripped.medicineName = nil
        stripped.dailyDose = nil
        let defaults = UserDefaults(suiteName: Self.suite)
        if keepPendingLegacy, let old = defaults?.data(forKey: Self.defaultsKey),
           let prev = try? JSONDecoder().decode(HeartSafetySettings.self, from: old) {
            if MedicineVault.name == nil { stripped.medicineName = prev.medicineName }
            if MedicineVault.dose == nil { stripped.dailyDose = prev.dailyDose }
        }
        guard let data = try? JSONEncoder().encode(stripped) else { return }
        defaults?.set(data, forKey: Self.defaultsKey)
    }

    /// `save()` plus the medicine name and dose into the vault. Use only with a value from `loadForEditing()`.
    public func saveForEditing() {
        let nameOK = MedicineVault.backend.write("name", medicineName)
        let doseOK = MedicineVault.backend.write("dose", dailyDose)
        write(keepPendingLegacy: !(nameOK && doseOK))
    }
}
