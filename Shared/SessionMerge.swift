import Foundation

/// Decides when a session arriving from the watch replaces a copy the phone already holds.
/// Pure (no TrainingSession) so `swift test` covers it; `DataManager` maps its sessions to `Item`.
public enum SessionMerge {
    public struct Item: Equatable, Sendable {
        public var id: UUID
        public var start: Date
        public var end: Date
        public var importedFromHealth: Bool
        /// The iPhone's own record of a workout that the watch also recorded (the watch version wins).
        public var isPhonePlaceholder: Bool
        public init(id: UUID, start: Date, end: Date, importedFromHealth: Bool = false, isPhonePlaceholder: Bool = false) {
            self.id = id; self.start = start; self.end = end
            self.importedFromHealth = importedFromHealth; self.isPhonePlaceholder = isPhonePlaceholder
        }
    }

    /// Two time ranges are the same workout when they overlap by at least half of the shorter one.
    public static func overlapsEnough(_ a: Item, _ b: Item) -> Bool {
        let overlap = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let shorter = min(a.end.timeIntervalSince(a.start), b.end.timeIntervalSince(b.start))
        return overlap > 0 && overlap >= max(shorter, 1) * 0.5
    }

    /// True when `incoming` (a session received over WatchConnectivity) must replace `existing`:
    /// - the same id, and `existing` was only imported from Apple Health (late watch session), or
    /// - `existing` is the phone's placeholder for the same workout.
    /// A Health import never replaces anything.
    public static func replaces(incoming: Item, existing: Item) -> Bool {
        guard !incoming.importedFromHealth else { return false }
        if existing.id == incoming.id { return existing.importedFromHealth }
        return existing.isPhonePlaceholder && overlapsEnough(incoming, existing)
    }

    /// The watch recorded this workout already (any non-placeholder session of the same time range).
    public static func isCovered(_ phone: Item, by existing: [Item]) -> Bool {
        existing.contains { !$0.isPhonePlaceholder && $0.id != phone.id && overlapsEnough(phone, $0) }
    }

    /// The effort answer survives a replacement: the incoming one wins, else the replaced session's.
    public static func carriedEffort(incoming: Int?, replaced: [Int?]) -> Int? {
        incoming ?? replaced.compactMap { $0 }.first
    }
}
