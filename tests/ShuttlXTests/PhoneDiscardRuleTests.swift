import XCTest
@testable import ShuttlXShared

final class PhoneDiscardRuleTests: XCTestCase {
    typealias R = PhoneDiscardRule
    let now = Date(timeIntervalSince1970: 1_000_000)

    /// Review #1: a watch-started workout (no phone id) must survive a phone Discard.
    func testWatchStartedWorkoutIsNeverDiscarded() {
        XCTAssertEqual(R.decide(phoneSessionId: "P1", sentAt: now, now: now,
                                runningPhoneSessionId: nil, isStarting: false, isActive: true),
                       .ignore(reason: "not the running workout"))
        XCTAssertEqual(R.decide(phoneSessionId: nil, sentAt: now, now: now,
                                runningPhoneSessionId: "P1", isStarting: false, isActive: true),
                       .ignore(reason: "no phoneSessionId"))
    }

    func testMatchingIdDiscards() {
        XCTAssertEqual(R.decide(phoneSessionId: "P1", sentAt: now - 3, now: now,
                                runningPhoneSessionId: "P1", isStarting: false, isActive: true), .apply)
        XCTAssertEqual(R.decide(phoneSessionId: "P2", sentAt: now, now: now,
                                runningPhoneSessionId: "P1", isStarting: false, isActive: true),
                       .ignore(reason: "not the running workout"))
    }

    /// Bug E: Discard right after the phone's start, while the watch is still starting.
    func testEarlyDiscardIsHeld() {
        XCTAssertEqual(R.decide(phoneSessionId: "P1", sentAt: now, now: now,
                                runningPhoneSessionId: "P1", isStarting: true, isActive: false), .hold)
    }

    func testStaleCopyIgnored() {
        XCTAssertEqual(R.decide(phoneSessionId: "P1", sentAt: now - 121, now: now,
                                runningPhoneSessionId: "P1", isStarting: false, isActive: true),
                       .ignore(reason: "stale"))
    }
}
