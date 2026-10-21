import XCTest
@testable import ShuttlXShared

final class ActivityClassifierTests: XCTestCase {
    typealias C = SpeedActivityClassifier

    func testShortWindowGivesNoAnswer() {
        XCTAssertNil(C.classify(speed: 3, cadence: 150, window: 20))
    }

    func testCycling() {
        XCTAssertEqual(C.classify(speed: 8, cadence: 150)?.activity, .cycling)
        XCTAssertEqual(C.classify(speed: 4, cadence: 40)?.activity, .cycling)
        XCTAssertEqual(C.classify(speed: 4, cadence: 170)?.activity, .running)   // fast sprint with steps
    }

    func testRunWalk() {
        XCTAssertEqual(C.classify(speed: 1.3, cadence: 105), .init(activity: .walking, confidence: .high))
        XCTAssertEqual(C.classify(speed: 3.0, cadence: 170), .init(activity: .running, confidence: .high))
        XCTAssertEqual(C.classify(speed: 1.9, cadence: 145)?.activity, .running)
        XCTAssertEqual(C.classify(speed: 1.9, cadence: 145)?.confidence, .low)   // 6.8 km/h band
        XCTAssertEqual(C.classify(speed: 0.1, cadence: 0)?.activity, .stationary)
    }

    func testHysteresis() {
        var h = C.Hysteresis()
        let t = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(h.ingest(.walking, at: t), .walking)
        XCTAssertEqual(h.ingest(.running, at: t + 10), .walking)
        XCTAssertEqual(h.ingest(.running, at: t + 40), .running)           // held 30 s
        XCTAssertEqual(h.ingest(.cycling, at: t + 50), .running)
        XCTAssertEqual(h.ingest(.cycling, at: t + 100), .running)          // only 50 s
        XCTAssertEqual(h.ingest(.cycling, at: t + 110), .cycling)          // 60 s
        XCTAssertEqual(h.ingest(.walking, at: t + 120), .cycling)
        XCTAssertEqual(h.ingest(.cycling, at: t + 125), .cycling)          // blip resets pending
        XCTAssertEqual(h.ingest(.walking, at: t + 130), .cycling)
        XCTAssertEqual(h.ingest(.walking, at: t + 180), .cycling)
        XCTAssertEqual(h.ingest(.walking, at: t + 190), .walking)
    }

    // MARK: Unknown cadence (audit 2026-10)

    func testUnknownCadenceNeedsHighSpeedForCycling() {
        XCTAssertEqual(C.classify(speed: 4, cadence: nil)?.activity, .running)
        XCTAssertEqual(C.classify(speed: 6.4, cadence: nil)?.activity, .running)
        XCTAssertEqual(C.classify(speed: 6.5, cadence: nil)?.activity, .cycling)   // 23.4 km/h
        XCTAssertEqual(C.classify(speed: 4, cadence: 40)?.activity, .cycling)      // cadence verdict
    }

    func testFirstReadingDoesNotCommitCycling() {
        let t = Date(timeIntervalSince1970: 0)
        var h = C.Hysteresis()
        h.ingest(.cycling, at: t)
        XCTAssertNil(h.committed)
        h.ingest(.cycling, at: t + 59)
        XCTAssertNil(h.committed)
        h.ingest(.cycling, at: t + 60)
        XCTAssertEqual(h.committed, .cycling)                                  // held 60 s

        var foot = C.Hysteresis()
        foot.ingest(.walking, at: t)
        XCTAssertEqual(foot.committed, .walking)                               // on foot still commits at once
    }

    func testAverageSpeedNeedsHistoryAndFixes() {
        let now = Date(timeIntervalSince1970: 1_000)
        func pts(every step: Int, for span: Int, speed: Double) -> [RoutePoint] {
            stride(from: span, through: 0, by: -step).map {
                RoutePoint(latitude: 0, longitude: 0, timestamp: now - TimeInterval($0), speed: speed)
            }
        }
        // 1 Hz for 40 s at 6 m/s: 31 fixes inside the 30 s window.
        let r = C.averageSpeed(of: pts(every: 1, for: 40, speed: 6), now: now)
        XCTAssertEqual(r?.fixes, 31)
        XCTAssertEqual(r?.speed ?? 0, 6, accuracy: 0.001)
        // History shorter than the window -> nil.
        XCTAssertNil(C.averageSpeed(of: pts(every: 1, for: 20, speed: 6), now: now))
        // One fix every 7 s (walking pace with a 10 m distance filter): too few fixes.
        XCTAssertNil(C.averageSpeed(of: pts(every: 7, for: 70, speed: 1.4), now: now))
    }

    func testFootFallbackUsesSpeedWhenMotionIsStale() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(C.footFallback(speedVerdict: .running, motionReadingAt: nil, now: now), .running)
        XCTAssertEqual(C.footFallback(speedVerdict: .walking, motionReadingAt: now - 300, now: now), .walking)
        XCTAssertNil(C.footFallback(speedVerdict: .running, motionReadingAt: now - 20, now: now))  // motion re-earns it
        XCTAssertEqual(C.footFallback(speedVerdict: .stationary, motionReadingAt: nil, now: now), .walking)
    }
}
