import Foundation
import HealthKit

// MARK: - HKWorkoutSessionDelegate
#if os(watchOS)
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            logger.info("Workout session state: \(fromState.rawValue) -> \(toState.rawValue)")

            switch toState {
            case .paused:
                // System-initiated pause (user pause already set isPaused before
                // the session transition fires). Reflect it so the UI and the
                // pause-corrected clock stay truthful.
                if isWorkoutActive && !isPaused {
                    logger.warning("Session paused by system — reflecting in UI")
                    applyPauseState()
                }
            case .running:
                if isWorkoutActive && isPaused {
                    logger.warning("Session resumed by system — reflecting in UI")
                    applyResumeState()
                }
            case .stopped, .ended:
                // If we didn't initiate this (user stop sets isWorkoutActive=false
                // before this callback runs), the session died under us — finalize
                // NOW so the workout is saved instead of leaving a dead session
                // behind a still-running UI that can never stop.
                if isWorkoutActive {
                    logger.error("Session moved to \(toState.rawValue) by system mid-workout — saving and finalizing")
                    saveWorkoutDataToLocalStorage()
                    saveWorkoutData()
                    stopWorkout()
                }
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Workout session failed: \(error.localizedDescription)")
            guard isWorkoutActive else { return }
            // Checkpoint first (cheap, local), then finalize through the normal
            // save path and tear the workout down so the UI never sits on a dead
            // session. Previously this only wrote the backup and kept running.
            saveWorkoutDataToLocalStorage()
            healthKitSaveError = "Workout session failed: \(error.localizedDescription)"
            saveWorkoutData()
            stopWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate (T-METRICS.4)
// We mirror HKLiveWorkoutBuilder's `distanceWalkingRunning` sum statistic into
// `hkDistanceKm`. The pedometer callback then prefers this value over its own
// CMPedometer reading, since the builder's value is Apple's canonical fused
// distance (pedometer + GPS + on-device motion classification — same value
// shown by Apple Fitness and persisted on the resulting HKWorkout).
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Events (pause/resume/lap/marker) — no-op for distance handling.
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              collectedTypes.contains(distanceType) else { return }

        guard let stats = workoutBuilder.statistics(for: distanceType),
              let sum = stats.sumQuantity() else { return }

        let meters = sum.doubleValue(for: .meter())
        let km = meters / 1000.0

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.hkDistanceKm = km
        }
    }
}
#endif
