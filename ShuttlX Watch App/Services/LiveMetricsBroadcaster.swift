import Foundation
import WatchConnectivity
import ShuttlXShared
import os.log

/// Watch → iPhone live-metrics + lifecycle broadcast — extracted from
/// WatchWorkoutManager (refactor plan Phase 3). Owns the 3-second throttle.
///
/// Dual-channel strategy:
///  • sendMessage — real-time when iPhone is reachable (foregrounded / unlocked)
///  • updateApplicationContext — OS-queued, delivered when iPhone next wakes
///    (handles locked phone in pocket, suspended app, brief BT hiccups)
/// Do NOT add an isReachable guard to the context channel — it silently drops
/// metrics during runs when the iPhone is locked. applicationContext only
/// stores the latest snapshot, which is exactly what we want for live metrics.
@MainActor
final class LiveMetricsBroadcaster {

    struct Snapshot {
        let workoutName: String
        let elapsedTime: TimeInterval
        let heartRate: Int
        let distance: Double
        let calories: Int
        let steps: Int
        let activityRawValue: String
        let isPaused: Bool
        let pace: TimeInterval?
        let cadence: Int
        let lastLatitude: Double?
        let lastLongitude: Double?
    }

    private var lastLiveUpdateTime: Date?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "LiveMetrics")

    /// Dedicated serial queue for the WatchConnectivity IPC. `sendMessage` and
    /// `updateApplicationContext` both cross into the WC daemon (wcd); when wcd's
    /// outbox is saturated — e.g. a cold-launch sync storm — those calls block the
    /// caller for hundreds of ms. This broadcaster is driven from
    /// `WatchWorkoutManager.updateElapsedTime()`, i.e. the 1 Hz display tick, so
    /// blocking here stalls the on-screen clock. Serial (not concurrent) so live
    /// snapshots keep FIFO order; fire-and-forget from the tick's point of view.
    private nonisolated static let wcQueue = DispatchQueue(
        label: "com.shuttlx.live-metrics-wc",
        qos: .utility
    )

    /// A single `updateApplicationContext` slower than this means wcd is backed up.
    /// Confirmation instrumentation for the "timer stale for the first 5–7 minutes"
    /// diagnosis — grep "Live metrics applicationContext slow".
    private nonisolated static let contextSlowThreshold: TimeInterval = 0.25

    /// Clears the throttle window (call when a workout stops).
    func reset() {
        lastLiveUpdateTime = nil
    }

    func broadcastIfNeeded(_ snapshot: Snapshot) {
        // Throttle is evaluated before any WC work — two Date comparisons on the
        // main actor, nothing more.
        let now = Date()
        if let lastUpdate = lastLiveUpdateTime, now.timeIntervalSince(lastUpdate) < 3.0 {
            return
        }
        lastLiveUpdateTime = now

        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = [
            "action": "liveMetrics",
            "workoutName": snapshot.workoutName,
            "elapsedTime": snapshot.elapsedTime,
            "heartRate": snapshot.heartRate,
            "distance": snapshot.distance,
            "calories": snapshot.calories,
            "steps": snapshot.steps,
            "currentActivity": snapshot.activityRawValue,
            "isPaused": snapshot.isPaused,
            "pace": snapshot.pace ?? 0,
            "cadence": snapshot.cadence,
            "timestamp": now.timeIntervalSince1970
        ]

        // Include latest route point for live map on iOS
        if let lat = snapshot.lastLatitude, let lon = snapshot.lastLongitude {
            payload["latitude"] = lat
            payload["longitude"] = lon
        }

        // Hand the finished payload (a value copy) to the background queue and
        // return immediately — the display tick must never wait on wcd.
        let logger = self.logger
        let outgoing = payload
        Self.wcQueue.async {
            // Channel 1: real-time when reachable
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(outgoing, replyHandler: nil) { error in
                    logger.debug("Live metrics sendMessage failed: \(error.localizedDescription)")
                }
            }

            // Channel 2: applicationContext — always delivered when iPhone next wakes
            let started = Date()
            do {
                try WCSession.default.updateApplicationContext(outgoing)
            } catch {
                // Raised from .debug: a failing context write means the iPhone is
                // not receiving live metrics at all, which is user-visible.
                logger.warning("Live metrics applicationContext failed: \(error.localizedDescription)")
            }
            let elapsed = Date().timeIntervalSince(started)
            if elapsed > Self.contextSlowThreshold {
                logger.warning("Live metrics applicationContext slow: \(Int(elapsed * 1000))ms — WC daemon backed up")
            }
        }
    }

    /// Notify iPhone that a workout started — transferUserInfo wakes iOS in background.
    func notifyWorkoutStarted(sport: WorkoutSport) {
        guard WCSession.default.activationState == .activated else { return }
        let startPayload: [String: Any] = [
            "action": "workoutStarted",
            "activityType": sport.rawValue,
            "startTime": Date().timeIntervalSince1970
        ]
        WCSession.default.transferUserInfo(startPayload)
    }

    /// Notify iPhone that the workout ended (immediate + guaranteed).
    func notifyWorkoutStopped() {
        let stopPayload: [String: Any] = ["action": "workoutStopped", "timestamp": Date().timeIntervalSince1970]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(stopPayload, replyHandler: nil, errorHandler: nil)
        }
        WCSession.default.transferUserInfo(stopPayload)
    }
}
