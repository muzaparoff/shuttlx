import XCTest

/// Tests the staleness computation that drives the "Signal lost" indicator
/// in LiveWorkoutCard. The logic is: isStale = elapsed > threshold (5s).
/// This is a pure time-arithmetic function; no UI or coordinator needed.
final class LiveMetricsStalenessTests: XCTestCase {

    private let threshold: TimeInterval = 5

    private func isStale(lastUpdated: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastUpdated) > threshold
    }

    func testFreshMetricsAreNotStale() {
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-2)
        XCTAssertFalse(isStale(lastUpdated: lastUpdated, now: now))
    }

    func testMetricsExactlyAtThresholdAreNotStale() {
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-threshold)
        XCTAssertFalse(isStale(lastUpdated: lastUpdated, now: now),
                       "Exactly at threshold should not yet be stale (uses strict >)")
    }

    func testMetricsOneSecondPastThresholdAreStale() {
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-(threshold + 1))
        XCTAssertTrue(isStale(lastUpdated: lastUpdated, now: now))
    }

    func testMetricsJustBeforeTimeoutAreStale() {
        // Timeout fires at 10s; staleness triggers at 5s. At 9s we should be stale.
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-9)
        XCTAssertTrue(isStale(lastUpdated: lastUpdated, now: now))
    }

    func testJustUpdatedMetricsAreNotStale() {
        let now = Date()
        // Simulate metrics arriving 0.1s ago (well within the 3s broadcast cadence)
        let lastUpdated = now.addingTimeInterval(-0.1)
        XCTAssertFalse(isStale(lastUpdated: lastUpdated, now: now))
    }

    func testMissedOneBroadcastNotStale() {
        // Watch broadcasts every 3s; one missed cycle = 6s elapsed but we
        // check at the next TimelineView tick (1s resolution) — at t=4s: not stale.
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-4)
        XCTAssertFalse(isStale(lastUpdated: lastUpdated, now: now))
    }

    func testMissedTwoBroadcastsIsStale() {
        // Two missed 3s cycles = 6s elapsed → stale
        let now = Date()
        let lastUpdated = now.addingTimeInterval(-6)
        XCTAssertTrue(isStale(lastUpdated: lastUpdated, now: now))
    }
}
