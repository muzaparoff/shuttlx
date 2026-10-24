import XCTest
@testable import ShuttlXShared

final class DistanceFusionTests: XCTestCase {
    private func step(_ f: inout DistanceFusion, gps: Double, ped: Double, usable: Bool = true, age: TimeInterval? = 1) -> Double {
        f.update(gpsKm: gps, pedometerKm: ped, gpsUsable: usable, gpsFixAge: age)
    }

    func testPedometerToGPSNeverLowersTotal() {
        var f = DistanceFusion()
        var last = 0.0
        // Pedometer only, then GPS becomes usable with a total far below (0.05) the pedometer's 0.40.
        for (g, p, u) in [(0.0, 0.2, false), (0.0, 0.4, false), (0.05, 0.5, true), (0.10, 0.6, true), (0.20, 0.7, true)] {
            let t = step(&f, gps: g, ped: p, usable: u, age: u ? 1 : nil)
            XCTAssertGreaterThanOrEqual(t, last)
            last = t
        }
        XCTAssertEqual(last, 0.4 + 0.05 + 0.05 + 0.10, accuracy: 1e-9)
    }

    func testGPSDropoutHandsOverToPedometerWithoutJump() {
        var f = DistanceFusion()
        _ = step(&f, gps: 0.5, ped: 0.45)
        XCTAssertEqual(f.totalKm, 0.5, accuracy: 1e-9)
        // Fix goes stale (> 10 s): pedometer increments take over, no jump to the pedometer total.
        let t = step(&f, gps: 0.5, ped: 0.55, age: 30)
        XCTAssertEqual(t, 0.6, accuracy: 1e-9)
        // GPS returns: only its new increment is added.
        XCTAssertEqual(step(&f, gps: 0.7, ped: 0.55, age: 2), 0.8, accuracy: 1e-9)
    }

    func testIndoorUsesPedometerOnly() {
        var f = DistanceFusion()
        XCTAssertEqual(step(&f, gps: 0, ped: 0.1, usable: false, age: nil), 0.1, accuracy: 1e-9)
        XCTAssertEqual(step(&f, gps: 0, ped: 0.25, usable: false, age: nil), 0.25, accuracy: 1e-9)
    }

    func testGPSAloneWithoutPedometer() {
        var f = DistanceFusion()
        XCTAssertEqual(step(&f, gps: 0.72, ped: 0), 0.72, accuracy: 1e-9)
    }

    func testNeverTheSumAndNeverDown() {
        var f = DistanceFusion()
        XCTAssertEqual(step(&f, gps: 1.0, ped: 1.1), 1.0, accuracy: 1e-9)
        // A source total that shrinks (pedometer restart) adds nothing.
        XCTAssertEqual(step(&f, gps: 1.0, ped: 0.2, usable: false, age: nil), 1.0, accuracy: 1e-9)
    }

    func testResetAtWorkoutStart() {
        var f = DistanceFusion()
        _ = step(&f, gps: 2.0, ped: 1.9)
        f = DistanceFusion()
        XCTAssertEqual(f.totalKm, 0)
        XCTAssertEqual(step(&f, gps: 0.1, ped: 0.1), 0.1, accuracy: 1e-9)
    }
}
