import Foundation
import SwiftUI

struct DailyWorkoutSummary: Identifiable {
    let id = UUID()
    let date: Date
    let totalDuration: TimeInterval
    let totalDistance: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let averagePace: TimeInterval?
    let sessionCount: Int

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(3))
    }
}

struct HRZoneDistribution: Identifiable {
    let id = UUID()
    let zone: String
    let percentage: Double
    let color: Color

    /// Zone definitions computed from the user's personalised max HR.
    /// Call this each time you need zones — the calculator reads shared UserDefaults
    /// so the boundaries stay current when the user changes their max HR in Settings.
    static func calculatedZones() -> [(name: String, range: ClosedRange<Double>, color: Color)] {
        let calculator = HeartRateZoneCalculator.fromSharedDefaults()
        let boundaries = calculator.zoneBoundaries()
        let colors: [Color] = [.blue, .green, .yellow, .orange, .red]
        return boundaries.enumerated().map { index, boundary in
            let lower = Double(boundary.lower)
            let upper = index == boundaries.count - 1
                ? calculator.estimatedMaxHR + 20   // extend Zone 5 ceiling
                : Double(boundary.upper)
            return (boundary.name, lower...upper, colors[index])
        }
    }
}

// MARK: - DataManager Extensions for Charts

extension DataManager {
    func dailySummaries(days: Int = 7) -> [DailyWorkoutSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? today
            let daySessions = sessions.filter { $0.startDate >= day && $0.startDate < dayEnd }

            let totalDuration = daySessions.reduce(0.0) { $0 + $1.duration }
            let totalDistance = daySessions.compactMap(\.distance).reduce(0, +)
            let totalCalories = daySessions.compactMap(\.caloriesBurned).reduce(0, +)
            let heartRates = daySessions.compactMap(\.averageHeartRate)
            let avgHR = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)

            var avgPace: TimeInterval? = nil
            if totalDistance > 0 && totalDuration > 0 {
                avgPace = totalDuration / totalDistance // seconds per km
            }

            return DailyWorkoutSummary(
                date: day,
                totalDuration: totalDuration,
                totalDistance: totalDistance,
                totalCalories: totalCalories,
                averageHeartRate: avgHR,
                averagePace: avgPace,
                sessionCount: daySessions.count
            )
        }
    }

    func heartRateZones(for sessions: [TrainingSession]) -> [HRZoneDistribution] {
        let heartRates = sessions.compactMap(\.averageHeartRate)
        guard !heartRates.isEmpty else { return [] }

        return HRZoneDistribution.calculatedZones().map { zone in
            let count = heartRates.filter { zone.range.contains($0) }.count
            let pct = Double(count) / Double(heartRates.count) * 100
            return HRZoneDistribution(zone: zone.name, percentage: pct, color: zone.color)
        }.filter { $0.percentage > 0 }
    }
}
