import Foundation

// MARK: - Analytics Data Types

struct WeeklySummary: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let totalDuration: TimeInterval
    let totalDistance: Double
    let sessionCount: Int
    let averageHeartRate: Double?
    let trainingLoad: Double

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStartDate)
    }
}

struct PersonalRecords {
    var fastestKmPace: TimeInterval?     // seconds per km
    var fastestKmDate: Date?
    var longestDuration: TimeInterval?
    var longestDurationDate: Date?
    var highestAvgHR: Double?
    var highestAvgHRDate: Date?
    var mostDistance: Double?             // km
    var mostDistanceDate: Date?
}

enum RecoveryStatus: String {
    case fresh = "Fresh"
    case normal = "Normal"
    case fatigued = "Fatigued"
    case overreaching = "Overreaching"
}

struct PaceZoneDistribution: Identifiable {
    let id = UUID()
    let zone: String
    let duration: TimeInterval
    let percentage: Double
}

// MARK: - Analytics Engine (Pure Functions)

enum AnalyticsEngine {

    // MARK: - Training Load

    /// Training load for a given week: total minutes x HR intensity factor (0-100 score).
    /// HR intensity is normalized assuming resting HR ~60 and max HR ~200.
    static func weeklyTrainingLoad(sessions: [TrainingSession]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return 0 }

        let recentSessions = sessions.filter { $0.startDate >= weekAgo }
        return computeTrainingLoad(for: recentSessions)
    }

    /// Fitness score: rolling 6-week weighted average of weekly training loads.
    /// More recent weeks get higher weight. Range roughly 0-100.
    static func fitnessScore(sessions: [TrainingSession]) -> Double {
        let weeklyLoads = weeklyTrainingLoads(sessions: sessions, weeks: 6)
        guard !weeklyLoads.isEmpty else { return 0 }

        // Exponential weighting: most recent week has highest weight
        let weights: [Double] = [0.05, 0.08, 0.12, 0.15, 0.25, 0.35]
        let count = weeklyLoads.count
        var weightedSum = 0.0
        var totalWeight = 0.0

        for i in 0..<count {
            let weightIndex = (6 - count) + i
            let weight = weightIndex >= 0 && weightIndex < weights.count ? weights[weightIndex] : 0.1
            weightedSum += weeklyLoads[i] * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    /// Fatigue: last 7 days training load. High value = needs rest.
    static func fatigue(sessions: [TrainingSession]) -> Double {
        return weeklyTrainingLoad(sessions: sessions)
    }

    /// Form = fitness - fatigue. Positive = peaked/ready, negative = fatigued.
    static func form(sessions: [TrainingSession]) -> Double {
        return fitnessScore(sessions: sessions) - fatigue(sessions: sessions)
    }

    // MARK: - VO2max Estimate

    /// Simplified VO2max estimate.
    /// Primary: Cooper test formula from best 12-min effort: VO2max = (distance_m - 504.9) / 44.73
    /// Fallback: HR method: 15.3 x (maxHR / restHR), using estimated values from session data.
    static func estimatedVO2Max(sessions: [TrainingSession]) -> Double? {
        // Try Cooper test approach: find best 12-minute distance
        let cooperEstimate = cooperVO2Max(sessions: sessions)
        if let cooper = cooperEstimate, cooper > 15 && cooper < 90 {
            return cooper
        }

        // Fallback: HR-based estimate
        return hrBasedVO2Max(sessions: sessions)
    }

    // MARK: - Personal Records

    static func personalRecords(sessions: [TrainingSession]) -> PersonalRecords {
        var records = PersonalRecords()

        for session in sessions {
            // Fastest km from km splits
            if let splits = session.kmSplits {
                for split in splits {
                    if records.fastestKmPace == nil || split.splitTime < records.fastestKmPace! {
                        records.fastestKmPace = split.splitTime
                        records.fastestKmDate = session.startDate
                    }
                }
            }
            // Also check pace from distance/duration for sessions without splits
            if records.fastestKmPace == nil, let dist = session.distance, dist > 0.5 {
                let pacePerKm = session.duration / dist
                if records.fastestKmPace == nil || pacePerKm < records.fastestKmPace! {
                    records.fastestKmPace = pacePerKm
                    records.fastestKmDate = session.startDate
                }
            }

            // Longest duration
            if records.longestDuration == nil || session.duration > records.longestDuration! {
                records.longestDuration = session.duration
                records.longestDurationDate = session.startDate
            }

            // Highest average HR
            if let hr = session.averageHeartRate {
                if records.highestAvgHR == nil || hr > records.highestAvgHR! {
                    records.highestAvgHR = hr
                    records.highestAvgHRDate = session.startDate
                }
            }

            // Most distance
            if let dist = session.distance {
                if records.mostDistance == nil || dist > records.mostDistance! {
                    records.mostDistance = dist
                    records.mostDistanceDate = session.startDate
                }
            }
        }

        return records
    }

    // MARK: - Weekly Trend

    /// Array of weekly summaries for trend charts, ordered oldest first.
    static func weeklyTrend(sessions: [TrainingSession], weeks: Int = 6) -> [WeeklySummary] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<weeks).reversed().compactMap { weekOffset -> WeeklySummary? in
            guard let weekEnd = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: now),
                  let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else {
                return nil
            }

            let weekSessions = sessions.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
            let totalDuration = weekSessions.reduce(0.0) { $0 + $1.duration }
            let totalDistance = weekSessions.compactMap(\.distance).reduce(0, +)
            let heartRates = weekSessions.compactMap(\.averageHeartRate)
            let avgHR = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
            let load = computeTrainingLoad(for: weekSessions)

            return WeeklySummary(
                weekStartDate: weekStart,
                totalDuration: totalDuration,
                totalDistance: totalDistance,
                sessionCount: weekSessions.count,
                averageHeartRate: avgHR,
                trainingLoad: load
            )
        }
    }

    // MARK: - Recovery Status

    /// Recovery status based on form score.
    static func recoveryStatus(sessions: [TrainingSession]) -> RecoveryStatus {
        let formValue = form(sessions: sessions)

        if formValue > 10 {
            return .fresh
        } else if formValue > -5 {
            return .normal
        } else if formValue > -20 {
            return .fatigued
        } else {
            return .overreaching
        }
    }

    // MARK: - Pace Zones

    /// Distribution of time in pace zones based on km split data and segment data.
    /// Zones: Easy (>6:30/km), Moderate (5:30-6:30), Tempo (4:45-5:30),
    /// Threshold (4:00-4:45), Interval (<4:00/km)
    static func paceZones(sessions: [TrainingSession]) -> [PaceZoneDistribution] {
        var zonesDuration: [String: TimeInterval] = [
            "Easy": 0,
            "Moderate": 0,
            "Tempo": 0,
            "Threshold": 0,
            "Interval": 0
        ]

        for session in sessions {
            // Use km splits if available
            if let splits = session.kmSplits, !splits.isEmpty {
                for split in splits {
                    let zone = paceZoneName(secondsPerKm: split.splitTime)
                    zonesDuration[zone, default: 0] += split.splitTime
                }
            } else if let distance = session.distance, distance > 0.1 {
                // Estimate from overall pace
                let pacePerKm = session.duration / distance
                let zone = paceZoneName(secondsPerKm: pacePerKm)
                zonesDuration[zone, default: 0] += session.duration
            }
        }

        let totalDuration = zonesDuration.values.reduce(0, +)
        guard totalDuration > 0 else { return [] }

        let orderedZones = ["Easy", "Moderate", "Tempo", "Threshold", "Interval"]
        return orderedZones.compactMap { zone in
            let duration = zonesDuration[zone] ?? 0
            guard duration > 0 else { return nil }
            return PaceZoneDistribution(
                zone: zone,
                duration: duration,
                percentage: (duration / totalDuration) * 100
            )
        }
    }

    // MARK: - Private Helpers

    private static func computeTrainingLoad(for sessions: [TrainingSession]) -> Double {
        var load = 0.0
        for session in sessions {
            let minutes = session.duration / 60.0
            // HR intensity: normalize to 0-1 range assuming resting=60, max=200
            let hrIntensity: Double
            if let avgHR = session.averageHeartRate, avgHR > 0 {
                hrIntensity = min(max((avgHR - 60) / 140.0, 0.1), 1.0)
            } else {
                // No HR data: assume moderate intensity (0.5)
                hrIntensity = 0.5
            }
            load += minutes * hrIntensity
        }
        // Normalize to roughly 0-100 scale (30 min * 5 sessions * 0.7 intensity = 105)
        return min(load / 1.0, 100)
    }

    private static func weeklyTrainingLoads(sessions: [TrainingSession], weeks: Int) -> [Double] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<weeks).reversed().compactMap { weekOffset -> Double? in
            guard let weekEnd = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: now),
                  let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else {
                return nil
            }

            let weekSessions = sessions.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
            return computeTrainingLoad(for: weekSessions)
        }
    }

    private static func cooperVO2Max(sessions: [TrainingSession]) -> Double? {
        // Find sessions with distance data and estimate 12-minute performance
        var bestDistanceIn12Min = 0.0

        for session in sessions {
            guard let distanceKm = session.distance, distanceKm > 0 else { continue }

            if session.duration >= 600 && session.duration <= 900 {
                // Close to 12 minutes -- extrapolate to 12 min
                let distanceMeters = distanceKm * 1000
                let projected12Min = distanceMeters * (720 / session.duration)
                bestDistanceIn12Min = max(bestDistanceIn12Min, projected12Min)
            } else if session.duration > 900 {
                // Longer session -- estimate 12-min pace from average speed
                let speedMps = (distanceKm * 1000) / session.duration
                let projected12Min = speedMps * 720
                bestDistanceIn12Min = max(bestDistanceIn12Min, projected12Min)
            }
        }

        guard bestDistanceIn12Min > 500 else { return nil }
        let vo2max = (bestDistanceIn12Min - 504.9) / 44.73
        return vo2max > 15 ? vo2max : nil
    }

    private static func hrBasedVO2Max(sessions: [TrainingSession]) -> Double? {
        // 15.3 x (maxHR / restHR)
        // Estimate maxHR from highest recorded HR across sessions
        let maxHRValues = sessions.compactMap(\.maxHeartRate)
        guard let maxHR = maxHRValues.max(), maxHR > 100 else { return nil }

        // Estimate resting HR: use lowest average HR from easy sessions
        let avgHRValues = sessions.compactMap(\.averageHeartRate).filter { $0 > 40 }
        guard !avgHRValues.isEmpty else { return nil }

        // Approximate resting HR as slightly below the lowest average HR recorded
        let lowestAvgHR = avgHRValues.min() ?? 70
        let estimatedRestHR = max(lowestAvgHR * 0.65, 50) // Rough estimate

        let vo2max = 15.3 * (maxHR / estimatedRestHR)
        return vo2max > 15 && vo2max < 90 ? vo2max : nil
    }

    private static func paceZoneName(secondsPerKm: TimeInterval) -> String {
        switch secondsPerKm {
        case ..<240:    return "Interval"   // < 4:00/km
        case 240..<285: return "Threshold"  // 4:00 - 4:45/km
        case 285..<330: return "Tempo"      // 4:45 - 5:30/km
        case 330..<390: return "Moderate"   // 5:30 - 6:30/km
        default:        return "Easy"       // > 6:30/km
        }
    }
}
