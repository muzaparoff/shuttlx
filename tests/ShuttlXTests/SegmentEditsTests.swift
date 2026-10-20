import XCTest
@testable import ShuttlXShared

final class SegmentEditsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private let sid = UUID()

    /// walk 0-600s, run 600-3000s, walk 3000-3600s
    private func raw() -> [ActivitySegment] {
        func seg(_ a: DetectedActivity, _ s: Double, _ e: Double, km: Double, hr: Double, cal: Double) -> ActivitySegment {
            ActivitySegment(activityType: a, startDate: t0.addingTimeInterval(s), endDate: t0.addingTimeInterval(e),
                            steps: Int(e - s), distance: km, averageHeartRate: hr, estimatedCalories: cal, activeEnergyCalories: cal)
        }
        return [seg(.walking, 0, 600, km: 1, hr: 100, cal: 40),
                seg(.running, 600, 3000, km: 8, hr: 150, cal: 400),
                seg(.walking, 3000, 3600, km: 1, hr: 110, cal: 60)]
    }

    func testNoEditsIsIdentity() {
        let r = raw()
        XCTAssertEqual(SegmentEdits().apply(to: r, sessionID: sid), r)
    }

    func testLegacyV1FileDecodesAsTypes() throws {
        let r = raw()
        let json = #"{"\#(r[1].id.uuidString)":"walking"}"#.data(using: .utf8)!
        let e = try SegmentEdits.decode(json)
        XCTAssertEqual(e.apply(to: r, sessionID: sid)[1].activityType, .walking)
        let round = try SegmentEdits.decode(JSONEncoder().encode(e))
        XCTAssertEqual(round, e)
    }

    func testRestOverrideZeroesCaloriesButNotTheSource() {
        let r = raw()
        let e = SegmentEdits().settingType(.stationary, partID: r[1].id, parts: r, sessionID: sid)
        let eff = e.apply(to: r, sessionID: sid)
        XCTAssertEqual(eff[1].activityType, .stationary)
        XCTAssertEqual(eff[1].activeEnergyCalories, 0)
        XCTAssertEqual(eff[1].estimatedCalories, 0)
        XCTAssertEqual(r[1].activeEnergyCalories, 400)
        XCTAssertEqual(SegmentEdits.caloriesRemoved(raw: r, effective: eff), 400)
    }

    func testSplitApportionsAndKeepsTotals() throws {
        let r = raw()
        let at = t0.addingTimeInterval(1800) // middle of the run
        let e = try XCTUnwrap(SegmentEdits().splitting(partID: r[1].id, at: at, parts: r, sessionID: sid))
        let eff = e.apply(to: r, sessionID: sid)
        XCTAssertEqual(eff.count, 4)
        XCTAssertEqual(eff[1].endDate, at)
        XCTAssertEqual(eff[2].startDate, at)
        XCTAssertEqual(eff[1].distance ?? 0, 1200.0 / 2400 * 8, accuracy: 0.001)
        XCTAssertEqual(eff[1].averageHeartRate ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(eff.compactMap(\.distance).reduce(0, +), 10, accuracy: 0.001)
        XCTAssertEqual(eff.reduce(0) { $0 + SegmentEdits.calories($1) }, 500, accuracy: 0.001)
        XCTAssertEqual(eff[0].id, r[0].id)
    }

    func testSplitTooCloseToEdgeRefused() {
        let r = raw()
        XCTAssertNil(SegmentEdits().splitting(partID: r[1].id, at: t0.addingTimeInterval(610), parts: r, sessionID: sid))
    }

    func testMergeJoinsNeighboursWeightedHR() throws {
        let r = raw()
        let e = try XCTUnwrap(SegmentEdits().merging(partID: r[0].id, parts: r, sessionID: sid))
        let eff = e.apply(to: r, sessionID: sid)
        XCTAssertEqual(eff.count, 2)
        XCTAssertEqual(eff[0].activityType, .walking)          // keeps the first part's type
        XCTAssertEqual(eff[0].duration, 3000)
        XCTAssertEqual(eff[0].distance ?? 0, 9, accuracy: 0.001)
        XCTAssertEqual(eff[0].averageHeartRate ?? 0, (100 * 600 + 150 * 2400) / 3000.0, accuracy: 0.001)
        XCTAssertNil(e.merging(partID: eff[1].id, parts: eff, sessionID: sid)) // last part
    }

    func testTypeChangeAfterSplitEditsThePartition() throws {
        let r = raw()
        var e = try XCTUnwrap(SegmentEdits().splitting(partID: r[1].id, at: t0.addingTimeInterval(1800), parts: r, sessionID: sid))
        let parts = e.apply(to: r, sessionID: sid)
        e = e.settingType(.stationary, partID: parts[2].id, parts: parts, sessionID: sid)
        let eff = e.apply(to: r, sessionID: sid)
        XCTAssertEqual(eff[2].activityType, .stationary)
        XCTAssertEqual(eff[2].activeEnergyCalories, 0)
        XCTAssertEqual(eff[1].activityType, .running)
        XCTAssertEqual(try SegmentEdits.decode(JSONEncoder().encode(e)), e)
    }
}
