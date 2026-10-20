import XCTest
@testable import ShuttlXShared

final class ActivityClassifierTests: XCTestCase {
    typealias C = SpeedActivityClassifier

    func testShortWindowGivesNoAnswer() {
        XCTAssertNil(C.classify(speed: 3, cadence: 150, window: 20))
    }

    func testCycling() {
        XCTAssertEqual(C.classify(speed: 8, cadence: 150)?.activity, .cycling)
        XCTAssertEqual(C.classify(speed: 4, cadence: nil)?.activity, .cycling)
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
}
