import ActivityKit
import Foundation
import os.log

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<WorkoutActivityAttributes>?
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "LiveActivity")

    /// Tracks whether startActivity() previously failed, allowing retry on next call.
    private var startFailed = false

    var hasActivity: Bool { currentActivity != nil }

    private init() {}

    // Ribbon bookkeeping: the watch doesn't broadcast segments, so the phone builds
    // run-length parts from the activity it sees on each metrics update.
    private var parts: [WorkoutActivityAttributes.Part] = []
    private var lastElapsed: TimeInterval = 0

    private func accumulate(elapsed: TimeInterval, activity: String, isPaused: Bool) {
        defer { lastElapsed = elapsed }
        let delta = Int((elapsed - lastElapsed).rounded())
        // Ignore resets, pauses and implausible gaps (>2 min between updates).
        guard !isPaused, delta > 0, delta < 120 else { return }
        if let i = parts.indices.last, parts[i].activity == activity {
            parts[i].seconds += delta
        } else {
            parts.append(.init(activity: activity, seconds: delta))
        }
        if parts.count > 24 { // ponytail: folds the oldest part into the next; ribbon loses early detail only
            let a = parts.removeFirst()
            parts[0].seconds += a.seconds
        }
    }

    /// Picks up the activity the system kept across an app relaunch. True when one is held afterwards.
    /// The Live Activity buttons call this first: a cold launch by a button tap has no `currentActivity` yet.
    @discardableResult
    func adoptExisting() -> Bool {
        if currentActivity == nil {
            currentActivity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.activityState == .active })
            if let currentActivity { logger.info("Live Activity adopted: \(currentActivity.id)") }
        }
        return currentActivity != nil
    }

    /// Explicitly starts a Live Activity for the given workout type.
    /// If `Activity.request()` throws, the error is logged and `startFailed` is set
    /// so that subsequent calls (e.g. from `updateActivity`) can retry.
    @discardableResult
    func startActivity(activityType: String) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled by user")
            return false
        }

        // If an activity already exists and we haven't failed, skip.
        if currentActivity != nil && !startFailed {
            return true
        }

        // One that survived an app relaunch (the system keeps it): adopt it instead of starting a second.
        if currentActivity == nil, let existing = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.activityState == .active }) {
            currentActivity = existing
            startFailed = false
            logger.info("Live Activity adopted: \(existing.id)")
            return true
        }

        let attributes = WorkoutActivityAttributes(
            workoutStartDate: Date(),
            activityType: activityType
        )

        let initialState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            heartRate: 0,
            distance: 0,
            calories: 0,
            currentActivity: activityType,
            isPaused: false,
            pace: 0,
            timerReferenceDate: Date()
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(60))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            startFailed = false
            logger.info("Live Activity started: \(self.currentActivity?.id ?? "nil")")
            return true
        } catch {
            startFailed = true
            currentActivity = nil
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            return false
        }
    }

    func updateActivity(
        elapsedTime: TimeInterval,
        heartRate: Int,
        distance: Double,
        calories: Int,
        currentActivity activityType: String,
        isPaused: Bool,
        pace: TimeInterval,
        pauseReason: String? = nil,
        zoneWord: String? = nil,
        demoParts: [WorkoutActivityAttributes.Part]? = nil // DEBUG screenshot seam only
    ) {
        // If no current activity (or previous start failed), try to start one first.
        if currentActivity == nil || startFailed {
            let started = startActivity(activityType: activityType)
            if !started {
                // startFailed is already set; will retry on next metric update.
                logger.warning("updateActivity: no activity running, start failed — will retry next update")
                return
            }
        }

        guard let activity = currentActivity else { return }

        // Recomputed every update from the elapsed time the Watch just
        // reported: reference = now - elapsedTime. This self-corrects each
        // broadcast (~3s) rather than accumulating drift, and automatically
        // "resets" the countable window across a pause/resume since the next
        // post-resume update's elapsedTime already reflects the paused gap.
        let timerReferenceDate = Date().addingTimeInterval(-elapsedTime)
        if let demoParts { parts = demoParts } else {
            accumulate(elapsed: elapsedTime, activity: activityType, isPaused: isPaused)
        }

        let state = WorkoutActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
            currentActivity: activityType,
            isPaused: isPaused,
            pace: pace,
            pauseReason: isPaused ? pauseReason : nil,
            zoneWord: heartRate > 0 ? zoneWord : nil,
            parts: parts.isEmpty ? nil : parts,
            timerReferenceDate: timerReferenceDate
        )

        // While active: 15s staleDate (watch broadcasts every 3s).
        // While paused: 600s so the Live Activity doesn't grey out during long rests.
        let staleInterval: TimeInterval = isPaused ? 600 : 15
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleInterval))

        Task {
            await activity.update(content)
        }
    }

    func endActivity() {
        startFailed = false
        parts = []
        lastElapsed = 0

        guard let activity = currentActivity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            elapsedTime: 0,
            heartRate: 0,
            distance: 0,
            calories: 0,
            currentActivity: "unknown",
            isPaused: false,
            pace: 0,
            timerReferenceDate: Date()
        )

        let content = ActivityContent(state: finalState, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
            logger.info("Live Activity ended")
        }

        currentActivity = nil
    }

    /// Ends leftovers. The first live (not stale) activity is kept and adopted: the workout it shows may still run
    /// (app relaunched mid-workout). Stale ones are orphans, extra live ones are duplicates; both are ended.
    func cleanupStaleActivities() {
        let all = Activity<WorkoutActivityAttributes>.activities
        let isLive: (Activity<WorkoutActivityAttributes>) -> Bool = {
            $0.activityState == .active && !($0.content.staleDate.map { $0 < Date() } ?? false)
        }
        // The one this process already holds (started or adopted, e.g. by a button tap) is never swept, stale or not.
        let keep = all.first(where: { $0.id == currentActivity?.id && $0.activityState == .active }) ?? all.first(where: isLive)
        currentActivity = keep
        if let keep { logger.info("Live Activity kept: \(keep.id)") }
        Task {
            for activity in all where activity.id != keep?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
