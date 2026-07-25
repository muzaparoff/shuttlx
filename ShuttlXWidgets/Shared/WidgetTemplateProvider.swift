import Foundation
import os.log

/// Reads `workout_templates.json` from the App Group container for widget
/// use (W1 Start Training configuration picker + tap-to-start resolution).
///
/// This intentionally does NOT reuse `ShuttlX/Services/WidgetDataProvider.swift`
/// — that file already handles `sessions.json` and is out of scope for this
/// change; this provider is self-contained within the ShuttlXWidgets target
/// but mirrors its `NSFileCoordinator` decode pattern exactly.
enum WidgetTemplateProvider {
    private static let appGroupIdentifier = "group.com.shuttlx.shared"
    private static let templatesFileName = "workout_templates.json"
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "WidgetTemplateProvider")

    static func loadTemplates() -> [WorkoutTemplate] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.warning("Widget: App Group container not available")
            return []
        }
        let url = containerURL.appendingPathComponent(templatesFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("Widget: No workout_templates.json found")
            return []
        }

        var decoded: [WorkoutTemplate] = []
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            do {
                let data = try Data(contentsOf: readURL)
                decoded = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
            } catch {
                logger.error("Widget: Failed to decode templates: \(error.localizedDescription)")
            }
        }
        if let coordinatorError {
            logger.error("Widget: File coordination error: \(coordinatorError.localizedDescription)")
        }
        return decoded
    }

    static func template(withID id: UUID) -> WorkoutTemplate? {
        loadTemplates().first { $0.id == id }
    }
}
