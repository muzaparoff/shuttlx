import Foundation

/// Active minutes in the calendar week that contains `date` (Today ring, "N of 150 min").
/// A session counts in the week it started. `duration` is active time (the watch leaves pauses out).
/// Imported Health sessions count like any other.
public enum WeekMinutes {
    public static let goal = 150

    public static func total(of sessions: [TrainingSession], weekOf date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let seconds = sessions.filter { week.contains($0.startDate) }.reduce(0) { $0 + max(0, $1.duration) }
        return Int(seconds / 60)
    }
}
