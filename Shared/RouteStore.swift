import Foundation
import os.log

/// One `[RoutePoint]` file per session (`<uuid>.json`) in a directory (`routes/` in the App Group).
/// iOS `DataManager` is the only writer (plan 2026-10 part B).
public struct RouteStore: Sendable {
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

    /// Route files whose session is not in `keeping` and that were last written before `cutoff`. The age guard
    /// keeps a file whose session is still on its way in (inbox, a save not yet finished).
    public func orphans(keeping: Set<UUID>, writtenBefore cutoff: Date) -> Set<UUID> {
        storedIDs().subtracting(keeping).filter { id in
            let date = (try? file(id).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return (date ?? .distantPast) < cutoff
        }
    }
}

/// Moving routes out of `sessions.json` into `RouteStore` files (plan 2026-10 part B, 4.2-4.3). Pure file logic,
/// so `swift test` covers the crash cases; `DataManager` runs it on its store queue.
public enum RouteExternalize {
    /// Takes the inline route out of `session` and fills its summary. Returns the points (nil when it had none).
    public static func strip(_ session: inout TrainingSession) -> [RoutePoint]? {
        guard let route = session.inlineRoute else { return nil }
        session.inlineRoute = nil
        guard !route.isEmpty else { return nil }
        session.routeSummary = RouteSummary(points: route)
        return route
    }

    /// The copy of a stored session to upload (CloudKit keeps whole sessions, route inline): `route` is what
    /// `DataManager.route(for:)` returned. nil = skip it this time: it has a route that could not be read, and an
    /// upload without it would replace the route in iCloud.
    public static func forUpload(_ session: TrainingSession, route: [RoutePoint]?) -> TrainingSession? {
        guard session.inlineRoute == nil, session.routeSummary != nil else { return session }
        guard let route, !route.isEmpty else { return nil }
        var s = session
        s.inlineRoute = route
        return s
    }

    public struct SaveResult: Equatable {
        /// Route files written by this save: their pending entries can be dropped.
        public var written: Set<UUID> = []
        /// Route writes that failed: those sessions went into sessions.json with their route inline.
        public var keptInline: Set<UUID> = []
        public var backupMade = false
        public init() {}
    }

    /// One save, in the order that never loses a route:
    /// 1. once, before the first save that moves routes out: copy sessions.json to `backupURL` (if it exists and
    ///    the copy is not there yet). If the copy fails, nothing moves out in this save.
    /// 2. write each pending route of a session in `sessions` to its file;
    /// 3. write `sessions` to `sessionsURL`, with the route inline for every session whose file write failed.
    /// A crash before 3 leaves the old sessions.json (routes still inline) and some route files; the next run
    /// rewrites the same files. `inlineEverything` (the "Put routes back into history" action) writes every
    /// route inline (from `pendingRoutes`, else the file) and touches no route file.
    /// Throws when the sessions.json write fails; the old file is then unchanged.
    public static func save(_ sessions: [TrainingSession],
                            pendingRoutes: [UUID: [RoutePoint]],
                            store: RouteStore,
                            sessionsURL: URL,
                            backupURL: URL?,
                            inlineEverything: Bool = false,
                            writeRoute: (([RoutePoint], UUID) throws -> Void)? = nil,
                            writeSessions: (Data, URL) throws -> Void = { try $0.write(to: $1, options: StoreFile.writeOptions) },
                            beforeSessionsWrite: () -> Void = {}) throws -> SaveResult {
        var result = SaveResult()
        var snapshot = sessions
        if inlineEverything {
            for i in snapshot.indices where snapshot[i].inlineRoute == nil {
                snapshot[i].inlineRoute = pendingRoutes[snapshot[i].id] ?? (snapshot[i].routeSummary != nil ? store.read(id: snapshot[i].id) : nil)
            }
        } else {
            let ids = Set(sessions.map(\.id))
            let toWrite = pendingRoutes.filter { ids.contains($0.key) }
            var canMove = true
            if let backupURL, !toWrite.isEmpty,
               !FileManager.default.fileExists(atPath: backupURL.path), FileManager.default.fileExists(atPath: sessionsURL.path) {
                do {
                    try FileManager.default.copyItem(at: sessionsURL, to: backupURL)
                    result.backupMade = true
                } catch {
                    canMove = false
                }
            }
            let write = writeRoute ?? { try store.write($0, id: $1) }
            for (id, points) in toWrite {
                if canMove, (try? write(points, id)) != nil { result.written.insert(id) } else { result.keptInline.insert(id) }
            }
            for i in snapshot.indices {
                if result.keptInline.contains(snapshot[i].id) { snapshot[i].inlineRoute = toWrite[snapshot[i].id] }
            }
        }
        let data = try JSONEncoder().encode(snapshot)
        beforeSessionsWrite()
        try writeSessions(data, sessionsURL)
        return result
    }
}
