import Foundation

/// Every heart-limit number in ONE place. Pure Foundation so `swift test` covers it.
///
/// The estimated upper limit is NOT a prescription. It is a conservative default for people who do not
/// have a limit from their doctor: 85 % of the age-predicted maximum (220 - age), lowered by a further
/// 19 % on a beta-blocker (the existing 0.81 factor). Owner decision, October 2026. The table of results
/// is pinned in `HeartLimitsTests.testEstimateTable` and needs clinical sign-off before release.
public enum HeartLimits {
    /// Age-predicted maximum heart rate = `predictedMaxBase - age`.
    public static let predictedMaxBase = 220
    /// The estimated limit is this share of the predicted maximum.
    public static let estimateFraction = 0.85
    /// Extra factor on the predicted maximum for beta-blocker users ("yes" and "not sure").
    public static let betaBlockerFactor = 0.81

    /// Accepted range for a typed upper limit, in bpm.
    public static let upperRange = 60...220
    /// Lowest accepted low limit, in bpm.
    public static let lowMin = 30
    /// The low limit must stay at least this far below the upper limit.
    public static let lowGap = 10
    /// Accepted range for an age typed by the user, in years.
    public static let ageRange = 10...110
    /// Accepted range for a typed maximum heart rate, in bpm.
    public static let maxHRRange = 100...230
    /// Accepted range for a typed body weight, in kg.
    public static let weightRange = 20.0...300.0

    // MARK: Estimate

    /// 220 - age, or nil when the age is missing or outside `ageRange`.
    public static func predictedMax(age: Int?) -> Int? {
        guard let age, ageRange.contains(age) else { return nil }
        return predictedMaxBase - age
    }

    /// round(estimateFraction * predictedMax [* betaBlockerFactor]); nil without a valid age.
    public static func estimate(age: Int?, betaBlocker: Bool?) -> Int? {
        guard let predicted = predictedMax(age: age) else { return nil }
        let adjusted = Double(predicted) * (betaBlocker == true ? betaBlockerFactor : 1)
        return Int((adjusted * estimateFraction).rounded())
    }

    /// Allowed low limits for the given upper limit (own or estimated; nil = unknown).
    public static func lowRange(upper: Int?) -> ClosedRange<Int> {
        let top = (upper ?? upperRange.upperBound) - lowGap
        return lowMin...max(lowMin, top)
    }

    // MARK: Typed input

    public enum Commit: Equatable {
        /// Empty text: the value is cleared.
        case cleared
        /// A number. `clamped` is true when it was outside the range and moved to the nearest bound.
        case set(Int, clamped: Bool)
        /// Not a number: keep the old value and tell the user.
        case rejected
    }

    /// Interprets text typed into a number field when the user finishes editing (blur or submit).
    /// Out-of-range numbers are clamped to the nearest bound; text that is not a whole number is rejected.
    public static func commit(_ text: String, range: ClosedRange<Int>) -> Commit {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .cleared }
        guard let v = Int(t) else { return .rejected }
        let c = min(max(v, range.lowerBound), range.upperBound)
        return .set(c, clamped: c != v)
    }

    /// "1,5" and "1.5" both parse; anything else is nil.
    public static func decimal(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty, let v = Double(t), v.isFinite else { return nil }
        return v
    }

    // MARK: Age from date of birth

    /// Whole years on `now`, honouring the birthday. Nil outside `ageRange`.
    public static func age(birthYear: Int, birthMonth: Int?, birthDay: Int?, now: Date,
                           calendar: Calendar = .current) -> Int? {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        guard let y = c.year else { return nil }
        var age = y - birthYear
        if let bm = birthMonth, let bd = birthDay, let m = c.month, let d = c.day, (m, d) < (bm, bd) { age -= 1 }
        return ageRange.contains(age) ? age : nil
    }

    // MARK: Watch alert freshness

    /// A heart alert is shown only if it is at most 60 s old and not from the future. A clock a few seconds
    /// ahead of this phone is tolerated; more than `futureTolerance` is rejected.
    public static let futureTolerance: TimeInterval = 5
    public static func isFreshAlert(ts: TimeInterval, now: TimeInterval) -> Bool {
        let age = now - ts
        return age <= 60 && age >= -futureTolerance
    }
}
