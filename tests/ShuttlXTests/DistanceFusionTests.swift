import XCTest
@testable import ShuttlXShared

final class DistanceFusionTests: XCTestCase {
    func testGPSAloneGivesDistanceWithoutPedometer() {
        // The reported bug: GPS grew, the pedometer never reported, the display stayed 0.
        XCTAssertEqual(DistanceFusion.totalKm(gpsKm: 0.72, gpsUsable: true, pedometerKm: 0), 0.72)
    }

    func testPedometerIsTheFallbackUntilGPSIsUsable() {
        XCTAssertEqual(DistanceFusion.totalKm(gpsKm: 0.01, gpsUsable: false, pedometerKm: 0.30), 0.30)
    }

    func testNeverTheSum() {
        XCTAssertEqual(DistanceFusion.totalKm(gpsKm: 1.0, gpsUsable: true, pedometerKm: 1.1), 1.0)
    }
}
