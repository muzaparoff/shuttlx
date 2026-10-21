import XCTest
@testable import ShuttlXShared

final class WatchLinkRulesTests: XCTestCase {
    func testStartedReplyCarriesWatchSessionId() {
        let r = WatchLinkRules.startReply(["action": "workoutStarted", "phoneSessionId": "P1", "sessionId": "W1"], expecting: "P1")
        XCTAssertEqual(r, .started(watchSessionId: "W1"))
    }

    func testIgnoredReply() {
        XCTAssertEqual(WatchLinkRules.startReply(["action": "workoutStartIgnored", "phoneSessionId": "P1"], expecting: "P1"), .ignored)
    }

    func testOtherPhoneIdOrPlainWatchStartIsNotAReply() {
        XCTAssertNil(WatchLinkRules.startReply(["action": "workoutStarted", "phoneSessionId": "OLD"], expecting: "P1"))
        // A watch-originated start has no phoneSessionId and must never link the phone.
        XCTAssertNil(WatchLinkRules.startReply(["action": "workoutStarted", "activityType": "running"], expecting: "P1"))
    }

    func testStopOfAnotherWatchWorkoutIsStale() {
        XCTAssertTrue(WatchLinkRules.isStaleStop(stopSessionId: "OLD", currentWatchSessionId: "NEW", sentAt: nil, workoutStart: nil))
        XCTAssertFalse(WatchLinkRules.isStaleStop(stopSessionId: "NEW", currentWatchSessionId: "NEW", sentAt: nil, workoutStart: nil))
    }

    func testStopWithoutIdFallsBackToTimestamp() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(WatchLinkRules.isStaleStop(stopSessionId: nil, currentWatchSessionId: "NEW", sentAt: 900, workoutStart: start))
        XCTAssertFalse(WatchLinkRules.isStaleStop(stopSessionId: nil, currentWatchSessionId: "NEW", sentAt: 1_100, workoutStart: start))
        // Old build, nothing to compare: behave as before.
        XCTAssertFalse(WatchLinkRules.isStaleStop(stopSessionId: nil, currentWatchSessionId: nil, sentAt: nil, workoutStart: nil))
    }

    func testLateStartedAnswerStillLinks() {
        var h = WatchLinkRules.StartHandshake(phoneSessionId: "P1")
        XCTAssertTrue(h.timeout(), "first timeout reports not linked")
        XCTAssertFalse(h.timeout())
        XCTAssertEqual(h.receive(["action": "workoutStarted", "phoneSessionId": "P1", "sessionId": "W1"]), .started(watchSessionId: "W1"))
    }

    func testDuplicateAnswerIsDropped() {
        var h = WatchLinkRules.StartHandshake(phoneSessionId: "P1")
        let msg: [String: Any] = ["action": "workoutStarted", "phoneSessionId": "P1", "sessionId": "W1"]
        XCTAssertNotNil(h.receive(msg))
        XCTAssertNil(h.receive(msg), "same answer on the second channel")
        XCTAssertFalse(h.timeout(), "no timeout report after an answer")
    }

    func testAnswerForAnotherStartIsIgnored() {
        var h = WatchLinkRules.StartHandshake(phoneSessionId: "P2")
        XCTAssertNil(h.receive(["action": "workoutStarted", "phoneSessionId": "P1", "sessionId": "W1"]))
        XCTAssertEqual(h.receive(["action": "workoutStartIgnored", "phoneSessionId": "P2"]), .ignored)
    }
}
