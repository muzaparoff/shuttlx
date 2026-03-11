import Foundation
import os.log

enum WatchWidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWidgetDataProvider")

    static func loadSessions() -> [TrainingSession] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.warning("Watch Widget: App Group container not available")
            return []
        }
        let url = containerURL.appendingPathComponent(sessionsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("Watch Widget: No sessions.json found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            logger.info("Watch Widget: Loaded \(sessions.count) sessions")
            return sessions
        } catch {
            logger.error("Watch Widget: Failed to decode sessions: \(error.localizedDescription)")
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

    static func thisWeekSessionCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return loadSessions().filter { $0.startDate >= weekStart }.count
    }
}
