import XCTest
@testable import ShuttlXShared

final class LimitVerdictTests: XCTestCase {
    func testAllUnder() { XCTAssertEqual(LimitVerdict.percentUnder([100, 110, 125], limit: 125), 100) }
    func testOneAboveNeverReadsAsHundred() {
        let bpm = Array(repeating: 110.0, count: 199) + [140]
        XCTAssertEqual(LimitVerdict.percentUnder(bpm, limit: 125), 99)
    }
    func testQuarterAbove() { XCTAssertEqual(LimitVerdict.percentUnder([100, 100, 100, 130], limit: 125), 75) }
    func testNoReadingsOrLimit() {
        XCTAssertNil(LimitVerdict.percentUnder([], limit: 125))
        XCTAssertNil(LimitVerdict.percentUnder([100], limit: 0))
        XCTAssertNil(LimitVerdict.percentUnder([.nan, 0], limit: 125))
    }
}
