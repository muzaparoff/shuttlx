import Foundation

/// "Under your limit N% of the time" for the session detail. Pure so it can be tested.
public enum LimitVerdict {
    /// Share of the heart-rate readings at or under `limit`, rounded DOWN so one reading above never reads as 100%.
    /// nil without readings or with a limit that is not positive.
    public static func percentUnder(_ bpm: [Double], limit: Int) -> Int? {
        guard limit > 0 else { return nil }
        let valid = bpm.filter { $0.isFinite && $0 > 0 }
        guard !valid.isEmpty else { return nil }
        let under = valid.filter { $0 <= Double(limit) }.count
        return under * 100 / valid.count
    }
}
