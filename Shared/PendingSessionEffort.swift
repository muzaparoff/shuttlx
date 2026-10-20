import Foundation

/// Effort answers (0-10) that reached the phone before their session did.
/// Small and bounded: the oldest entry is dropped past `cap`. The caller persists it (Codable).
public struct PendingSessionEffort: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let sessionId: String
        public let rpe: Int
    }

    public static let cap = 20
    public private(set) var entries: [Entry] = []

    public init() {}

    /// Stores the answer for a session; a newer answer for the same session replaces the older one.
    public mutating func add(sessionId: String, rpe: Int) {
        entries.removeAll { $0.sessionId == sessionId }
        entries.append(Entry(sessionId: sessionId, rpe: min(max(rpe, 0), 10)))
        if entries.count > Self.cap { entries.removeFirst(entries.count - Self.cap) }
    }

    /// Returns and removes the waiting answer for a session, if any.
    public mutating func take(sessionId: String) -> Int? {
        guard let i = entries.firstIndex(where: { $0.sessionId == sessionId }) else { return nil }
        return entries.remove(at: i).rpe
    }
}
