import Foundation
import Combine
import os.log
import ShuttlXShared

@MainActor
class TemplateManager: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "TemplateManager")
    private let appGroupIdentifier = "group.com.shuttlx.shared"
    private let fileName = "workout_templates.json"

    private var wipeObserver: AnyCancellable?

    init() {
        loadTemplates()
        wipeObserver = NotificationCenter.default.publisher(for: .localUserDataWiped)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.templates = []
                self?.syncToWatch()
            }
    }

    // MARK: - CRUD

    func save(_ template: WorkoutTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        persistTemplates()
        syncToWatch()
    }

    func delete(_ template: WorkoutTemplate) {
        templates.removeAll { $0.id == template.id }
        persistTemplates()
        syncToWatch()
    }

    func deleteAt(offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        persistTemplates()
        syncToWatch()
    }

    private func syncToWatch() {
        PhoneSyncCoordinator.shared.sendTemplatesToWatch(templates)
    }

    // MARK: - Persistence

    private func loadTemplates() {
        guard let url = templatesFileURL() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = LenientJSON.decodeArray(WorkoutTemplate.self, from: data)
            if decoded.skipped > 0 || decoded.wholeFileUndecodable {
                // The next save rewrites the file without the bad records: keep the original first.
                let backup = try StoreFile.backupCorrupt(url)
                logger.error("workout_templates.json: \(decoded.skipped) unreadable template(s); original kept as \(backup.lastPathComponent)")
            }
            templates = decoded.elements
            logger.info("Loaded \(self.templates.count) template(s)")
        } catch {
            logger.error("Failed to load templates: \(error.localizedDescription)")
        }
    }

    private func persistTemplates() {
        guard let url = templatesFileURL() else { return }

        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: url, options: StoreFile.writeOptions)
            logger.info("Saved \(self.templates.count) template(s)")
        } catch {
            logger.error("Failed to save templates: \(error.localizedDescription)")
        }
    }

    private func templatesFileURL() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL")
            return nil
        }
        return container.appendingPathComponent(fileName)
    }
}
