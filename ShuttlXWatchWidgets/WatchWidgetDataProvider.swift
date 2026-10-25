import Foundation
import os
import os.log
import ShuttlXShared

enum WatchWidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWidgetDataProvider")

    /// Cached sessions to avoid re-decoding JSON multiple times per timeline update
    private static let cache = OSAllocatedUnfairLock<(sessions: [SessionHeadline], at: Date)?>(initialState: nil)

    static func loadSessions() -> [SessionHeadline] {
        // Return cache if fresh (within 5 seconds — covers a single timeline build)
        if let hit = cache.withLock({ $0 }), Date().timeIntervalSince(hit.at) < 5 {
            return hit.sessions
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

        var decoded: [SessionHeadline] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                let result = LenientJSON.decodeArray(SessionHeadline.self, from: data)
                if result.wholeFileUndecodable {
                    logger.error("Watch Widget: sessions.json is unreadable")
                } else if result.skipped > 0 {
                    logger.error("Watch Widget: skipped \(result.skipped) unreadable sessions")
                }
                decoded = result.elements
            } catch {
                logger.error("Watch Widget: Failed to read sessions: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("Watch Widget: File coordination error: \(coordinatorError.localizedDescription)")
        }

        // Sort descending by startDate once at cache time — all callers benefit
        let sorted = decoded.sorted { $0.startDate > $1.startDate }
        cache.withLock { $0 = (sorted, Date()) }
        return sorted
    }

    static func lastSession() -> SessionHeadline? {
        // Cache is pre-sorted descending — first element is the most recent
        loadSessions().first
    }

    static func todaySession() -> SessionHeadline? {
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
