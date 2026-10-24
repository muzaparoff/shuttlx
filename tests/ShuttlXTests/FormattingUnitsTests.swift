import XCTest
@testable import ShuttlXShared

final class FormattingUnitsTests: XCTestCase {
    func testResolveStoredWinsOverLocale() {
        let us = Locale(identifier: "en_US"), de = Locale(identifier: "de_DE")
        XCTAssertEqual(DistanceUnit.resolve(stored: "km", locale: us), .km)
        XCTAssertEqual(DistanceUnit.resolve(stored: "mi", locale: de), .mi)
    }

    func testResolveAutoFollowsRegion() {
        XCTAssertEqual(DistanceUnit.resolve(stored: nil, locale: Locale(identifier: "en_US")), .mi)
        XCTAssertEqual(DistanceUnit.resolve(stored: nil, locale: Locale(identifier: "de_DE")), .km)
        XCTAssertEqual(DistanceUnit.resolve(stored: "bogus", locale: Locale(identifier: "de_DE")), .km)
    }

    func testDistance() {
        XCTAssertEqual(FormattingUtils.formatDistance(2.1, unit: .km), "2.10 km")
        XCTAssertEqual(FormattingUtils.formatDistance(0.45, unit: .km), "450 m")
        XCTAssertEqual(FormattingUtils.formatDistance(5, unit: .mi), "3.11 mi")
        XCTAssertEqual(FormattingUtils.formatDistanceValue(10, unit: .mi), "6.2")
    }

    func testPace() {
        XCTAssertEqual(FormattingUtils.formatPaceWithUnit(330, unit: .km), "5'30\"/km")
        // 6:00/km = 9:39.6/mi
        XCTAssertEqual(FormattingUtils.formatPace(360, unit: .mi), "9'39\"")
        XCTAssertEqual(FormattingUtils.formatPaceWithUnit(nil, unit: .mi), "--'--\"/mi")
    }

    func testSpeed() {
        XCTAssertEqual(FormattingUtils.formatSpeed(metersPerSecond: 5, unit: .km), "18.0 km/h")
        XCTAssertEqual(FormattingUtils.formatSpeed(metersPerSecond: 5, unit: .mi), "11.2 mph")
    }

    func testSplitRowsKmAsStoredWithPartialTail() {
        let rows = FormattingUtils.splitRows(splitTimes: [360, 350, 340], totalKm: 3.42, totalDuration: 1_150, unit: .km)
        XCTAssertEqual(rows.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(rows.prefix(3).map(\.time), [360, 350, 340])
        XCTAssertTrue(rows[3].isPartial)
        XCTAssertEqual(rows[3].time, 100, accuracy: 0.001)
        XCTAssertEqual(rows[3].distance, 0.42, accuracy: 0.001)
    }

    func testSplitRowsNoTailWhenDistanceUnknownOrTiny() {
        XCTAssertEqual(FormattingUtils.splitRows(splitTimes: [300, 300], totalKm: nil, totalDuration: 700, unit: .km).count, 2)
        XCTAssertEqual(FormattingUtils.splitRows(splitTimes: [300, 300], totalKm: 2.05, totalDuration: 620, unit: .km).count, 2)
        XCTAssertTrue(FormattingUtils.splitRows(splitTimes: [], totalKm: 2, totalDuration: 600, unit: .mi).isEmpty)
    }

    func testSplitRowsMilesInterpolateInsideKm() {
        // Constant 6:00/km over 5 km: a mile is 1.609344 km = 579.4 s, 3 whole miles (4.83 km), tail 0.17 mi.
        let rows = FormattingUtils.splitRows(splitTimes: Array(repeating: 360, count: 5), totalKm: 5, totalDuration: 1_800, unit: .mi)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].time, 579.36, accuracy: 0.05)
        XCTAssertEqual(rows[2].time, 579.36, accuracy: 0.05)
        XCTAssertTrue(rows[3].isPartial)
        XCTAssertEqual(rows[3].distance, 5 / 1.609344 - 3, accuracy: 0.001)
        XCTAssertEqual(rows[3].pace, 579.36, accuracy: 0.5)
    }
}
