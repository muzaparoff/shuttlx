import XCTest
@testable import ShuttlXShared

final class PendingSessionEffortTests: XCTestCase {
    func testTakeReturnsAndRemoves() {
        var p = PendingSessionEffort()
        p.add(sessionId: "A", rpe: 6)
        XCTAssertEqual(p.take(sessionId: "A"), 6)
        XCTAssertNil(p.take(sessionId: "A"))
        XCTAssertNil(p.take(sessionId: "missing"))
    }

    func testNewerAnswerReplacesOlder() {
        var p = PendingSessionEffort()
        p.add(sessionId: "A", rpe: 3)
        p.add(sessionId: "A", rpe: 8)
        XCTAssertEqual(p.entries.count, 1)
        XCTAssertEqual(p.take(sessionId: "A"), 8)
    }

    func testClampsToZeroTen() {
        var p = PendingSessionEffort()
        p.add(sessionId: "A", rpe: 42)
        p.add(sessionId: "B", rpe: -5)
        XCTAssertEqual(p.take(sessionId: "A"), 10)
        XCTAssertEqual(p.take(sessionId: "B"), 0)
    }

    func testBoundedDropsOldest() {
        var p = PendingSessionEffort()
        for i in 0..<(PendingSessionEffort.cap + 5) { p.add(sessionId: "S\(i)", rpe: 5) }
        XCTAssertEqual(p.entries.count, PendingSessionEffort.cap)
        XCTAssertNil(p.take(sessionId: "S0"))
        XCTAssertEqual(p.take(sessionId: "S\(PendingSessionEffort.cap + 4)"), 5)
    }

    func testCodableRoundTrip() throws {
        var p = PendingSessionEffort()
        p.add(sessionId: "A", rpe: 4)
        let back = try JSONDecoder().decode(PendingSessionEffort.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back, p)
    }
}
