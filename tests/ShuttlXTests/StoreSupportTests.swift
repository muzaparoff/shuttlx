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

    // MARK: append (watch sessions.json, audit C1)

    /// The old watch append decoded strictly and wrote `[new]` over a file with one bad record
    /// (probe: 30 good + 1 bad became 1 record).
    func testAppendKeepsGoodRecordsAndBacksUpTheBadOne() throws {
        let f = dir.appendingPathComponent("sessions.json")
        let good = (1...30).map { Rec(id: UUID(), n: $0) }
        var json = String(data: try JSONEncoder().encode(good), encoding: .utf8)!
        json.removeLast()
        json += ",{\"id\":\"not-a-uuid\",\"n\":0}]"
        let original = Data(json.utf8)
        try original.write(to: f)
        let new = Rec(id: UUID(), n: 99)

        guard case .inserted(let backup?) = try StoreAppend.append(new, to: f, options: .atomic) else {
            return XCTFail("expected an insert with a backup")
        }
        XCTAssertEqual(try JSONDecoder().decode([Rec].self, from: Data(contentsOf: f)), good + [new])
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertEqual(try StoreAppend.append(new, to: f, options: .atomic), .alreadyStored)
    }

    func testAppendNeverReplacesAWhollyUnreadableFile() throws {
        let f = dir.appendingPathComponent("sessions.json")
        let truncated = Data("[{\"id\":".utf8)
        try truncated.write(to: f)

        guard case .fileKept(let backup?) = try StoreAppend.append(Rec(id: UUID(), n: 1), to: f, options: .atomic) else {
            return XCTFail("expected the file to be kept")
        }
        XCTAssertEqual(try Data(contentsOf: f), truncated)
        XCTAssertEqual(try Data(contentsOf: backup), truncated)
        // A second attempt adds no second copy and still leaves the file alone.
        guard case .fileKept(let again?) = try StoreAppend.append(Rec(id: UUID(), n: 2), to: f, options: .atomic) else {
            return XCTFail("expected the file to be kept")
        }
        XCTAssertEqual(again.lastPathComponent, backup.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: f), truncated)
    }

    func testAppendCreatesMissingFile() throws {
        let f = dir.appendingPathComponent("sessions.json")
        let r = Rec(id: UUID(), n: 1)
        XCTAssertEqual(try StoreAppend.append(r, to: f, options: .atomic), .inserted(backup: nil))
        XCTAssertEqual(try JSONDecoder().decode([Rec].self, from: Data(contentsOf: f)), [r])
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
        let files = try FileManager.default.contentsOfDirectory(atPath: pending.path)
        XCTAssertEqual(files.filter { $0.hasSuffix(".json.bad") }.count, 1) // set aside, not deleted
    }

    // MARK: watch pending queue (Wave 5 C8)

    func testPutOverwritesWhereAddDoesNot() throws {
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending_sync"))
        let id = UUID()
        try inbox.put(Rec(id: id, n: 1))
        try inbox.add(Rec(id: id, n: 2))
        XCTAssertEqual(inbox.contents().elements, [Rec(id: id, n: 1)])
        try inbox.put(Rec(id: id, n: 3))
        XCTAssertEqual(inbox.contents().elements, [Rec(id: id, n: 3)])
    }

    /// The watch runs add / put / remove for one id on one serial queue; the last one wins.
    func testAddThenRemoveInOrderOnASerialQueue() throws {
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending_sync"))
        let queue = DispatchQueue(label: "test.pending")
        let a = Rec(id: UUID(), n: 1), b = Rec(id: UUID(), n: 2)
        queue.async { try? inbox.add(a) }
        queue.async { try? inbox.add(b) }
        queue.async { try? inbox.put(Rec(id: b.id, n: 7)) }
        queue.async { inbox.remove(ids: [a.id]) }
        queue.sync {}
        XCTAssertEqual(inbox.contents().elements, [Rec(id: b.id, n: 7)])
    }

    func testMigrationMovesEveryRecordAndDeletesTheOldFile() throws {
        let legacy = dir.appendingPathComponent("pending_sync_sessions.json")
        let recs = (1...3).map { Rec(id: UUID(), n: $0) }
        try JSONEncoder().encode(recs).write(to: legacy)
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending_sync"))
        XCTAssertEqual(try inbox.migrate(from: legacy), .migrated(count: 3, backup: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(Set(inbox.contents().elements.map(\.id)), Set(recs.map(\.id)))
        XCTAssertEqual(try inbox.migrate(from: legacy), .noLegacyFile)
    }

    func testMigrationOfAHalfCorruptFileBacksUpTheOriginal() throws {
        let legacy = dir.appendingPathComponent("pending_sync_sessions.json")
        let good = Rec(id: UUID(), n: 1)
        var json = String(data: try JSONEncoder().encode([good]), encoding: .utf8)!
        json.removeLast()
        json += ",{\"id\":\"not-a-uuid\",\"n\":0}]"
        let original = Data(json.utf8)
        try original.write(to: legacy)
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending_sync"))
        // A session queued before the migration ran is newer than its legacy copy and is kept.
        let early = Rec(id: good.id, n: 5)
        try inbox.add(early)

        guard case .migrated(1, let backup?) = try inbox.migrate(from: legacy) else {
            return XCTFail("expected a migration with a backup")
        }
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(inbox.contents().elements, [early])
    }

    func testMigrationNeverDeletesAWhollyUnreadableFile() throws {
        let legacy = dir.appendingPathComponent("pending_sync_sessions.json")
        let garbage = Data("not json".utf8)
        try garbage.write(to: legacy)
        let inbox = SessionInbox<Rec>(directory: dir.appendingPathComponent("pending_sync"))
        guard case .fileKept(let backup) = try inbox.migrate(from: legacy) else {
            return XCTFail("expected the file to be kept")
        }
        XCTAssertEqual(try Data(contentsOf: legacy), garbage)
        XCTAssertEqual(try Data(contentsOf: backup), garbage)
        XCTAssertTrue(backup.lastPathComponent.hasPrefix("pending_sync_sessions_corrupt_"))
        try inbox.add(Rec(id: UUID(), n: 1)) // the queue keeps working
        XCTAssertEqual(inbox.contents().elements.count, 1)
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
