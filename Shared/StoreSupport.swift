import Foundation

/// Helpers for the App Group JSON stores: lenient decoding, corrupt-file backups, file protection.
/// Pure Foundation so `swift test` covers them.

public enum LenientJSON {
    public struct Decoded<T> {
        public var elements: [T]
        /// Elements that were present but did not decode.
        public var skipped: Int
        /// True when nothing could be read: not a JSON array, or every element failed. The caller must
        /// keep the file, back it up and refuse to overwrite it.
        public var wholeFileUndecodable: Bool
        public init(elements: [T] = [], skipped: Int = 0, wholeFileUndecodable: Bool = false) {
            self.elements = elements
            self.skipped = skipped
            self.wholeFileUndecodable = wholeFileUndecodable
        }
    }

    private struct Slot<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    /// Decodes a JSON array element by element, so one bad record cannot cost the whole history.
    public static func decodeArray<T: Decodable>(_ type: T.Type, from data: Data,
                                                 decoder: JSONDecoder = JSONDecoder()) -> Decoded<T> {
        guard let slots = try? decoder.decode([Slot<T>].self, from: data) else {
            return Decoded(wholeFileUndecodable: true)
        }
        let good = slots.compactMap(\.value)
        let skipped = slots.count - good.count
        return Decoded(elements: good, skipped: skipped, wholeFileUndecodable: !slots.isEmpty && good.isEmpty)
    }
}

public enum StoreFile {
    /// Files written by background wakes or read by widgets must stay readable while the phone is locked
    /// after the first unlock; `.completeFileProtection` makes those writes fail and widgets read nothing.
    public static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    /// Copies `url` to `<stem>_corrupt_<ms>.json` next to it. Returns the existing backup when an identical
    /// copy is already there (a file that stays corrupt must not add a copy per launch).
    @discardableResult
    public static func backupCorrupt(_ url: URL, now: Date = Date()) throws -> URL {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let prefix = url.deletingPathExtension().lastPathComponent + "_corrupt_"
        for existing in corruptBackups(in: dir, prefixes: [prefix]) where fm.contentsEqual(atPath: existing.path, andPath: url.path) {
            return existing
        }
        let backup = dir.appendingPathComponent("\(prefix)\(Int(now.timeIntervalSince1970 * 1000)).json")
        try fm.copyItem(at: url, to: backup)
        return backup
    }

    public static func corruptBackups(in directory: URL, prefixes: [String]) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { f in prefixes.contains { f.lastPathComponent.hasPrefix($0) } }
    }

    /// Existing installs hold these files at `.complete`; lower them once while the app is unlocked.
    public static func relaxProtection(of urls: [URL]) {
        #if os(iOS) || os(watchOS)
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                   ofItemAtPath: url.path)
        }
        #endif
    }
}

/// Sessions that reached the phone but are not yet in `sessions.json`. One file per session id
/// (`<uuid>.json`), so adding never reads or rewrites other entries and a duplicate id is a no-op.
/// `PhoneSyncCoordinator` adds, `DataManager` (the only `sessions.json` writer) drains and acknowledges.
public struct SessionInbox<T: Codable & Identifiable> where T.ID == UUID {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private func file(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    public func add(_ item: T) throws {
        let url = file(item.id)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(item).write(to: url, options: StoreFile.writeOptions)
    }

    /// Every readable entry. An unreadable file is renamed to `.bad` (kept, never read again).
    public func contents() -> LenientJSON.Decoded<T> {
        var out = LenientJSON.Decoded<T>()
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.pathExtension == "json" {
            do {
                out.elements.append(try JSONDecoder().decode(T.self, from: Data(contentsOf: f)))
            } catch {
                out.skipped += 1
                try? FileManager.default.moveItem(at: f, to: f.appendingPathExtension("bad"))
            }
        }
        return out
    }

    public func remove(ids: Set<UUID>) {
        for id in ids { try? FileManager.default.removeItem(at: file(id)) }
    }

    public func removeAll() { try? FileManager.default.removeItem(at: directory) }

    /// Keeps only the newest `cap` entries (by modification date). For a quarantine folder that must stay bounded.
    public func trim(to cap: Int) {
        let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "json" }
        guard files.count > cap else { return }
        func date(_ u: URL) -> Date { (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
        for f in files.sorted(by: { date($0) < date($1) }).prefix(files.count - cap) { try? FileManager.default.removeItem(at: f) }
    }
}

public enum SessionIngestRules {
    public static let clearedAtKey = "sessionsClearedAt"

    public static func clearedAt(_ defaults: UserDefaults = .standard) -> Date? {
        let t = defaults.double(forKey: clearedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    public static func markCleared(at date: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: clearedAtKey)
    }

    /// A session that ended at or before the user's last clear must never come back (late watch resend,
    /// iCloud pull, Health re-import). A workout still running when the user cleared ends later and is kept.
    public static func isStale(end: Date, clearedAt: Date?) -> Bool {
        guard let clearedAt else { return false }
        return end <= clearedAt
    }
}

/// Phone -> watch: drop your copies. Sent with `transferUserInfo` (and `sendMessage` when reachable).
public struct PurgeSessionsMessage {
    public enum Scope: String { case all, sessions }
    public static let action = "purgeSessions"

    public let scope: Scope
    public let ts: Double

    public init(scope: Scope, ts: Double = Date().timeIntervalSince1970) {
        self.scope = scope
        self.ts = ts
    }

    public var payload: [String: Any] { ["action": Self.action, "scope": scope.rawValue, "ts": ts] }

    public init?(payload: [String: Any]) {
        guard payload["action"] as? String == Self.action,
              let raw = payload["scope"] as? String, let scope = Scope(rawValue: raw),
              let ts = payload["ts"] as? Double else { return nil }
        self.scope = scope
        self.ts = ts
    }
}
