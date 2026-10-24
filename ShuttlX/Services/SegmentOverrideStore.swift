import Foundation
import os.log
import WidgetKit
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

    /// Drops this session's corrections (`rawSegmentIDs` = ids of the RECORDED segments in sessions.json).
    func reset(sessionID: UUID, rawSegmentIDs: [UUID]) {
        commit(edits.resetting(sessionID: sessionID, rawSegmentIDs: rawSegmentIDs))
    }

    /// Wipe: forget every correction (the file is removed by `DataManager.wipeLocalUserData`).
    func wipe() { edits = SegmentEdits() }

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
            do { try StoreFile.backupCorrupt(url) } catch {
                logger.error("Backup of corrupt overrides failed: \(error.localizedDescription, privacy: .public)")
            }
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        guard let url else { logger.error("App Group container unavailable"); return }
        do {
            try JSONEncoder().encode(edits).write(to: url, options: StoreFile.writeOptions)
            WidgetCenter.shared.reloadAllTimelines()   // widgets apply the corrections too
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
