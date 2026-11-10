import XCTest
@testable import ShuttlXShared

final class WeekMinutesTests: XCTestCase {
    func testSumsThisCalendarWeekOnly() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let wed = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12)) ?? Date()
        let mon = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 0, minute: 5)) ?? Date()
        let sunBefore = cal.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 23, minute: 55)) ?? Date()
        var imported = TrainingSession(startDate: wed, duration: 30 * 60)
        imported.importedFromHealth = true
        let sessions = [
            TrainingSession(startDate: mon, duration: 45 * 60 + 30),   // 45.5 min
            imported,                                                  // counts
            TrainingSession(startDate: sunBefore, duration: 60 * 60),  // last week
        ]
        XCTAssertEqual(WeekMinutes.total(of: sessions, weekOf: wed, calendar: cal), 75)
        XCTAssertEqual(WeekMinutes.total(of: [], weekOf: wed, calendar: cal), 0)
    }
}
