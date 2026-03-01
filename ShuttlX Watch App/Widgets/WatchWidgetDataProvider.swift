import Foundation

enum WatchWidgetDataProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let sessionsFileName = "sessions.json"

    static func loadSessions() -> [TrainingSession] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return []
        }
        let url = containerURL.appendingPathComponent(sessionsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TrainingSession].self, from: data)
        } catch {
            return []
        }
    }

    static func lastSession() -> TrainingSession? {
        loadSessions()
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
