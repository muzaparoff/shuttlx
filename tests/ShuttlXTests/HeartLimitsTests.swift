import XCTest
@testable import ShuttlXShared

final class HeartLimitsTests: XCTestCase {
    /// CLINICAL SIGN-OFF TABLE. estimate = round(0.85 * (220 - age) [* 0.81 on a beta-blocker]).
    func testEstimateTable() {
        let table: [(age: Int, none: Int, beta: Int)] = [
            (40, 153, 124),   // 180 -> 153.00 ; 145.8 -> 123.93
            (55, 140, 114),   // 165 -> 140.25 ; 133.65 -> 113.60
            (70, 128, 103),   // 150 -> 127.50 ; 121.5 -> 103.28
        ]
        for row in table {
            XCTAssertEqual(HeartLimits.estimate(age: row.age, betaBlocker: nil), row.none, "age \(row.age)")
            XCTAssertEqual(HeartLimits.estimate(age: row.age, betaBlocker: false), row.none, "age \(row.age)")
            XCTAssertEqual(HeartLimits.estimate(age: row.age, betaBlocker: true), row.beta, "age \(row.age) beta")
        }
    }

    func testEstimateNeedsAValidAge() {
        XCTAssertNil(HeartLimits.estimate(age: nil, betaBlocker: nil))
        XCTAssertNil(HeartLimits.estimate(age: 9, betaBlocker: nil))
        XCTAssertNil(HeartLimits.estimate(age: 111, betaBlocker: nil))
        XCTAssertNotNil(HeartLimits.estimate(age: 10, betaBlocker: nil))
        XCTAssertNotNil(HeartLimits.estimate(age: 110, betaBlocker: true))
    }

    /// The estimate is always inside the range a user could type, so it can be shown and re-typed.
    func testEstimateStaysInsideUpperRange() {
        for age in HeartLimits.ageRange {
            for beta in [false, true] {
                let e = HeartLimits.estimate(age: age, betaBlocker: beta)
                XCTAssertTrue(e.map(HeartLimits.upperRange.contains) ?? false, "age \(age) beta \(beta) -> \(String(describing: e))")
            }
        }
    }

    func testCommitClampsAndRejects() {
        let r = HeartLimits.upperRange
        XCTAssertEqual(HeartLimits.commit("150", range: r), .set(150, clamped: false))
        XCTAssertEqual(HeartLimits.commit(" 150 ", range: r), .set(150, clamped: false))
        XCTAssertEqual(HeartLimits.commit("59", range: r), .set(60, clamped: true))
        XCTAssertEqual(HeartLimits.commit("1250", range: r), .set(220, clamped: true))
        XCTAssertEqual(HeartLimits.commit("-5", range: r), .set(60, clamped: true))
        XCTAssertEqual(HeartLimits.commit("", range: r), .cleared)
        XCTAssertEqual(HeartLimits.commit("12a", range: r), .rejected)
        XCTAssertEqual(HeartLimits.commit("1.5", range: r), .rejected)
    }

    func testAgeAndLowRanges() {
        XCTAssertEqual(HeartLimits.commit("9", range: HeartLimits.ageRange), .set(10, clamped: true))
        XCTAssertEqual(HeartLimits.commit("111", range: HeartLimits.ageRange), .set(110, clamped: true))
        XCTAssertEqual(HeartLimits.lowRange(upper: 120), 30...110)
        XCTAssertEqual(HeartLimits.lowRange(upper: nil), 30...210)
        XCTAssertEqual(HeartLimits.lowRange(upper: 60), 30...50)
    }

    func testDecimalAcceptsCommaAndDot() {
        XCTAssertEqual(HeartLimits.decimal("72,5"), 72.5)
        XCTAssertEqual(HeartLimits.decimal("72.5"), 72.5)
        XCTAssertEqual(HeartLimits.decimal(" 70 "), 70)
        XCTAssertNil(HeartLimits.decimal("7,2,5"))
        XCTAssertNil(HeartLimits.decimal(""))
        XCTAssertNil(HeartLimits.decimal("abc"))
    }

    func testAgeFromBirthdayHonoursTheBirthday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 21)) ?? Date()
        XCTAssertEqual(HeartLimits.age(birthYear: 1966, birthMonth: 10, birthDay: 21, now: now, calendar: cal), 60)
        XCTAssertEqual(HeartLimits.age(birthYear: 1966, birthMonth: 10, birthDay: 22, now: now, calendar: cal), 59)
        XCTAssertEqual(HeartLimits.age(birthYear: 1966, birthMonth: nil, birthDay: nil, now: now, calendar: cal), 60)
        XCTAssertNil(HeartLimits.age(birthYear: 2026, birthMonth: 1, birthDay: 1, now: now, calendar: cal))
        XCTAssertNil(HeartLimits.age(birthYear: 1800, birthMonth: 1, birthDay: 1, now: now, calendar: cal))
    }

    func testAlertFreshness() {
        XCTAssertTrue(HeartLimits.isFreshAlert(ts: 1000, now: 1000))
        XCTAssertTrue(HeartLimits.isFreshAlert(ts: 1000, now: 1060))
        XCTAssertFalse(HeartLimits.isFreshAlert(ts: 1000, now: 1061))
        XCTAssertTrue(HeartLimits.isFreshAlert(ts: 1005, now: 1000))    // 5 s ahead is tolerated
        XCTAssertFalse(HeartLimits.isFreshAlert(ts: 1005.1, now: 1000)) // more than 5 s in the future
        XCTAssertFalse(HeartLimits.isFreshAlert(ts: 5000, now: 1000))
    }
}
