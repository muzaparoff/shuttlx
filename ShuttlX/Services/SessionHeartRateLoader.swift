import Foundation
import HealthKit
import os.log
import ShuttlXShared

/// Heart-rate line for the session detail. `TrainingSession` stores no samples (no model or payload
/// growth), so the line is read from Health for the session's time range and bucketed to ~150 points.
/// Samples stay on screen: nothing here is logged or sent to telemetry.
struct HeartRateSeries: Equatable {
    struct Point: Identifiable, Equatable {
        let date: Date
        let bpm: Double
        var id: Date { date }
    }
    let points: [Point]
    let average: Double
    let peak: Double
}

enum SessionHeartRateLoader {
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "SessionHeartRate")
    static let targetPoints = 150

    /// Nil when Health is unavailable, access was not granted (HealthKit then returns no samples,
    /// by design), or there are too few samples to draw a line.
    static func load(for session: TrainingSession) async -> HeartRateSeries? {
        let start = session.startDate
        let end = session.endDate ?? start.addingTimeInterval(session.duration)
        guard end.timeIntervalSince(start) >= 60 else { return nil }

        #if DEBUG
        // Screenshot seam (SHUTTLX_DEMO_HR=1): the simulator has no Health data, so draw a smooth line
        // through the parts' average heart rates. Without it demo mode shows no chart.
        if ProcessInfo.processInfo.environment["SHUTTLX_DEMO_HR"] == "1" {
            return demoSeries(session, start: start, end: end)
        }
        #endif

        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }

        let bucket = max(5, Int((end.timeIntervalSince(start) / Double(targetPoints)).rounded(.up)))
        let store = HKHealthStore()
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        let buckets: [(Date, Double, Double)] = await withCheckedContinuation { cont in
            let query = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax],
                anchorDate: start, intervalComponents: DateComponents(second: bucket))
            query.initialResultsHandler = { _, results, error in
                if let error { logger.info("HR query failed: \(error.localizedDescription, privacy: .public)") }
                var out: [(Date, Double, Double)] = []
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    guard let avg = stat.averageQuantity()?.doubleValue(for: unit),
                          let mx = stat.maximumQuantity()?.doubleValue(for: unit) else { return }
                    out.append((stat.startDate.addingTimeInterval(Double(bucket) / 2), avg, mx))
                }
                cont.resume(returning: out)
            }
            store.execute(query)
        }
        return series(buckets)
    }

    private static func series(_ buckets: [(Date, Double, Double)]) -> HeartRateSeries? {
        guard buckets.count >= 3 else { return nil }
        let pts = buckets.map { HeartRateSeries.Point(date: $0.0, bpm: $0.1) }
        return HeartRateSeries(points: pts,
                               average: pts.map(\.bpm).reduce(0, +) / Double(pts.count),
                               peak: buckets.map(\.2).max() ?? 0)
    }

    #if DEBUG
    private static func demoSeries(_ session: TrainingSession, start: Date, end: Date) -> HeartRateSeries? {
        let total = end.timeIntervalSince(start)
        let n = targetPoints
        let buckets: [(Date, Double, Double)] = (0..<n).map { i in
            let t = start.addingTimeInterval(total * (Double(i) + 0.5) / Double(n))
            let seg = session.segments.first { $0.startDate <= t && t < ($0.endDate ?? t) }
            let base = seg?.averageHeartRate ?? session.averageHeartRate ?? 130
            let wobble = sin(Double(i) * 0.7) * 3 + sin(Double(i) * 0.23) * 2
            return (t, base + wobble, base + wobble + 4)
        }
        return series(buckets)
    }
    #endif
}

/// Apple's measured VO2max (`vo2Max`), read-only. The watch measures it on outdoor walks and runs.
/// Nothing here is stored, written to Health, logged with values, or sent to telemetry.
struct VO2MaxReading: Equatable {
    let value: Double          // ml/kg/min
    let date: Date
    let previous: Double?      // the sample before it, for the trend arrow
}

enum VO2MaxLoader {
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "VO2Max")

    static var type: HKQuantityType? { HKQuantityType.quantityType(forIdentifier: .vo2Max) }

    /// Nil when Health is unavailable, access was not granted (HealthKit then returns no samples), or none exist.
    static func latest() async -> VO2MaxReading? {
        #if DEBUG
        // Screenshot seam (SHUTTLX_DEMO_VO2=<value>): the simulator has no Health data.
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_DEMO_VO2"], let v = Double(raw) {
            return VO2MaxReading(value: v, date: Date().addingTimeInterval(-3 * 86400), previous: v - 0.6)
        }
        #endif
        guard HKHealthStore.isHealthDataAvailable(), let type else { return nil }
        let unit = HKUnit(from: "ml/(kg*min)")
        let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 2,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, error in
                if let error { logger.info("VO2max query failed: \(error.localizedDescription, privacy: .public)") }
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            HKHealthStore().execute(q)
        }
        guard let first = samples.first else { return nil }
        return VO2MaxReading(value: first.quantity.doubleValue(for: unit), date: first.endDate,
                             previous: samples.dropFirst().first?.quantity.doubleValue(for: unit))
    }
}
