import Foundation
import os.log

enum WidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "WidgetDataProvider")

    /// Cached sessions — stored pre-sorted descending by startDate to avoid re-sorting on every call
    private static var cachedSessions: [TrainingSession]?
    private static var cacheTimestamp: Date?

    static func loadSessions() -> [TrainingSession] {
        // Return cache if fresh (within 5 seconds — covers a single timeline build)
        if let cached = cachedSessions, let ts = cacheTimestamp, Date().timeIntervalSince(ts) < 5 {
            return cached
        }

        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.warning("Widget: App Group container not available")
            return []
        }
        let url = containerURL.appendingPathComponent(sessionsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("Widget: No sessions.json found")
            return []
        }

        var decoded: [TrainingSession] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                decoded = try JSONDecoder().decode([TrainingSession].self, from: data)
            } catch {
                logger.error("Widget: Failed to decode sessions: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("Widget: File coordination error: \(coordinatorError.localizedDescription)")
        }

        // Sort once at cache time — all callers get a pre-sorted slice
        cachedSessions = decoded.sorted { $0.startDate > $1.startDate }
        cacheTimestamp = Date()
        return cachedSessions ?? []
    }

    /// Returns sessions sorted descending by startDate (most recent first).
    /// Prefer this over `loadSessions()` when you need ordering.
    static func sortedSessions() -> [TrainingSession] {
        loadSessions() // already sorted at cache time
    }

    static func lastSession() -> TrainingSession? {
        sortedSessions().first
    }

    static func todaySession() -> TrainingSession? {
        let cal = Calendar.current
        return sortedSessions()
            .first { cal.isDateInToday($0.startDate) }
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    static func thisWeekSessionCount() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return sortedSessions().filter { $0.startDate >= weekStart }.count
    }

    static func currentStreak() -> Int {
        let calendar = Calendar.current
        let sessions = sortedSessions()
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
