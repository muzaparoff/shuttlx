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

    static let zones: [(name: String, range: ClosedRange<Double>, color: Color)] = [
        ("Zone 1", 0...103, .blue),
        ("Zone 2", 104...124, .green),
        ("Zone 3", 125...145, .yellow),
        ("Zone 4", 146...166, .orange),
        ("Zone 5", 167...220, .red)
    ]
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

        return HRZoneDistribution.zones.map { zone in
            let count = heartRates.filter { zone.range.contains($0) }.count
            let pct = Double(count) / Double(heartRates.count) * 100
            return HRZoneDistribution(zone: zone.name, percentage: pct, color: zone.color)
        }.filter { $0.percentage > 0 }
    }
}
