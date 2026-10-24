import XCTest
@testable import ShuttlXShared

final class RouteStoreTests: XCTestCase {
    private var dir: URL!
    private var store: RouteStore!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("routes-\(UUID().uuidString)")
        store = RouteStore(directory: dir) // directory created by the first write
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private let points = [
        RoutePoint(latitude: 52.37, longitude: 4.89, altitude: 1.5, timestamp: Date(timeIntervalSinceReferenceDate: 0), speed: 1.4, horizontalAccuracy: 5),
        RoutePoint(latitude: 52.3702, longitude: 4.8903, altitude: nil, timestamp: Date(timeIntervalSinceReferenceDate: 5)),
    ]

    func testWriteReadRoundTrip() throws {
        let id = UUID()
        try store.write(points, id: id)
        XCTAssertEqual(store.read(id: id), points)
        try store.write([points[0]], id: id) // overwrite
        XCTAssertEqual(store.read(id: id), [points[0]])
    }

    func testMissingAndCorruptFilesAreNil() throws {
        XCTAssertNil(store.read(id: UUID()))
        let id = UUID()
        try store.write(points, id: id)
        try Data("{not json".utf8).write(to: dir.appendingPathComponent("\(id.uuidString).json"))
        XCTAssertNil(store.read(id: id))
    }

    func testRemoveAndStoredIDs() throws {
        let a = UUID(), b = UUID(), c = UUID()
        for id in [a, b, c] { try store.write(points, id: id) }
        try Data().write(to: dir.appendingPathComponent("notes.txt"))
        try Data().write(to: dir.appendingPathComponent("not-a-uuid.json"))
        XCTAssertEqual(store.storedIDs(), [a, b, c])
        store.remove(ids: [a, UUID()])
        XCTAssertEqual(store.storedIDs(), [b, c])
        XCTAssertNil(store.read(id: a))
        XCTAssertEqual(RouteStore(directory: dir.appendingPathComponent("absent")).storedIDs(), [])
    }
}

extension RouteStoreTests {
    func testOrphansAreOldFilesOfUnknownSessions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("orphans-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = RouteStore(directory: dir)
        let kept = UUID(), oldOrphan = UUID(), newOrphan = UUID()
        let p = [RoutePoint(latitude: 1, longitude: 2, timestamp: Date(timeIntervalSinceReferenceDate: 0))]
        for id in [kept, oldOrphan, newOrphan] { try store.write(p, id: id) }
        let old = Date().addingTimeInterval(-3 * 86_400)
        for id in [kept, oldOrphan] {
            try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: dir.appendingPathComponent("\(id.uuidString).json").path)
        }
        XCTAssertEqual(store.orphans(keeping: [kept], writtenBefore: Date().addingTimeInterval(-86_400)), [oldOrphan])
    }
}
