import Foundation
import os
import os.log
import ShuttlXShared

enum WidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "WidgetDataProvider")

    /// Cached sessions — stored pre-sorted descending by startDate to avoid re-sorting on every call
    private static let cache = OSAllocatedUnfairLock<(sessions: [SessionHeadline], at: Date)?>(initialState: nil)

    static func loadSessions() -> [SessionHeadline] {
        // Return cache if fresh (within 5 seconds — covers a single timeline build)
        if let hit = cache.withLock({ $0 }), Date().timeIntervalSince(hit.at) < 5 {
            return hit.sessions
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

        var decoded: [SessionHeadline] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                let result = LenientJSON.decodeArray(SessionHeadline.self, from: data)
                if result.wholeFileUndecodable {
                    logger.error("Widget: sessions.json is unreadable")
                } else if result.skipped > 0 {
                    logger.error("Widget: skipped \(result.skipped) unreadable sessions")
                }
                decoded = result.elements
            } catch {
                logger.error("Widget: Failed to read sessions: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("Widget: File coordination error: \(coordinatorError.localizedDescription)")
        }

        // "Fix a part" corrections change a session's calories; the file is read-only here.
        if let edits = loadEdits(in: containerURL) {
            decoded = decoded.map { session in
                guard let e = edits.effective(segments: session.segments, calories: session.caloriesBurned, sessionID: session.id) else { return session }
                var s = session
                s.segments = e.segments
                s.caloriesBurned = e.calories
                return s
            }
        }

        // Sort once at cache time — all callers get a pre-sorted slice
        let sorted = decoded.sorted { $0.startDate > $1.startDate }
        cache.withLock { $0 = (sorted, Date()) }
        return sorted
    }

    private static func loadEdits(in container: URL) -> SegmentEdits? {
        let url = container.appendingPathComponent("segment_overrides.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try SegmentEdits.decode(Data(contentsOf: url)) } catch {
            logger.error("Widget: Failed to read segment overrides: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns sessions sorted descending by startDate (most recent first).
    /// Prefer this over `loadSessions()` when you need ordering.
    static func sortedSessions() -> [SessionHeadline] {
        loadSessions() // already sorted at cache time
    }

    static func lastSession() -> SessionHeadline? {
        sortedSessions().first
    }

    static func todaySession() -> SessionHeadline? {
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
