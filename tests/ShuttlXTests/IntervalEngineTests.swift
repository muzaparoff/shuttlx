import XCTest
@testable import ShuttlXShared

/// Records every haptic the engine fires — useful for asserting the right
/// audio-tactile cue lands on each transition without touching UIKit/WatchKit.
@MainActor
private final class TestHapticPlayer: HapticPlayer, @unchecked Sendable {
    private(set) var played: [HapticKind] = []
    nonisolated init() {}
    func play(_ kind: HapticKind) { played.append(kind) }
}

private func warmup(_ duration: TimeInterval) -> IntervalStepDescriptor {
    IntervalStepDescriptor(type: .warmup, label: "Warmup", duration: duration)
}
private func work(_ duration: TimeInterval) -> IntervalStepDescriptor {
    IntervalStepDescriptor(type: .work, label: "Run", duration: duration)
}
private func rest(_ duration: TimeInterval) -> IntervalStepDescriptor {
    IntervalStepDescriptor(type: .rest, label: "Walk", duration: duration)
}

@MainActor
final class IntervalEngineTests: XCTestCase {

    // Configure populates the first step and total count.
    func testConfigure_PopulatesFirstStep() {
        let engine = IntervalEngine(haptics: nil)
        engine.configure(steps: [work(60), rest(30), work(60)], templateName: "T", templateID: nil)
        XCTAssertEqual(engine.totalStepsCount, 3)
        XCTAssertEqual(engine.currentStepIndex, 0)
        XCTAssertEqual(engine.currentStepTimeRemaining, 60)
        XCTAssertEqual(engine.currentStep?.type, .work)
        XCTAssertEqual(engine.nextStep?.type, .rest)
        XCTAssertFalse(engine.isComplete)
    }

    // Empty step list is a no-op safety net (we don't crash on it).
    func testConfigure_EmptySteps_DoesNotCrash() {
        let engine = IntervalEngine(haptics: nil)
        engine.configure(steps: [], templateName: "", templateID: nil)
        XCTAssertEqual(engine.totalStepsCount, 0)
        XCTAssertNil(engine.currentStep)
        XCTAssertEqual(engine.currentStepTimeRemaining, 0)
        // Calling tick on an empty engine should not crash and should leave it idle.
        engine.tick(heartRate: 0, distance: 0)
        XCTAssertEqual(engine.currentStepIndex, 0)
        XCTAssertFalse(engine.isComplete)
    }

    // Each tick decrements time remaining by 1 second.
    func testTick_DecrementsTimeRemaining() {
        let engine = IntervalEngine(haptics: nil)
        engine.configure(steps: [work(10)], templateName: "T", templateID: nil)
        XCTAssertEqual(engine.currentStepTimeRemaining, 10)
        engine.tick(heartRate: 0, distance: 0)
        XCTAssertEqual(engine.currentStepTimeRemaining, 9)
        engine.tick(heartRate: 0, distance: 0)
        XCTAssertEqual(engine.currentStepTimeRemaining, 8)
    }

    // The +5s countdown beat fires exactly once per step (the tick that lands
    // currentStepTimeRemaining == 5).
    func testCountdownTick_FiresAtFiveSecondsRemaining() {
        let h = TestHapticPlayer()
        let engine = IntervalEngine(haptics: h)
        engine.configure(steps: [work(8)], templateName: "T", templateID: nil)
        // 3 ticks → time = 5 → countdownTick fires.
        engine.tick(heartRate: 0, distance: 0)
        engine.tick(heartRate: 0, distance: 0)
        engine.tick(heartRate: 0, distance: 0)
        XCTAssertEqual(engine.currentStepTimeRemaining, 5)
        XCTAssertEqual(h.played.filter { $0 == .countdownTick }.count, 1)
    }

    // Step transition: when time hits 0, completeCurrentStep records a result
    // and advanceToNextStep fires the appropriate haptic for the NEXT step's type.
    func testStepTransition_FiresWorkStartHapticForWorkStep() {
        let h = TestHapticPlayer()
        let engine = IntervalEngine(haptics: h)
        engine.configure(steps: [warmup(1), work(60)], templateName: "T", templateID: nil)
        // 1 tick → warmup completes, next step (work) starts.
        engine.tick(heartRate: 130, distance: 0)
        XCTAssertEqual(engine.currentStepIndex, 1)
        XCTAssertEqual(engine.currentStep?.type, .work)
        XCTAssertTrue(h.played.contains(.workStart),
                      "Entering a .work step should fire .workStart")
    }

    func testStepTransition_FiresRestStartHapticForRestStep() {
        let h = TestHapticPlayer()
        let engine = IntervalEngine(haptics: h)
        engine.configure(steps: [work(1), rest(30)], templateName: "T", templateID: nil)
        engine.tick(heartRate: 150, distance: 0)
        XCTAssertEqual(engine.currentStep?.type, .rest)
        XCTAssertTrue(h.played.contains(.restStart))
    }

    // The final step ends → isComplete = true, .complete haptic fires.
    func testFinalStep_MarksComplete_AndPlaysCompleteHaptic() {
        let h = TestHapticPlayer()
        let engine = IntervalEngine(haptics: h)
        engine.configure(steps: [work(1)], templateName: "T", templateID: nil)
        engine.tick(heartRate: 150, distance: 0)
        XCTAssertTrue(engine.isComplete)
        XCTAssertEqual(engine.currentStepTimeRemaining, 0)
        XCTAssertNil(engine.currentStep)
        XCTAssertEqual(h.played.last, .complete)
    }

    // stop() flushes any in-flight step and returns all accumulated results.
    func testStop_ReturnsAllResults() {
        let engine = IntervalEngine(haptics: nil)
        engine.configure(steps: [work(60), rest(30)], templateName: "Five-K", templateID: nil)
        // 30 ticks of work step (mid-step stop)
        for _ in 0..<30 {
            engine.tick(heartRate: 150, distance: 0)
        }
        let result = engine.stop(finalDistance: 1500)
        XCTAssertEqual(result.templateName, "Five-K")
        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].intervalType, .work)
        XCTAssertEqual(result.results[0].actualDuration, 30)
    }

    // HR samples collected during a step contribute to its averageHeartRate.
    func testStop_ComputesAverageHRPerStep() {
        let engine = IntervalEngine(haptics: nil)
        engine.configure(steps: [work(3)], templateName: "T", templateID: nil)
        engine.tick(heartRate: 140, distance: 0)
        engine.tick(heartRate: 150, distance: 0)
        engine.tick(heartRate: 160, distance: 0)
        // Step completes on the third tick (duration 3 → 2 → 1 → 0).
        let result = engine.stop(finalDistance: 0)
        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].averageHeartRate ?? 0, 150, accuracy: 0.1)
    }
}
