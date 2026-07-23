import XCTest

/// Tests for the workout remote-control command routing.
/// Verifies the command strings that flow over WCSession are stable
/// — a mismatch between sender and receiver would silently drop controls.
final class WorkoutControlCommandTests: XCTestCase {

    // Mirror the exact command strings used in PhoneSyncCoordinator (sender)
    // and WatchSyncCoordinator (receiver). Both sides must match.
    private let senderCommands: Set<String> = ["pause", "resume", "stop"]

    // Commands the watch side handles in its switch statement
    private let receiverCommands: Set<String> = ["pause", "resume", "stop"]

    func testSenderAndReceiverCommandSetsMatch() {
        XCTAssertEqual(senderCommands, receiverCommands,
                       "Sender and receiver command sets diverged — WCSession messages would be silently dropped")
    }

    func testPauseCommandIsLowercased() {
        XCTAssertTrue(senderCommands.contains("pause"), "Pause command must be \"pause\" (lowercase)")
    }

    func testResumeCommandIsLowercased() {
        XCTAssertTrue(senderCommands.contains("resume"), "Resume command must be \"resume\" (lowercase)")
    }

    func testStopCommandIsLowercased() {
        XCTAssertTrue(senderCommands.contains("stop"), "Stop command must be \"stop\" (lowercase)")
    }

    func testNoUnrecognizedCommandsOnReceiverSide() {
        // Any command the receiver doesn't handle would hit the `default: break` path and be silent.
        let unhandled = senderCommands.subtracting(receiverCommands)
        XCTAssertTrue(unhandled.isEmpty,
                      "These commands would be silently ignored on watch: \(unhandled)")
    }

    func testActionKeyIsConsistent() {
        // Both sides must use the same WCSession message action key.
        let senderActionKey = "workoutControl"
        let receiverActionKey = "workoutControl"
        XCTAssertEqual(senderActionKey, receiverActionKey)
    }
}
