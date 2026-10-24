import XCTest
@testable import ShuttlXShared

final class SplitCounterTests: XCTestCase {
    func testCrossingTimeIsInterpolated() {
        var c = SplitCounter(unitMetres: SplitCounter.kmMetres)
        XCTAssertFalse(c.update(metres: 900, activeTime: 300).alert)
        // 1000 m sits halfway between 900 m @300 s and 1100 m @340 s.
        let u = c.update(metres: 1100, activeTime: 340)
        XCTAssertTrue(u.alert)
        XCTAssertEqual(u.splits.count, 1)
        XCTAssertEqual(u.splits[0].number, 1)
        XCTAssertEqual(u.splits[0].cumulativeTime, 320, accuracy: 0.001)
        XCTAssertEqual(u.splits[0].splitTime, 320, accuracy: 0.001)
        XCTAssertFalse(u.splits[0].estimated)

        let u2 = c.update(metres: 2000, activeTime: 600)
        XCTAssertEqual(u2.splits.first?.splitTime ?? 0, 280, accuracy: 0.001)
        XCTAssertFalse(c.update(metres: 2000, activeTime: 610).alert, "no new crossing, no alert")
    }

    func testBurstRecordsEverySplitWithOneAlert() {
        var c = SplitCounter(unitMetres: SplitCounter.kmMetres)
        _ = c.update(metres: 500, activeTime: 150)
        // Source switch: the builder reports 2.6 km at once.
        let u = c.update(metres: 2600, activeTime: 780)
        XCTAssertTrue(u.alert)
        XCTAssertEqual(u.splits.map(\.number), [1, 2])
        XCTAssertTrue(u.splits.allSatisfy(\.estimated))
        XCTAssertTrue(u.splits.allSatisfy { $0.splitTime > 0 }, "no 0-second burst splits")
        XCTAssertEqual(u.splits[1].cumulativeTime, 150 + 630 * 1500 / 2100, accuracy: 0.001)
    }

    func testResumeIsSilentOnceThenAlerts() {
        var c = SplitCounter(unitMetres: SplitCounter.kmMetres)
        // Re-seed from the backup's km splits (cumulative times), then silence.
        _ = c.update(metres: 1000, activeTime: 360)
        _ = c.update(metres: 2000, activeTime: 720)
        XCTAssertEqual(c.splits.map(\.splitTime), [360, 360])
        c.silenceNextUpdate()
        // The kill gap's distance lands in the first update after resume.
        let first = c.update(metres: 3400, activeTime: 1300)
        XCTAssertFalse(first.alert)
        XCTAssertEqual(first.splits.count, 1, "still recorded")
        XCTAssertTrue(c.update(metres: 4000, activeTime: 1500).alert)
    }

    func testMiles() {
        var c = SplitCounter(unitMetres: SplitCounter.mileMetres)
        XCTAssertTrue(c.update(metres: 1500, activeTime: 540).splits.isEmpty)
        let u = c.update(metres: 1700, activeTime: 612)
        XCTAssertEqual(u.splits.count, 1)
        XCTAssertEqual(u.splits[0].cumulativeTime, 540 + 72 * 109.344 / 200, accuracy: 0.001)
    }

    func testDistanceDropAndBadInputNeverCross() {
        var c = SplitCounter(unitMetres: SplitCounter.kmMetres)
        _ = c.update(metres: 1200, activeTime: 400)
        XCTAssertTrue(c.update(metres: 900, activeTime: 410).splits.isEmpty)
        XCTAssertTrue(c.update(metres: .nan, activeTime: 420).splits.isEmpty)
        XCTAssertTrue(c.update(metres: 1900, activeTime: 600).splits.isEmpty)
        XCTAssertEqual(c.update(metres: 2100, activeTime: 660).splits.map(\.number), [2])
    }
}
