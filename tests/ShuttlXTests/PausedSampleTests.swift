import XCTest
@testable import ShuttlXShared

/// Peak HR during a pause is classified by sample date, not by delivery time.
final class PausedSampleTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Pause 100-160 s. HealthKit delivers every sample 8 s late: the 175 bpm sample
    /// taken at 155 (paused) arrives at 163 (running), the 120 bpm sample at 95
    /// (running) arrives at 103 (paused).
    func testDelayedDeliveryUsesSampleDate() {
        let samples: [(at: Double, bpm: Double)] = [(90, 130), (95, 120), (110, 150), (155, 175), (170, 140)]
        let delay = 8.0
        var closed: [DateInterval] = []
        var openSince: Date?
        var active: [Double] = [], pausedPeak = 0.0
        var oldRuleActive: [Double] = []   // pre-fix rule: "paused at delivery"
        for s in stride(from: 0.0, through: 200, by: 1) {
            let now = t0 + s
            if s == 100 { openSince = now }
            if s == 160, let start = openSince { closed.append(DateInterval(start: start, end: now)); openSince = nil }
            for sample in samples where sample.at + delay == s {
                if openSince == nil { oldRuleActive.append(sample.bpm) }
                if PausedSample.isPaused(t0 + sample.at, closed: closed, openSince: openSince) {
                    pausedPeak = max(pausedPeak, sample.bpm)
                } else {
                    active.append(sample.bpm)
                }
            }
        }
        XCTAssertEqual(active, [130, 120, 140])
        XCTAssertEqual(active.max(), 140)
        XCTAssertEqual(pausedPeak, 175)
        // The old delivery-time rule put the paused 175 into the workout peak.
        XCTAssertEqual(oldRuleActive.max(), 175)
    }

    func testOpenPauseAndBoundaries() {
        let pause = DateInterval(start: t0 + 10, end: t0 + 20)
        XCTAssertFalse(PausedSample.isPaused(t0 + 9, closed: [pause], openSince: nil))
        XCTAssertTrue(PausedSample.isPaused(t0 + 10, closed: [pause], openSince: nil))
        XCTAssertTrue(PausedSample.isPaused(t0 + 20, closed: [pause], openSince: nil))
        XCTAssertFalse(PausedSample.isPaused(t0 + 21, closed: [pause], openSince: nil))
        XCTAssertTrue(PausedSample.isPaused(t0 + 50, closed: [pause], openSince: t0 + 40))
        XCTAssertFalse(PausedSample.isPaused(t0 + 39, closed: [pause], openSince: t0 + 40))
    }
}
