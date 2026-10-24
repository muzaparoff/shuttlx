import XCTest
@testable import ShuttlXShared

final class RouteExternalizeTests: XCTestCase {
    private var dir: URL!
    private var store: RouteStore!
    private var sessionsURL: URL { dir.appendingPathComponent("sessions.json") }
    private var backupURL: URL { dir.appendingPathComponent("sessions_pre_routes_backup.json") }
    struct Boom: Error {}

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("externalize-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = RouteStore(directory: dir.appendingPathComponent("routes"))
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func session(points: Int) -> TrainingSession {
        let t0 = Date(timeIntervalSinceReferenceDate: 790_000_000)
        let route = (0..<points).map { RoutePoint(latitude: 52 + Double($0) * 1e-4, longitude: 0.1, altitude: Double($0 % 7),
                                                  timestamp: t0.addingTimeInterval(Double($0))) }
        return TrainingSession(startDate: t0, duration: 600, distance: 2, inlineRoute: route.isEmpty ? nil : route)
    }

    /// The app's load + ingest step: strip every inline route into the pending map.
    private func strip(_ sessions: [TrainingSession]) -> ([TrainingSession], [UUID: [RoutePoint]]) {
        var pending: [UUID: [RoutePoint]] = [:]
        let out = sessions.map { s -> TrainingSession in
            var s = s
            if let r = RouteExternalize.strip(&s) { pending[s.id] = r }
            return s
        }
        return (out, pending)
    }

    private func records() throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: sessionsURL)) as? [[String: Any]])
    }

    func testStrippedSnapshotHasNoRouteAndFilesHoldThePoints() throws {
        let original = [session(points: 50), session(points: 0), session(points: 3)]
        let (stripped, pending) = strip(original)
        XCTAssertEqual(pending.count, 2)
        let r = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: backupURL)
        XCTAssertEqual(r.written, Set(pending.keys))
        XCTAssertTrue(r.keptInline.isEmpty)
        XCTAssertFalse(r.backupMade) // no sessions.json yet: nothing to back up
        XCTAssertTrue(try records().allSatisfy { $0["route"] == nil })
        for s in original where s.inlineRoute != nil {
            XCTAssertEqual(store.read(id: s.id), s.inlineRoute)
        }
        let loaded = try JSONDecoder().decode([TrainingSession].self, from: Data(contentsOf: sessionsURL))
        XCTAssertEqual(loaded.first?.routeSummary?.pointCount, 50)
        XCTAssertNil(loaded[1].routeSummary)
    }

    func testFailingRouteWriteKeepsThatSessionInline() throws {
        let original = [session(points: 10), session(points: 20)]
        let (stripped, pending) = strip(original)
        let bad = original[1].id
        let r = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: backupURL,
                                          writeRoute: { pts, id in if id == bad { throw Boom() }; try self.store.write(pts, id: id) })
        XCTAssertEqual(r.written, [original[0].id])
        XCTAssertEqual(r.keptInline, [bad])
        let loaded = try JSONDecoder().decode([TrainingSession].self, from: Data(contentsOf: sessionsURL))
        XCTAssertNil(loaded[0].inlineRoute)
        XCTAssertEqual(loaded[1].inlineRoute, original[1].inlineRoute)
        XCTAssertNil(store.read(id: bad))
    }

    func testFailingSessionsWriteLeavesOldFileAndRouteFiles() throws {
        let original = [session(points: 10), session(points: 20)]
        let old = try JSONEncoder().encode(original)   // a pre-migration file: routes inline
        try old.write(to: sessionsURL)
        let (stripped, pending) = strip(original)
        XCTAssertThrowsError(try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL,
                                                       backupURL: backupURL, writeSessions: { _, _ in throw Boom() }))
        XCTAssertEqual(try Data(contentsOf: sessionsURL), old)
        XCTAssertEqual(store.storedIDs(), Set(original.map(\.id)))
        XCTAssertEqual(try Data(contentsOf: backupURL), old)
    }

    func testCrashBeforeSessionsWriteThenSecondRunIsIdempotent() throws {
        let original = [session(points: 30), session(points: 0), session(points: 5)]
        let old = try JSONEncoder().encode(original)
        try old.write(to: sessionsURL)
        // Run 1 "crashes" between the route files and the sessions.json write (the write never happens).
        var (stripped, pending) = strip(original)
        XCTAssertThrowsError(try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL,
                                                       backupURL: backupURL, writeSessions: { _, _ in throw Boom() }))
        // The relaunch reads the old file again (routes still inline) and saves for real, twice.
        XCTAssertEqual(try Data(contentsOf: sessionsURL), old)
        let reloaded = try JSONDecoder().decode([TrainingSession].self, from: Data(contentsOf: sessionsURL))
        (stripped, pending) = strip(reloaded)
        let r2 = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: backupURL)
        let after2 = try JSONSerialization.jsonObject(with: Data(contentsOf: sessionsURL)) as? NSArray
        let r3 = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: backupURL)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: Data(contentsOf: sessionsURL)) as? NSArray, after2) // key order varies
        XCTAssertTrue(try records().allSatisfy { $0["route"] == nil })
        XCTAssertEqual(r2.written, r3.written)
        XCTAssertFalse(r2.backupMade) // made by run 1, never overwritten
        XCTAssertEqual(try Data(contentsOf: backupURL), old)
        for s in original where s.inlineRoute != nil { XCTAssertEqual(store.read(id: s.id), s.inlineRoute) }
    }

    func testMixedFileLoads() throws {
        var stripped = session(points: 4)
        let route = try XCTUnwrap(RouteExternalize.strip(&stripped))
        try store.write(route, id: stripped.id)
        let inline = session(points: 6)
        try JSONEncoder().encode([stripped, inline]).write(to: sessionsURL)
        let decoded = LenientJSON.decodeArray(TrainingSession.self, from: try Data(contentsOf: sessionsURL))
        XCTAssertEqual(decoded.elements.count, 2)
        XCTAssertEqual(decoded.skipped, 0)
        XCTAssertNil(decoded.elements[0].inlineRoute)
        XCTAssertEqual(decoded.elements[0].routeSummary?.pointCount, 4)
        XCTAssertEqual(decoded.elements[1].inlineRoute?.count, 6)
    }

    func testInlineEverythingPutsRoutesBack() throws {
        let original = [session(points: 8), session(points: 9)]
        var (stripped, pending) = strip(original)
        _ = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: nil)
        pending = [:]
        // One route still pending (not on disk), one only in its file.
        stripped.append(session(points: 3))
        let extra = RouteExternalize.strip(&stripped[2])
        pending[stripped[2].id] = extra
        let r = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL, backupURL: nil,
                                          inlineEverything: true)
        XCTAssertTrue(r.written.isEmpty)
        let loaded = try JSONDecoder().decode([TrainingSession].self, from: Data(contentsOf: sessionsURL))
        XCTAssertEqual(loaded.map { $0.inlineRoute?.count }, [8, 9, 3])
    }

    func testFailedBackupMovesNothingOut() throws {
        let original = [session(points: 5)]
        try JSONEncoder().encode(original).write(to: sessionsURL)
        let (stripped, pending) = strip(original)
        let r = try RouteExternalize.save(stripped, pendingRoutes: pending, store: store, sessionsURL: sessionsURL,
                                          backupURL: dir.appendingPathComponent("missing-dir/backup.json"))
        XCTAssertEqual(r.keptInline, [original[0].id])
        XCTAssertTrue(store.storedIDs().isEmpty)
        let loaded = try JSONDecoder().decode([TrainingSession].self, from: Data(contentsOf: sessionsURL))
        XCTAssertEqual(loaded[0].inlineRoute, original[0].inlineRoute)
    }
}

extension RouteExternalizeTests {
    func testUploadCopyCarriesTheRouteOrIsSkipped() throws {
        var routed = session(points: 5)
        let points = try XCTUnwrap(RouteExternalize.strip(&routed))
        XCTAssertEqual(RouteExternalize.forUpload(routed, route: points)?.inlineRoute, points)
        XCTAssertNil(RouteExternalize.forUpload(routed, route: nil), "never upload a routed session without its route")
        XCTAssertNil(RouteExternalize.forUpload(routed, route: []))
        let plain = session(points: 0)
        XCTAssertEqual(RouteExternalize.forUpload(plain, route: nil)?.id, plain.id)
        let inline = session(points: 3)   // still inline (e.g. a pulled copy): sent as it is
        XCTAssertEqual(RouteExternalize.forUpload(inline, route: nil)?.inlineRoute?.count, 3)
    }
}
