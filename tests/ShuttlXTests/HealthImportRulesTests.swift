import XCTest
@testable import ShuttlXShared

final class HealthImportRulesTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testExternalUUIDMatch() {
        let id = UUID()
        let known = [HealthImportRules.Known(id: id, start: t0.addingTimeInterval(9999), duration: 5)]
        XCTAssertTrue(HealthImportRules.isAlreadyPresent(externalUUID: id, workoutUUID: UUID(), start: t0, duration: 1800, known: known))
    }

    func testTimeAndDurationFallback() {
        let known = [HealthImportRules.Known(id: UUID(), start: t0, duration: 1800)]
        func check(_ dt: TimeInterval, _ dur: TimeInterval) -> Bool {
            HealthImportRules.isAlreadyPresent(externalUUID: nil, workoutUUID: UUID(), start: t0.addingTimeInterval(dt), duration: dur, known: known)
        }
        XCTAssertTrue(check(120, 1800 * 1.05))
        XCTAssertFalse(check(121, 1800))
        XCTAssertFalse(check(0, 1800 * 1.06))
    }

    func testSessionID() {
        let w = UUID(), e = UUID()
        XCTAssertEqual(HealthImportRules.sessionID(externalUUIDString: e.uuidString, workoutUUID: w), e)
        XCTAssertEqual(HealthImportRules.sessionID(externalUUIDString: "nope", workoutUUID: w), w)
        XCTAssertEqual(HealthImportRules.sessionID(externalUUIDString: nil, workoutUUID: w), w)
    }

    func testDownsampleKeepsEndsAndCap() {
        let out = HealthImportRules.downsample(Array(0..<5000), limit: 2000)
        XCTAssertEqual(out.count, 2000)
        XCTAssertEqual(out.first, 0)
        XCTAssertEqual(out.last, 4999)
        XCTAssertEqual(HealthImportRules.downsample([1, 2, 3], limit: 2000), [1, 2, 3])
    }

    func testActivityMapping() {
        XCTAssertEqual(HealthImportRules.activity(phaseMetadata: "walking", sport: .running), .walking)
        XCTAssertEqual(HealthImportRules.activity(phaseMetadata: nil, sport: .running), .running)
        XCTAssertEqual(HealthImportRules.activity(phaseMetadata: "bogus", sport: .cycling), .unknown)
    }

    func testGrace() {
        XCTAssertFalse(HealthImportRules.isPastGrace(end: t0, now: t0.addingTimeInterval(599)))
        XCTAssertTrue(HealthImportRules.isPastGrace(end: t0, now: t0.addingTimeInterval(600)))
    }
}
