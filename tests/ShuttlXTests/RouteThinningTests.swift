import XCTest
@testable import ShuttlXShared

final class RouteThinningTests: XCTestCase {
    private func route(_ n: Int) -> [RoutePoint] {
        (0..<n).map { RoutePoint(latitude: Double($0), longitude: 0, timestamp: Date(timeIntervalSince1970: Double($0))) }
    }

    func testUnderLimitUntouched() {
        var r = route(10)
        r.thinIfOver(10)
        XCTAssertEqual(r.count, 10)
    }

    func testOverLimitHalvesAndKeepsEnds() {
        var r = route(11)
        r.thinIfOver(10)
        XCTAssertEqual(r.first?.latitude, 0)
        XCTAssertEqual(r.last?.latitude, 10)
        XCTAssertLessThanOrEqual(r.count, 7)
    }

    /// Watch rule (WatchWorkoutManager+LocationDelegate): append, then `thinEvenlyIfOver(2000, to: 1500)`.
    /// 4 h ride at 1 fix per 10 m (5 m/s, so a fix every 2 s). Points kept in hours 1-4: the old watch halving
    /// of the older half 2 / 17 / 206 / 1475 (scratch probe); `thinIfOver(2000)` on every append 29 / 71 / 250 / 850.
    func testFourHourRideKeepsPointsInEveryHour() {
        let cap = 2000
        var r: [RoutePoint] = []
        for i in 0..<7200 {
            r.append(RoutePoint(latitude: Double(i) * 10 / 111_000, longitude: 0,
                                timestamp: Date(timeIntervalSince1970: Double(i * 2))))
            r.thinEvenlyIfOver(cap, to: 1500)
            XCTAssertLessThanOrEqual(r.count, cap)
        }
        let perHour = (0..<4).map { h in r.filter { Int($0.timestamp.timeIntervalSince1970 / 3600) == h }.count }
        XCTAssertGreaterThanOrEqual(perHour.min() ?? 0, 200, "points per hour: \(perHour)")
        XCTAssertEqual(r.last?.timestamp, Date(timeIntervalSince1970: 7199 * 2))
        // The newest 60 s stay at full rate for the speed classifier.
        XCTAssertEqual(r.filter { $0.timestamp.timeIntervalSince1970 >= 7199 * 2 - 60 }.count, 31)
    }

    func testEvenThinningRunsRarely() {
        var r: [RoutePoint] = []
        var thins = 0
        for i in 0..<7200 {
            r.append(RoutePoint(latitude: 0, longitude: 0, timestamp: Date(timeIntervalSince1970: Double(i * 2))))
            let before = r.count
            r.thinEvenlyIfOver(2000, to: 1500)
            if r.count < before { thins += 1 }
        }
        XCTAssertLessThanOrEqual(thins, 12)   // about once per 500 fixes
    }

    func testRepeatedAppendStaysBounded() {
        var r: [RoutePoint] = []
        for i in 0..<5000 {
            r.append(RoutePoint(latitude: Double(i), longitude: 0, timestamp: Date(timeIntervalSince1970: Double(i))))
            r.thinIfOver(100)
        }
        XCTAssertLessThanOrEqual(r.count, 100)
        XCTAssertEqual(r.last?.latitude, 4999)
    }
}
