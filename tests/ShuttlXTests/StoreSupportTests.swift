import XCTest
@testable import ShuttlXShared

final class StoreSupportTests: XCTestCase {
    struct Rec: Codable, Identifiable, Equatable { let id: UUID; var n: Int }

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    // MARK: per-element decode

    func testOneBadElementKeepsTheRest() throws {
        let a = Rec(id: UUID(), n: 1), b = Rec(id: UUID(), n: 2)
        var json = String(data: try JSONEncoder().encode([a, b]), encoding: .utf8)!
        json.removeLast() // drop "]"
        json += ",{\"id\":\"not-a-uuid\"}]"
        let r = LenientJSON.decodeArray(Rec.self, from: Data(json.utf8))
        // The old all-or-nothing decode (DataManager.loadSessionsFromAppGroup before this change) lost everything:
        XCTAssertThrowsError(try JSONDecoder().decode([Rec].self, from: Data(json.utf8)))
        XCTAssertEqual(r.elements, [a, b])
        XCTAssertEqual(r.skipped, 1)
        XCTAssertFalse(r.wholeFileUndecodable)
    }

    func testTruncatedFileIsWholeFileUndecodable() throws {
        let data = try JSONEncoder().encode([Rec(id: UUID(), n: 1)])
        XCTAssertTrue(LenientJSON.decodeArray(Rec.self, from: data.prefix(data.count - 5)).wholeFileUndecodable)
        XCTAssertTrue(LenientJSON.decodeArray(Rec.self, from: Data()).wholeFileUndecodable)
    }

    func testAllElementsBadCountsAsWholeFile() {
        let r = LenientJSON.decodeArray(Rec.self, from: Data("[{\"x\":1},{\"x\":2}]".utf8))
        XCTAssertTrue(r.wholeFileUndecodable)
        XCTAssertEqual(r.skipped, 2)
    }

    func testEmptyArrayIsFine() {
        let r = LenientJSON.decodeArray(Rec.self, from: Data("[]".utf8))
        XCTAssertTrue(r.elements.isEmpty)
        XCTAssertFalse(r.wholeFileUndecodable)
    }

    // MARK: corrupt backup

    func testBackupIsKeptOnceForIdenticalBytes() throws {
        let f = dir.appendingPathComponent("sessions.json")
        try Data("garbage".utf8).write(to: f)
        let first = try StoreFile.backupCorrupt(f)
        let second = try StoreFile.backupCorrupt(f, now: Date().addingTimeInterval(5))
        XCTAssertEqual(first.lastPathComponent, second.lastPathComponent)
        XCTAssertEqual(StoreFile.corruptBackups(in: dir, prefixes: ["sessions_corrupt_"]).count, 1)
        try Data("other garbage".utf8).write(to: f)
        _ = try StoreFile.backupCorrupt(f, now: Date().addingTimeInterval(10))
        XCTAssertEqual(StoreFile.corruptBackups(in: dir, prefixes: ["sessions_corrupt_"]).count, 2)
    }

    // MARK: inbox

    func testInboxDedupesDrainsAndAcknowledges() throws {
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending"))
        let a = Rec(id: UUID(), n: 1), b = Rec(id: UUID(), n: 2)
        try inbox.add(a); try inbox.add(a); try inbox.add(b)
        XCTAssertEqual(Set(inbox.contents().elements.map(\.id)), [a.id, b.id])
        XCTAssertEqual(inbox.contents().elements.count, 2)
        inbox.remove(ids: [a.id])
        XCTAssertEqual(inbox.contents().elements, [b])
        inbox.removeAll()
        XCTAssertTrue(inbox.contents().elements.isEmpty)
    }

    func testInboxQuarantinesUnreadableEntry() throws {
        let pending = dir.appendingPathComponent("pending")
        let inbox = SessionInbox<Rec>(directory: pending)
        try inbox.add(Rec(id: UUID(), n: 1))
        try Data("{".utf8).write(to: pending.appendingPathComponent("\(UUID().uuidString).json"))
        let first = inbox.contents()
        XCTAssertEqual(first.elements.count, 1)
        XCTAssertEqual(first.skipped, 1)
        XCTAssertEqual(inbox.contents().skipped, 0) // renamed to .bad, not re-read
    }

    // MARK: cutoff

    func testCutoffDropsOldKeepsRunningWorkout() {
        let cut = Date()
        XCTAssertTrue(SessionIngestRules.isStale(end: cut.addingTimeInterval(-60), clearedAt: cut))
        XCTAssertTrue(SessionIngestRules.isStale(end: cut, clearedAt: cut))
        XCTAssertFalse(SessionIngestRules.isStale(end: cut.addingTimeInterval(1), clearedAt: cut))
        XCTAssertFalse(SessionIngestRules.isStale(end: .distantPast, clearedAt: nil))
    }

    func testCutoffPersistsInDefaults() {
        let d = UserDefaults(suiteName: "cutoff-\(UUID().uuidString)")!
        XCTAssertNil(SessionIngestRules.clearedAt(d))
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        SessionIngestRules.markCleared(at: t, defaults: d)
        XCTAssertEqual(SessionIngestRules.clearedAt(d), t)
    }

    // MARK: purge contract

    func testPurgeMessageRoundTrip() {
        let m = PurgeSessionsMessage(scope: .sessions, ts: 42)
        XCTAssertEqual(m.payload["action"] as? String, "purgeSessions")
        XCTAssertEqual(m.payload["scope"] as? String, "sessions")
        XCTAssertEqual(m.payload["ts"] as? Double, 42)
        let back = PurgeSessionsMessage(payload: m.payload)
        XCTAssertEqual(back?.scope, .sessions)
        XCTAssertNil(PurgeSessionsMessage(payload: ["action": "purgeSessions", "scope": "bogus", "ts": 1.0]))
    }

    func testTrimKeepsTheNewestEntries() throws {
        let box = SessionInbox<Rec>(directory: dir.appendingPathComponent("rejected"))
        var ids: [UUID] = []
        for i in 0..<5 {
            let r = Rec(id: UUID(), n: i)
            try box.add(r)
            ids.append(r.id)
            let url = box.directory.appendingPathComponent("\(r.id.uuidString).json")
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000 + Double(i))], ofItemAtPath: url.path)
        }
        box.trim(to: 2)
        XCTAssertEqual(Set(box.contents().elements.map(\.id)), Set(ids.suffix(2)))
    }
}
