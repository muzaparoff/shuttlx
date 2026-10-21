import XCTest
@testable import ShuttlXShared

final class WCPayloadValidationTests: XCTestCase {
    func testLiveMetricsAcceptsRealSnapshot() {
        let m = WCPayloadValidation.liveMetrics([
            "elapsedTime": 1234.5, "heartRate": 131, "distance": 4.2, "calories": 310, "steps": 5000,
            "pace": 340.0, "currentActivity": "running", "workoutName": "Free Run", "isPaused": false,
            "latitude": 52.1, "longitude": 4.3])
        XCTAssertEqual(m?.heartRate, 131)
        XCTAssertEqual(m?.latitude, 52.1)
    }

    func testLiveMetricsRejectsBadElapsed() {
        XCTAssertNil(WCPayloadValidation.liveMetrics([:]))
        XCTAssertNil(WCPayloadValidation.liveMetrics(["elapsedTime": Double.nan]))
        XCTAssertNil(WCPayloadValidation.liveMetrics(["elapsedTime": -1.0]))
        XCTAssertNil(WCPayloadValidation.liveMetrics(["elapsedTime": 1e12]))
    }

    func testLiveMetricsZeroesBadFieldsAndDropsHalfAPosition() {
        let m = WCPayloadValidation.liveMetrics([
            "elapsedTime": 10.0, "heartRate": 9999, "distance": Double.infinity, "currentActivity": "flying",
            "latitude": 120.0, "longitude": 4.0])
        XCTAssertEqual(m?.heartRate, 0)
        XCTAssertEqual(m?.distance, 0)
        XCTAssertEqual(m?.currentActivity, "unknown")
        XCTAssertNil(m?.latitude)
        XCTAssertNil(m?.longitude)
    }

    func testLongWorkoutNameIsCut() {
        let m = WCPayloadValidation.liveMetrics(["elapsedTime": 1.0, "workoutName": String(repeating: "x", count: 500)])
        XCTAssertEqual(m?.workoutName.count, 60)
    }

    func testEffortNeedsUUIDAndRange() {
        let id = UUID().uuidString
        XCTAssertTrue(WCPayloadValidation.isValidEffort(sessionId: id, rpe: 0))
        XCTAssertTrue(WCPayloadValidation.isValidEffort(sessionId: id, rpe: 10))
        XCTAssertFalse(WCPayloadValidation.isValidEffort(sessionId: id, rpe: 11))
        XCTAssertFalse(WCPayloadValidation.isValidEffort(sessionId: id, rpe: -1))
        XCTAssertFalse(WCPayloadValidation.isValidEffort(sessionId: "not-a-uuid", rpe: 5))
    }

    func testAlertValueRange() {
        XCTAssertEqual(WCPayloadValidation.alertValue(150), 150)
        XCTAssertNil(WCPayloadValidation.alertValue(5000))
        XCTAssertNil(WCPayloadValidation.alertValue("150"))
        XCTAssertNil(WCPayloadValidation.alertValue(Double.nan))
    }

    func testSessionSanity() {
        let now = Date()
        let ok = { (d: TimeInterval, km: Double?, hr: Double?, seg: Int, route: Int, start: Date) in
            WCPayloadValidation.isSaneSession(startDate: start, duration: d, distanceKm: km, calories: 300,
                                              averageHR: hr, maxHR: hr, segmentCount: seg, routeCount: route, now: now)
        }
        XCTAssertTrue(ok(3600, 10, 140, 5, 3000, now.addingTimeInterval(-3600)))
        XCTAssertFalse(ok(.nan, 10, 140, 5, 0, now))
        XCTAssertFalse(ok(3600 * 100, 10, 140, 5, 0, now))
        XCTAssertFalse(ok(3600, -5, 140, 5, 0, now))
        XCTAssertFalse(ok(3600, 10, 900, 5, 0, now))
        XCTAssertFalse(ok(3600, 10, 140, 99_999, 0, now))
        XCTAssertFalse(ok(3600, 10, 140, 5, 9_999_999, now))
        XCTAssertFalse(ok(3600, 10, 140, 5, 0, now.addingTimeInterval(10 * 86_400)))
        XCTAssertFalse(ok(3600, 10, 140, 5, 0, Date(timeIntervalSince1970: 0)))
    }
}
