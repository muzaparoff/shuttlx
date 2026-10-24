import XCTest
@testable import ShuttlXShared

final class RouteSummaryTests: XCTestCase {
    private func p(_ alt: Double?, _ t: Double, lat: Double = 52.37) -> RoutePoint {
        RoutePoint(latitude: lat, longitude: 4.89, altitude: alt, timestamp: Date(timeIntervalSinceReferenceDate: t))
    }

    /// Copy of the per-session loop in `AnalyticsEngine.elevationSummary` (iOS, Oct 2026), the reference.
    private func reference(_ route: [RoutePoint]) -> (ascent: Double, descent: Double, max: Double)? {
        let altitudes = route.compactMap(\.altitude)
        guard altitudes.count >= 2 else { return nil }
        var ascent = 0.0, descent = 0.0
        for i in 1..<altitudes.count {
            let diff = altitudes[i] - altitudes[i - 1]
            if diff > 0 { ascent += diff } else { descent += abs(diff) }
        }
        return (ascent, descent, altitudes.max()!)
    }

    func testMatchesTheElevationSummaryLoop() throws {
        let route = [p(10, 0, lat: 1), p(12.5, 1), p(nil, 2), p(11, 3), p(11, 4), p(20.25, 5), p(3, 6)]
        let s = try XCTUnwrap(RouteSummary(points: route))
        let ref = try XCTUnwrap(reference(route))
        XCTAssertEqual(s.ascent, ref.ascent)
        XCTAssertEqual(s.descent, ref.descent)
        XCTAssertEqual(s.maxAltitude, ref.max)
        XCTAssertEqual(s.ascent, 11.75)
        XCTAssertEqual(s.descent, 18.75)
        XCTAssertEqual(s.pointCount, 7)
        XCTAssertEqual(s.altitudeCount, 6)
        XCTAssertEqual(s.startLatitude, 1)
        XCTAssertEqual(s.startLongitude, 4.89)
    }

    func testNoAltitudes() throws {
        let s = try XCTUnwrap(RouteSummary(points: [p(nil, 0), p(nil, 1)]))
        XCTAssertNil(s.maxAltitude)
        XCTAssertEqual(s.altitudeCount, 0)
        XCTAssertEqual(s.ascent, 0)
        XCTAssertEqual(s.descent, 0)
    }

    func testEmptyAndSinglePoint() throws {
        XCTAssertNil(RouteSummary(points: []))
        let one = try XCTUnwrap(RouteSummary(points: [p(7, 0)]))
        XCTAssertEqual(one.pointCount, 1)
        XCTAssertEqual(one.altitudeCount, 1) // latestElevationRoute would pick it, elevationSummary would not
        XCTAssertEqual(one.maxAltitude, 7)
        XCTAssertEqual(one.ascent, 0)
        XCTAssertNil(reference([p(7, 0)]))
    }
}
