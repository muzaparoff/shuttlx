import XCTest
@testable import ShuttlXShared

/// Watch audit wave 1: heart-limit page hysteresis, 3-2-1 interval clicks, zone reference,
/// alert limits from the resolved limit, lenient sessions.json rewrites.
final class WatchWave1RulesTests: XCTestCase {

    // MARK: Heart-limit page (W3 / 3A)

    func testHeartLimitModeEntersAt90LeavesBelow85() {
        // Limit 130: enter at 117 (90 %), leave below 110.5 (85 %).
        XCTAssertFalse(HeartLimitMode.isOn(hr: 116, limit: 130, wasOn: false))
        XCTAssertTrue(HeartLimitMode.isOn(hr: 117, limit: 130, wasOn: false))
        XCTAssertTrue(HeartLimitMode.isOn(hr: 116, limit: 130, wasOn: true))   // no flicker at 116/117
        XCTAssertTrue(HeartLimitMode.isOn(hr: 111, limit: 130, wasOn: true))
        XCTAssertFalse(HeartLimitMode.isOn(hr: 110, limit: 130, wasOn: true))
    }

    func testHeartLimitModeOffWithoutLimitOrHR() {
        XCTAssertFalse(HeartLimitMode.isOn(hr: 200, limit: nil, wasOn: true))
        XCTAssertFalse(HeartLimitMode.isOn(hr: 0, limit: 130, wasOn: true))
    }

    /// The old rule (hr >= 0.9 * limit, no memory) swapped the page on every sample of 116/117.
    func testAlternatingEdgeSamplesStayInMode() {
        var on = false
        var swaps = 0
        for hr in [117, 116, 117, 116, 117, 116] {
            let next = HeartLimitMode.isOn(hr: hr, limit: 130, wasOn: on)
            if next != on { swaps += 1 }
            on = next
        }
        XCTAssertEqual(swaps, 1)
    }

    // MARK: 3-2-1 clicks (W2)

    func testCountdownClicksAtThreeTwoOne() {
        var clicks: [Double] = []
        var previous: Double = 10
        for r in stride(from: 9.0, through: 0, by: -1) {
            if StepCountdownCue.shouldClick(previous: previous, remaining: r) { clicks.append(r) }
            previous = r
        }
        XCTAssertEqual(clicks, [3, 2, 1])
    }

    func testCountdownSkippedTicksClickOnce() {
        XCTAssertTrue(StepCountdownCue.shouldClick(previous: 10, remaining: 2))
        XCTAssertFalse(StepCountdownCue.shouldClick(previous: 5, remaining: 4))
        XCTAssertFalse(StepCountdownCue.shouldClick(previous: 1, remaining: 0))   // the step change has its own haptic
        XCTAssertFalse(StepCountdownCue.shouldClick(previous: 2, remaining: 2))
        // New step shorter than 3 s: starts at 2, first beat is 1.
        XCTAssertTrue(StepCountdownCue.shouldClick(previous: 2, remaining: 1))
    }

    // MARK: Zone reference = resolved limit, no 190 fallback (algorithms §6 pick A)

    func testZoneWordUsesSyncedLimitElseWatchAgeElseNothing() {
        let synced = HeartSafetySettings(upperLimit: 130)
        XCTAssertEqual(synced.effectiveUpperLimit(age: 30), 130)          // the synced limit wins
        XCTAssertEqual(synced.zoneWord(hr: 120, age: 30), "HARD")
        let unsynced = HeartSafetySettings()
        XCTAssertEqual(unsynced.effectiveUpperLimit(age: 65), 132)        // 0.85 x (220 - 65)
        XCTAssertEqual(unsynced.zoneWord(hr: 120, age: 65), "HARD")
        // No limit, no age: no word (the old 190 fallback said STEADY up to 170 bpm).
        XCTAssertNil(unsynced.effectiveUpperLimit(age: nil))
        XCTAssertNil(unsynced.zoneWord(hr: 165, age: nil))
        XCTAssertNil(HeartSafetySettings(upperLimit: 130, effortOnly: true).zoneWord(hr: 120, age: 65))
    }

    func testAlertLimitsMatchTheScreenLimit() {
        XCTAssertEqual(HeartAlertLimits(HeartSafetySettings(upperLimit: 130), age: 30).upper, 130)
        XCTAssertEqual(HeartAlertLimits(HeartSafetySettings(), age: 65).upper, 132)
        XCTAssertNil(HeartAlertLimits(HeartSafetySettings(), age: nil).upper)
        XCTAssertNil(HeartAlertLimits(HeartSafetySettings(effortOnly: true), age: 65).upper)
    }

    // MARK: sessions.json rewrites (watch effort + purge)

    struct Rec: Codable, Identifiable, Equatable { let id: UUID; var n: Int }

    private func fileWithOneBadRecord(_ recs: [Rec]) throws -> Data {
        var json = String(data: try JSONEncoder().encode(recs), encoding: .utf8)!
        json.removeLast()
        json += ",{\"id\":\"not-a-uuid\"}]"
        return Data(json.utf8)
    }

    func testEffortUpdateSurvivesOneBadRecord() throws {
        let a = Rec(id: UUID(), n: 1), b = Rec(id: UUID(), n: 2)
        let data = try fileWithOneBadRecord([a, b])
        XCTAssertThrowsError(try JSONDecoder().decode([Rec].self, from: data))   // the old strict read failed here
        let plan: (elements: [Rec], backupFirst: Bool)? = StoreRewrite.update(existing: data) { recs in
            guard let i = recs.firstIndex(where: { $0.id == b.id }) else { return false }
            recs[i].n = 9
            return true
        }
        XCTAssertEqual(plan?.elements, [a, Rec(id: b.id, n: 9)])
        XCTAssertEqual(plan?.backupFirst, true)
    }

    func testEffortUpdateLeavesFileAloneWhenNothingChangesOrUnreadable() throws {
        let data = try JSONEncoder().encode([Rec(id: UUID(), n: 1)])
        let none: (elements: [Rec], backupFirst: Bool)? = StoreRewrite.update(existing: data) { _ in false }
        XCTAssertNil(none)
        let broken: (elements: [Rec], backupFirst: Bool)? = StoreRewrite.update(existing: Data("{".utf8)) { _ in true }
        XCTAssertNil(broken)
    }

    /// The old purge decoded strictly and DELETED sessions.json when one record was bad,
    /// taking the sessions it had to keep with it.
    func testPurgeWithOneBadRecordKeepsNewerSessions() throws {
        let old = Rec(id: UUID(), n: 1), new = Rec(id: UUID(), n: 50)
        let plan: StoreRewrite.PurgePlan<Rec> = StoreRewrite.purge(existing: try fileWithOneBadRecord([old, new])) { $0.n < 10 }
        guard case .write(let kept, let removed) = plan else { return XCTFail("file must not be removed") }
        XCTAssertEqual(kept, [new])
        XCTAssertEqual(removed, [old])
    }

    func testPurgeRemovesWhollyUnreadableFile() {
        let plan: StoreRewrite.PurgePlan<Rec> = StoreRewrite.purge(existing: Data("not json".utf8)) { _ in true }
        guard case .removeFile = plan else { return XCTFail() }
    }
}
