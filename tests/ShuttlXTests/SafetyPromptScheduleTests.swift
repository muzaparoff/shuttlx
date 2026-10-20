import XCTest
@testable import ShuttlXShared

final class SafetyPromptScheduleTests: XCTestCase {

    func testPromptsAt3h50ThenTimesOutAfter5Minutes() {
        var s = SafetyPromptSchedule()
        XCTAssertEqual(s.evaluate(activeElapsed: 13_799), .none)
        XCTAssertEqual(s.evaluate(activeElapsed: 13_800), .showPrompt)
        XCTAssertTrue(s.isPromptShowing)
        // Showing: no second showPrompt, no auto-end before 5 min.
        XCTAssertEqual(s.evaluate(activeElapsed: 13_801), .none)
        XCTAssertEqual(s.evaluate(activeElapsed: 14_099), .none)
        XCTAssertEqual(s.evaluate(activeElapsed: 14_100), .autoEnd)
    }

    func testContinueRearmsOneHourLater() {
        var s = SafetyPromptSchedule()
        XCTAssertEqual(s.evaluate(activeElapsed: 13_800), .showPrompt)
        s.acknowledge(activeElapsed: 13_860)
        XCTAssertFalse(s.isPromptShowing)
        XCTAssertEqual(s.evaluate(activeElapsed: 14_200), .none) // past the old timeout: no auto-end
        XCTAssertEqual(s.evaluate(activeElapsed: 17_459), .none)
        XCTAssertEqual(s.evaluate(activeElapsed: 17_460), .showPrompt)
    }

    /// Active elapsed does not advance while paused, so the timeout freezes.
    func testTimeoutMeasuredInActiveTime() {
        var s = SafetyPromptSchedule()
        XCTAssertEqual(s.evaluate(activeElapsed: 13_800), .showPrompt)
        // Paused for an hour: ticks stop, elapsed stays put on resume.
        XCTAssertEqual(s.evaluate(activeElapsed: 13_810), .none)
    }

    func testRecoveredPastThresholdPromptsImmediately() {
        var s = SafetyPromptSchedule()
        XCTAssertEqual(s.evaluate(activeElapsed: 20_000), .showPrompt)
    }
}
