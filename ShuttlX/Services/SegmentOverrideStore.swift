import Foundation
import os.log
import ShuttlXShared

/// User corrections of a session's parts ("Fix a part": type, split, merge). Kept in its own file so
/// `sessions.json` is never mutated. The logic is the pure `SegmentEdits` (ShuttlXShared); `DataManager`
/// applies it once to build `effectiveSessions`. Single writer: main actor only.
@MainActor
final class SegmentOverrideStore: ObservableObject {
    static let shared = SegmentOverrideStore()

    @Published private(set) var edits = SegmentEdits()

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SegmentOverrideStore")
    private let url: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")?
        .appendingPathComponent("segment_overrides.json")

    private init() { load() }

    /// `parts` are the session's current EFFECTIVE parts (what the user is looking at).
    func setType(_ activity: DetectedActivity, partID: UUID, parts: [ActivitySegment], sessionID: UUID) {
        commit(edits.settingType(activity, partID: partID, parts: parts, sessionID: sessionID))
    }

    @discardableResult
    func split(partID: UUID, at date: Date, parts: [ActivitySegment], sessionID: UUID) -> Bool {
        guard let next = edits.splitting(partID: partID, at: date, parts: parts, sessionID: sessionID) else { return false }
        commit(next)
        return true
    }

    @discardableResult
    func merge(partID: UUID, parts: [ActivitySegment], sessionID: UUID) -> Bool {
        guard let next = edits.merging(partID: partID, parts: parts, sessionID: sessionID) else { return false }
        commit(next)
        return true
    }

    private func commit(_ next: SegmentEdits) {
        edits = next
        save()
    }

    private func load() {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            edits = try SegmentEdits.decode(Data(contentsOf: url))
        } catch {
            // Keep the bytes: the next save would otherwise overwrite the user's corrections with an empty file.
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("segment_overrides_corrupt_\(Int(Date().timeIntervalSince1970)).json")
            do { try FileManager.default.copyItem(at: url, to: backup) } catch {
                logger.error("Backup of corrupt overrides failed: \(error.localizedDescription, privacy: .public)")
            }
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        guard let url else { logger.error("App Group container unavailable"); return }
        do {
            try JSONEncoder().encode(edits).write(to: url, options: .atomic)
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
