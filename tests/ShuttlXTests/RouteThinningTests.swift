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
