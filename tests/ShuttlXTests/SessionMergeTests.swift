import XCTest
@testable import ShuttlXShared

final class SessionMergeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func item(_ id: UUID = UUID(), start: TimeInterval = 0, minutes: Double = 30,
                      imported: Bool = false, placeholder: Bool = false) -> SessionMerge.Item {
        .init(id: id, start: t0.addingTimeInterval(start), end: t0.addingTimeInterval(start + minutes * 60),
              importedFromHealth: imported, isPhonePlaceholder: placeholder)
    }

    // Task 4: a late watch session replaces its Health-imported copy (same id).
    func testWatchSessionReplacesImportedCopyWithSameId() {
        let id = UUID()
        XCTAssertTrue(SessionMerge.replaces(incoming: item(id), existing: item(id, imported: true)))
    }

    func testWatchSessionDoesNotReplaceItself() {
        let id = UUID()
        XCTAssertFalse(SessionMerge.replaces(incoming: item(id), existing: item(id)))
    }

    func testHealthImportNeverReplaces() {
        let id = UUID()
        XCTAssertFalse(SessionMerge.replaces(incoming: item(id, imported: true), existing: item(id, imported: true)))
        XCTAssertFalse(SessionMerge.replaces(incoming: item(imported: true), existing: item(placeholder: true)))
    }

    // Task 1: the phone's own record is replaced by the watch session of the same workout.
    func testWatchSessionReplacesPhonePlaceholderOfSameWorkout() {
        let phone = item(start: 5, minutes: 29, placeholder: true)
        XCTAssertTrue(SessionMerge.replaces(incoming: item(), existing: phone))
    }

    func testDifferentWorkoutKeepsPlaceholder() {
        let phone = item(start: 0, minutes: 30, placeholder: true)
        XCTAssertFalse(SessionMerge.replaces(incoming: item(start: 3 * 3600), existing: phone))
        XCTAssertFalse(SessionMerge.replaces(incoming: item(start: 28 * 60, minutes: 30), existing: phone)) // 2 of 30 min overlap
    }

    func testOrdinaryExistingSessionIsNeverReplacedByOverlap() {
        XCTAssertFalse(SessionMerge.replaces(incoming: item(), existing: item(start: 1)))
    }

    func testPhoneSessionIsCoveredByAWatchSession() {
        let phone = item(minutes: 30, placeholder: true)
        XCTAssertTrue(SessionMerge.isCovered(phone, by: [item(start: 2)]))
        XCTAssertTrue(SessionMerge.isCovered(phone, by: [item(start: 2, imported: true)]))
        XCTAssertFalse(SessionMerge.isCovered(phone, by: [item(start: 5 * 3600)]))
        XCTAssertFalse(SessionMerge.isCovered(phone, by: [item(start: 2, placeholder: true)]))
        XCTAssertFalse(SessionMerge.isCovered(phone, by: []))
    }

    func testEffortIsCarriedOver() {
        XCTAssertEqual(SessionMerge.carriedEffort(incoming: nil, replaced: [7]), 7)
        XCTAssertEqual(SessionMerge.carriedEffort(incoming: 4, replaced: [7]), 4)
        XCTAssertNil(SessionMerge.carriedEffort(incoming: nil, replaced: [nil]))
        XCTAssertNil(SessionMerge.carriedEffort(incoming: nil, replaced: []))
    }
}
