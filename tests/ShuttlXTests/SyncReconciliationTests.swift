import XCTest

/// Tests the session-reconciliation filtering logic that powers
/// `WatchSyncCoordinator.reconcileSessions` and `PhoneSyncCoordinator.reconcileSessionIDs`.
///
/// The watch receives a set of known session IDs from iOS and re-sends any
/// sessions it holds that aren't in the set. These tests verify the filter
/// produces the correct "missing" subset under all boundary conditions.
final class SyncReconciliationTests: XCTestCase {

    // MARK: - Helpers

    /// Simulates the watch-side filter: given all local session IDs and
    /// the set of IDs iOS claims to know about, return the missing ones.
    private func missingIDs(
        watchSessionIDs: [UUID],
        knownByiOS: [UUID]
    ) -> [UUID] {
        let knownSet = Set(knownByiOS.map { $0.uuidString })
        return watchSessionIDs.filter { !knownSet.contains($0.uuidString) }
    }

    // MARK: - Tests

    func testNoMissingSessionsWhenSetsMatch() {
        let ids = [UUID(), UUID(), UUID()]
        let missing = missingIDs(watchSessionIDs: ids, knownByiOS: ids)
        XCTAssertTrue(missing.isEmpty, "Expected no missing sessions when iOS knows all of them")
    }

    func testAllMissingWhenIOSKnowsNone() {
        let ids = [UUID(), UUID(), UUID()]
        let missing = missingIDs(watchSessionIDs: ids, knownByiOS: [])
        XCTAssertEqual(missing.count, 3, "iOS knowing zero sessions → all 3 should be missing")
        XCTAssertEqual(Set(missing), Set(ids))
    }

    func testPartialOverlap() {
        let shared1 = UUID()
        let shared2 = UUID()
        let watchOnly1 = UUID()
        let watchOnly2 = UUID()
        let iOSExtra = UUID() // iOS-only session; irrelevant to watch filter

        let watchSessions = [shared1, shared2, watchOnly1, watchOnly2]
        let knownByiOS   = [shared1, shared2, iOSExtra]

        let missing = missingIDs(watchSessionIDs: watchSessions, knownByiOS: knownByiOS)

        XCTAssertEqual(missing.count, 2)
        XCTAssertTrue(missing.contains(watchOnly1))
        XCTAssertTrue(missing.contains(watchOnly2))
        XCTAssertFalse(missing.contains(shared1))
        XCTAssertFalse(missing.contains(shared2))
    }

    func testEmptyWatchSessionsProducesNoMissing() {
        let missing = missingIDs(watchSessionIDs: [], knownByiOS: [UUID(), UUID()])
        XCTAssertTrue(missing.isEmpty, "No watch sessions → nothing to report as missing")
    }

    func testSingleMissingSession() {
        let known = UUID()
        let missing = UUID()
        let result = missingIDs(watchSessionIDs: [known, missing], knownByiOS: [known])
        XCTAssertEqual(result, [missing])
    }

    func testUUIDStringRoundtripPreservesIdentity() {
        // Verifies the string-based comparison (as used in WCSession payloads)
        // round-trips correctly and doesn't produce false positives.
        let id = UUID()
        let stringForm = id.uuidString
        let recovered = UUID(uuidString: stringForm)!
        XCTAssertEqual(id, recovered)

        let missing = missingIDs(watchSessionIDs: [id], knownByiOS: [recovered])
        XCTAssertTrue(missing.isEmpty, "Same UUID via string roundtrip should not appear as missing")
    }

    func testLargeSessionSetPerformance() {
        // 500 sessions on watch, iOS knows all but 10 — verify correctness at scale.
        let shared = (0..<490).map { _ in UUID() }
        let watchOnly = (0..<10).map { _ in UUID() }
        let all = shared + watchOnly

        let missing = missingIDs(watchSessionIDs: all, knownByiOS: shared)
        XCTAssertEqual(missing.count, 10)
        XCTAssertEqual(Set(missing), Set(watchOnly))
    }
}
