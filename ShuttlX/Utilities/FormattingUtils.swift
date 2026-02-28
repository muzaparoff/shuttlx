import Foundation

enum FormattingUtils {
    /// "12m 30s" or "1h 05m"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    /// "02:30" or "1:05:30" for timer display
    static func formatTimer(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// "Feb 27, 2:30 PM"
    static func formatSessionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    /// "Feb 27"
    static func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    /// "2.10 km" or "450 m"
    static func formatDistance(_ km: Double) -> String {
        if km < 1.0 { return "\(Int(km * 1000)) m" }
        return String(format: "%.2f km", km)
    }

    /// "5'30\"" pace format
    static func formatPace(_ secondsPerKm: TimeInterval?) -> String {
        guard let pace = secondsPerKm else { return "--'--\"" }
        let m = Int(pace) / 60
        let s = Int(pace) % 60
        return String(format: "%d'%02d\"", m, s)
    }

    /// Accessible time description: "1 hour 5 minutes 30 seconds"
    static func formatTimeAccessible(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 { return "\(h) hour\(h == 1 ? "" : "s") \(m) minutes \(s) seconds" }
        if m > 0 { return "\(m) minutes \(s) seconds" }
        return "\(s) seconds"
    }
}
