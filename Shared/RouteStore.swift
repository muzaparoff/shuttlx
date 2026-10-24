import Foundation
import os.log

/// One `[RoutePoint]` file per session (`<uuid>.json`) in a directory (`routes/` in the App Group).
/// Plan 2026-10 part B, 4.1. Not used yet; `DataManager` becomes its only writer in B3.
public struct RouteStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "RouteStore")

    private func file(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    /// Atomic, readable after first unlock. Throws so the caller can keep the route inline when it fails.
    public func write(_ points: [RoutePoint], id: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(points).write(to: file(id), options: StoreFile.writeOptions)
    }

    /// nil when the file is missing or unreadable.
    public func read(id: UUID) -> [RoutePoint]? {
        guard let data = try? Data(contentsOf: file(id)) else { return nil }
        do { return try JSONDecoder().decode([RoutePoint].self, from: data) } catch {
            Self.logger.error("Unreadable route file \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func remove(ids: Set<UUID>) {
        for id in ids { try? FileManager.default.removeItem(at: file(id)) }
    }

    /// Ids of the route files present (other files are ignored).
    public func storedIDs() -> Set<UUID> {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return Set(files.filter { $0.pathExtension == "json" }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) })
    }
}
