import Foundation
import HealthKit
import os.log

/// Reads heart-rate samples on iOS via a streaming `HKAnchoredObjectQuery`.
/// Source-agnostic: picks up samples from **any** device the user has paired —
/// Apple Watch, Powerbeats Pro 2, future AirPods Pro 3, third-party HR straps.
///
/// Surfaces:
///   - `current: Int` — latest BPM (0 while no sample has arrived yet)
///   - `sourceName: String?` — display name of the device that produced the
///     latest sample, e.g., "Apple Watch Ultra", "Powerbeats Pro 2". Drives the
///     UI's "❤ 142 BPM · Powerbeats Pro 2" pill.
@MainActor
final class iOSHeartRateMonitor: ObservableObject {
    @Published private(set) var current: Int = 0
    @Published private(set) var sourceName: String?
    /// True after at least one HR sample has arrived from any source.
    @Published private(set) var hasReceivedSample: Bool = false
    /// True if `noSourceDetectedAfter` seconds have elapsed since `start(from:)`
    /// without a single HR sample. UI uses this to surface a "pair an HR
    /// device" affordance instead of silently showing `—`.
    @Published private(set) var noSourceDetected: Bool = false

    /// Grace period before we declare "no HR source". 10s is enough for the
    /// first Apple Watch sample to arrive while not so long the user thinks
    /// the workout is broken.
    var noSourceDetectedAfter: TimeInterval = 10

    /// Sum/count for an O(1) average across the active workout, excluding
    /// paused intervals (caller is responsible for stopping the query during
    /// pause if a strict pause-aware average is desired). Mirrors the watch
    /// manager's HR-averaging pattern.
    private(set) var sampleSum: Double = 0
    private(set) var sampleCount: Int = 0
    private(set) var maxBPM: Int = 0

    var average: Int { sampleCount > 0 ? Int((sampleSum / Double(sampleCount)).rounded()) : 0 }

    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?
    private var noSourceTimer: DispatchSourceTimer?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "iOSHeartRateMonitor")

    /// Begin streaming HR samples from `startDate`. Idempotent — calling twice
    /// stops the prior query before starting the new one.
    func start(from startDate: Date) {
        stop()
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            logger.warning("HR quantity type unavailable")
            return
        }

        // Crucially: NO HKDevice.local() filter. We want HR from any paired
        // device (watch, Powerbeats Pro 2, future AirPods Pro 3, etc.).
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: .strictStartDate
        )

        let q = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.logger.error("HR query error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor [weak self] in self?.anchor = newAnchor }
            self?.process(samples)
        }
        q.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.logger.error("HR update error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor [weak self] in self?.anchor = newAnchor }
            self?.process(samples)
        }

        query = q
        store.execute(q)
        logger.info("HR query started")

        // Arm the no-source watchdog. If no sample arrives within the grace
        // period the UI flips to the "pair an HR device" affordance.
        scheduleNoSourceWatchdog()
    }

    func stop() {
        if let q = query { store.stop(q) }
        query = nil
        noSourceTimer?.cancel()
        noSourceTimer = nil
    }

    /// Reset accumulators between workouts. Does NOT stop an in-flight query.
    func reset() {
        sampleSum = 0
        sampleCount = 0
        maxBPM = 0
        current = 0
        sourceName = nil
        hasReceivedSample = false
        noSourceDetected = false
        anchor = nil
    }

    private func scheduleNoSourceWatchdog() {
        noSourceTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + noSourceDetectedAfter)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !self.hasReceivedSample {
                self.noSourceDetected = true
                self.logger.info("No HR source detected after \(self.noSourceDetectedAfter)s")
            }
        }
        noSourceTimer = t
        t.resume()
    }

    // MARK: - Private

    nonisolated private func process(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let pairs: [(Int, String?)] = samples.map {
            (
                Int($0.quantity.doubleValue(for: bpmUnit).rounded()),
                $0.sourceRevision.source.name
            )
        }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for (bpm, source) in pairs where bpm > 0 {
                self.sampleSum += Double(bpm)
                self.sampleCount += 1
                if bpm > self.maxBPM { self.maxBPM = bpm }
                self.current = bpm
                self.sourceName = source
                if !self.hasReceivedSample {
                    self.hasReceivedSample = true
                    self.noSourceDetected = false
                    self.noSourceTimer?.cancel()
                    self.noSourceTimer = nil
                }
            }
        }
    }
}
