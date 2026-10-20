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
                    // Build summary before stopWorkout() zeros published state (S-1 pattern).
                    pendingSummary = buildCurrentSummary()
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
            saveWorkoutData()
            // Build summary before stopWorkout() zeros published state (S-1 pattern).
            // healthKitSaveError is preserved in pendingSummary's parent view for display
            // after F-4 adds WorkoutEndReason; for now the summary screen at least confirms
            // the data was saved.
            healthKitSaveError = "Workout session failed: \(error.localizedDescription)"
            pendingSummary = buildCurrentSummary()
            stopWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate (T-METRICS.4)
// The builder's statistics are Apple's canonical, workout-scoped numbers (the
// same values Apple Fitness shows and the saved HKWorkout carries). Distance
// covers walking/running, cycling and swimming — whichever type the session's
// configuration collects — and active energy replaces the old unfiltered
// HKAnchoredObjectQuery. Statistics are read here on the delegate queue; only
// the resulting values hop to the main actor.
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Events (pause/resume/lap/marker) — no-op.
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var distanceKm: Double?
        for identifier in [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling, .distanceSwimming] {
            let type = HKQuantityType(identifier)
            guard collectedTypes.contains(type),
                  let sum = workoutBuilder.statistics(for: type)?.sumQuantity() else { continue }
            distanceKm = sum.doubleValue(for: .meter()) / 1000.0
        }

        var energy: (kcal: Double, end: Date)?
        let energyType = HKQuantityType(.activeEnergyBurned)
        if collectedTypes.contains(energyType),
           let stats = workoutBuilder.statistics(for: energyType),
           let sum = stats.sumQuantity() {
            energy = (sum.doubleValue(for: .kilocalorie()), stats.endDate)
        }

        guard distanceKm != nil || energy != nil else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let distanceKm { self.applyBuilderDistance(km: distanceKm) }
            if let energy { self.applyBuilderEnergy(totalKcal: energy.kcal, statsEnd: energy.end) }
        }
    }
}
#endif
