import Foundation
import os.log

enum WatchWidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWidgetDataProvider")

    /// Cached sessions to avoid re-decoding JSON multiple times per timeline update
    private static var cachedSessions: [TrainingSession]?
    private static var cacheTimestamp: Date?

    static func loadSessions() -> [TrainingSession] {
        // Return cache if fresh (within 5 seconds — covers a single timeline build)
        if let cached = cachedSessions, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < 5 {
            return cached
        }

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
            // Sort descending by startDate once at cache time — all callers benefit
            cachedSessions = sessions.sorted { $0.startDate > $1.startDate }
            cacheTimestamp = Date()
            return cachedSessions!
        } catch {
            logger.error("Watch Widget: Failed to decode sessions: \(error.localizedDescription)")
            return []
        }
    }

    static func lastSession() -> TrainingSession? {
        // Cache is pre-sorted descending — first element is the most recent
        loadSessions().first
    }

    static func todaySession() -> TrainingSession? {
        let cal = Calendar.current
        // Cache is pre-sorted descending — first match is the most recent today session
        return loadSessions().first { cal.isDateInToday($0.startDate) }
    }

    static func thisWeekSessionCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return loadSessions().filter { $0.startDate >= weekStart }.count
    }
}
