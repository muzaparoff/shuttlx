import XCTest
@testable import ShuttlXShared

final class SessionHeadlineTests: XCTestCase {
    private func sessionsFile(_ records: [String]) -> Data { Data("[\(records.joined(separator: ","))]".utf8) }

    func testDecodesFullSessionsAndSkipsABadRecord() throws {
        let full = String(decoding: try ModelWireCompatibilityTests.fixture("session_v1"), as: UTF8.self)
        let r = LenientJSON.decodeArray(SessionHeadline.self, from: sessionsFile([full, #"{"id":"not-a-uuid"}"#, full]))
        XCTAssertEqual(r.elements.count, 2)
        XCTAssertEqual(r.skipped, 1)
        let h = try XCTUnwrap(r.elements.first)
        let s = try JSONDecoder().decode(TrainingSession.self, from: ModelWireCompatibilityTests.fixture("session_v1"))
        XCTAssertEqual(h.id, s.id)
        XCTAssertEqual(h.startDate, s.startDate)
        XCTAssertEqual(h.duration, s.duration)
        XCTAssertEqual(h.averageHeartRate, s.averageHeartRate)
        XCTAssertEqual(h.caloriesBurned, s.caloriesBurned)
        XCTAssertEqual(h.distance, s.distance)
        XCTAssertEqual(h.segments, s.segments)
        XCTAssertEqual(h.displayName, s.displayName)
    }

    func testIgnoresTheRoute() throws {
        // A route a full TrainingSession could not decode: the headline never looks at it.
        let minimal = #"{"id":"00000000-0000-4000-8000-000000000001","startDate":0,"duration":60,"segments":[],"route":"garbage"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(TrainingSession.self, from: Data(minimal.utf8)))
        let r = LenientJSON.decodeArray(SessionHeadline.self, from: sessionsFile([minimal]))
        XCTAssertEqual(r.elements.count, 1)
        XCTAssertEqual(r.elements.first?.displayName, "Run+Walk")
    }
}
