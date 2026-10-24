import XCTest
@testable import ShuttlXShared

/// Plan 2026-10 part B, check from the open-items plan: 200 one-hour sessions with 1000 GPS points each
/// give a stripped sessions.json under 2.5 MB (inline it is about 37 MB).
final class SessionsFileSizeTests: XCTestCase {
    func testTwoHundredRoutedSessionsStripUnderTwoAndAHalfMB() throws {
        let t0 = Date(timeIntervalSinceReferenceDate: 780_000_000)
        var sessions: [TrainingSession] = []
        for n in 0..<200 {
            let start = t0.addingTimeInterval(Double(n) * 86_400)
            let segments: [ActivitySegment] = (0..<30).map { (i: Int) -> ActivitySegment in
                let from = start.addingTimeInterval(Double(i) * 120)
                let activity: DetectedActivity = i % 2 == 0 ? .walking : .running
                return ActivitySegment(activityType: activity, startDate: from, endDate: from.addingTimeInterval(120), steps: 250,
                                       distance: 0.3, averageHeartRate: 130, estimatedCalories: 20, activeEnergyCalories: 19)
            }
            let route: [RoutePoint] = (0..<1000).map { (i: Int) -> RoutePoint in
                let d = Double(i)
                return RoutePoint(latitude: 52.2 + d * 1e-5, longitude: 0.12 + d * 1e-5, altitude: 10 + Double(i % 50),
                                  timestamp: start.addingTimeInterval(d * 3.6), speed: 2.8, horizontalAccuracy: 5)
            }
            let splits: [KmSplitData] = (1...8).map { (k: Int) -> KmSplitData in KmSplitData(kmNumber: k, splitTime: 420, cumulativeTime: Double(k) * 420) }
            var s = TrainingSession(startDate: start, endDate: start.addingTimeInterval(3600), duration: 3600, averageHeartRate: 128,
                                    maxHeartRate: 160, caloriesBurned: 450, distance: 9, totalSteps: 8000, segments: segments,
                                    inlineRoute: route,
                                    kmSplits: splits)
            XCTAssertNotNil(RouteExternalize.strip(&s))
            sessions.append(s)
        }
        let bytes = try JSONEncoder().encode(sessions).count
        XCTAssertLessThan(bytes, 2_500_000, "stripped sessions.json is \(bytes) bytes")
    }
}
