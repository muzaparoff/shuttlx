import Foundation

/// Distance unit for display. Data stays in kilometres; only the display converts.
/// App Group key `distanceUnit`: "km" | "mi" | absent (= follow the region).
public enum DistanceUnit: String, Sendable {
    case km, mi

    public static let storageKey = "distanceUnit"
    public static let kmPerMile = 1.609344

    /// Pure rule: a stored "km"/"mi" wins, anything else follows the region (US, UK -> miles).
    public static func resolve(stored: String?, locale: Locale = .current) -> DistanceUnit {
        if let stored, let unit = DistanceUnit(rawValue: stored) { return unit }
        // usesMetricSystem is false for US (and LR, MM); the UK is metric in Foundation but runs on miles.
        return (!locale.usesMetricSystem || locale.regionCode == "GB") ? .mi : .km
    }

    public static var current: DistanceUnit {
        resolve(stored: UserDefaults(suiteName: "group.com.shuttlx.shared")?.string(forKey: storageKey))
    }

    /// "km" / "mi"
    public var symbol: String { rawValue }
    public var paceSuffix: String { "/" + rawValue }
    public var name: String { self == .km ? "kilometre" : "mile" }
    /// Kilometres in one unit.
    public var km: Double { self == .km ? 1 : Self.kmPerMile }
    public func value(fromKm km: Double) -> Double { km / self.km }
}

/// One line of the Splits card: a whole km/mile, or the partial last one.
public struct SplitRow: Equatable, Sendable {
    public let number: Int
    public let time: TimeInterval
    /// 1 for a full split, less for the partial last one (in the chosen unit).
    public let distance: Double
    public var isPartial: Bool { distance < 1 }
    /// Seconds per chosen unit.
    public var pace: TimeInterval { distance > 0 ? time / distance : 0 }
}

public enum FormattingUtils {
    /// Splits in the chosen unit from the stored per-km split times (`splitTimes[i]` = time of km i+1).
    /// Km: as stored. Miles: cumulative time is interpolated linearly inside each km (an estimate).
    /// A partial last split is added when `totalKm`/`totalDuration` leave at least 0.1 of the unit.
    public static func splitRows(splitTimes: [TimeInterval], totalKm: Double?, totalDuration: TimeInterval,
                                 unit: DistanceUnit) -> [SplitRow] {
        guard !splitTimes.isEmpty else { return [] }
        var cumulative: [TimeInterval] = []   // cumulative[i] = time at km i+1
        var run = 0.0
        for t in splitTimes { run += max(0, t); cumulative.append(run) }
        let knownKm = Double(splitTimes.count)
        let endKm = max(knownKm, totalKm ?? knownKm)
        let endTime = max(run, totalDuration)

        func timeAt(_ km: Double) -> TimeInterval {
            if km <= 0 { return 0 }
            if km >= endKm { return endTime }
            if km >= knownKm {   // past the last full km: spread the remaining time evenly
                return run + (endTime - run) * (km - knownKm) / (endKm - knownKm)
            }
            let i = Int(km.rounded(.down))
            let lower = i == 0 ? 0 : cumulative[i - 1]
            return lower + (cumulative[i] - lower) * (km - Double(i))
        }

        var rows: [SplitRow] = []
        let wholeUnits = Int((endKm / unit.km + 1e-9).rounded(.down))
        if wholeUnits > 0 {
            for n in 1...wholeUnits {
                let a = timeAt(Double(n - 1) * unit.km), b = timeAt(Double(n) * unit.km)
                rows.append(SplitRow(number: n, time: b - a, distance: 1))
            }
        }
        // Partial tail: the distance left after the last whole split (needs at least a tenth of the unit).
        let tailUnits = endKm / unit.km - Double(wholeUnits)
        let tailTime = endTime - timeAt(Double(wholeUnits) * unit.km)
        if tailUnits >= 0.1, tailTime > 0 {
            rows.append(SplitRow(number: wholeUnits + 1, time: tailTime, distance: tailUnits))
        }
        return rows
    }

    /// "12m 30s" or "1h 05m"
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    /// "02:30" or "1:05:30" for timer display
    public static func formatTimer(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // Cached formatters to avoid repeated allocation
    private static let sessionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "Feb 27, 2:30 PM"
    public static func formatSessionDate(_ date: Date) -> String {
        sessionDateFormatter.string(from: date)
    }

    /// "Feb 27"
    public static func formatShortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// "2.10 km" or "450 m"
    public static func formatDistance(_ km: Double) -> String {
        if km < 1.0 { return "\(Int(km * 1000)) m" }
        return String(format: "%.2f km", km)
    }

    /// Unit-aware distance: "2.10 km" / "1.30 mi"; "450 m" for under 1 km.
    public static func formatDistance(_ km: Double, unit: DistanceUnit) -> String {
        if unit == .km { return formatDistance(km) }
        return String(format: "%.2f mi", unit.value(fromKm: km))
    }

    /// One decimal, number only ("3.4"), for stat tiles that carry their own unit label.
    public static func formatDistanceValue(_ km: Double, unit: DistanceUnit) -> String {
        String(format: "%.1f", unit.value(fromKm: km))
    }

    /// Pace per chosen unit from seconds per km: "9'40\"" for 6'00"/km in miles.
    public static func formatPace(_ secondsPerKm: TimeInterval?, unit: DistanceUnit) -> String {
        formatPace(secondsPerKm.map { $0 * unit.km })
    }

    /// Pace with its suffix: "5'30\"/km".
    public static func formatPaceWithUnit(_ secondsPerKm: TimeInterval?, unit: DistanceUnit) -> String {
        formatPace(secondsPerKm, unit: unit) + unit.paceSuffix
    }

    /// Speed in km/h or mph, one decimal ("18.4 km/h").
    public static func formatSpeed(metersPerSecond: Double, unit: DistanceUnit) -> String {
        let perHour = metersPerSecond * 3.6 / unit.km
        return String(format: "%.1f ", perHour) + (unit == .km ? "km/h" : "mph")
    }

    /// "5'30\"" pace format
    public static func formatPace(_ secondsPerKm: TimeInterval?) -> String {
        guard let pace = secondsPerKm else { return "--'--\"" }
        let m = Int(pace) / 60
        let s = Int(pace) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    /// Accessible time description: "1 hour 5 minutes 30 seconds"
    public static func formatTimeAccessible(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 { return "\(h) hour\(h == 1 ? "" : "s") \(m) minutes \(s) seconds" }
        if m > 0 { return "\(m) minutes \(s) seconds" }
        return "\(s) seconds"
    }
}
