import Foundation
import os.log

enum WidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "WidgetDataProvider")

    static func loadSessions() -> [TrainingSession] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.warning("Widget: App Group container not available")
            return []
        }
        let url = containerURL.appendingPathComponent(sessionsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("Widget: No sessions.json found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            logger.info("Widget: Loaded \(sessions.count) sessions")
            return sessions
        } catch {
            logger.error("Widget: Failed to decode sessions: \(error.localizedDescription)")
            return []
        }
    }

    static func lastSession() -> TrainingSession? {
        loadSessions()
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    static func todaySession() -> TrainingSession? {
        let cal = Calendar.current
        return loadSessions()
            .filter { cal.isDateInToday($0.startDate) }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func thisWeekSessionCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return loadSessions().filter { $0.startDate >= weekStart }.count
    }

    static func currentStreak() -> Int {
        let calendar = Calendar.current
        let sessions = loadSessions()
        guard !sessions.isEmpty else { return 0 }

        let workoutDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // If no workout today, start checking from yesterday
        if !workoutDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }

        return streak
    }
}
