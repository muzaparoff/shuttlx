import Foundation
import os.log
import ShuttlXShared

/// User corrections of a part's activity ("Fix a part"). Kept in its own file so
/// `sessions.json` is never mutated; the effective type is `override ?? segment.activityType`.
/// Single writer: main actor only.
@MainActor
final class SegmentOverrideStore: ObservableObject {
    static let shared = SegmentOverrideStore()

    @Published private(set) var overrides: [UUID: DetectedActivity] = [:]

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SegmentOverrideStore")
    private let url: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")?
        .appendingPathComponent("segment_overrides.json")

    private init() { load() }

    func effective(for segment: ActivitySegment) -> DetectedActivity {
        overrides[segment.id] ?? segment.activityType
    }

    /// Segments with overrides applied (same ids), for display.
    func applying(to segments: [ActivitySegment]) -> [ActivitySegment] {
        segments.map { seg in
            guard let o = overrides[seg.id], o != seg.activityType else { return seg }
            var copy = seg
            copy.activityType = o
            return copy
        }
    }

    func set(_ activity: DetectedActivity, for segment: ActivitySegment) {
        if activity == segment.activityType {
            overrides.removeValue(forKey: segment.id)
        } else {
            overrides[segment.id] = activity
        }
        save()
    }

    private func load() {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let raw = try JSONDecoder().decode([String: DetectedActivity].self, from: Data(contentsOf: url))
            overrides = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
        } catch {
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        guard let url else { logger.error("App Group container unavailable"); return }
        do {
            let raw = Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.uuidString, $0.value) })
            try JSONEncoder().encode(raw).write(to: url, options: .atomic)
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
