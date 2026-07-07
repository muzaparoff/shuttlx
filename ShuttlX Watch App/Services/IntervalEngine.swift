import Foundation
#if os(watchOS)
import WatchKit
#endif

@MainActor
class IntervalEngine: ObservableObject {
    @Published var currentStepIndex: Int = 0
    @Published var currentStepTimeRemaining: TimeInterval = 0
    @Published var currentStep: IntervalStep?
    @Published var nextStep: IntervalStep?
    @Published var isComplete = false
    @Published var totalStepsCount: Int = 0

    private var allSteps: [IntervalStep] = []
    private var intervalResults: [CompletedInterval] = []
    private var stepStartDistance: Double = 0
    private var stepHeartRateSamples: [Double] = []
    private var stepElapsed: TimeInterval = 0
    // Workout-elapsed timestamp (pause-corrected wall clock) at which the current
    // step began. The countdown is derived from this, NOT from counting ticks, so
    // dropped or throttled timer ticks self-heal instead of losing seconds.
    private var stepStartElapsed: TimeInterval = 0
    private var templateName: String = ""
    private var templateID: UUID?

    // MARK: - Setup

    func configure(template: WorkoutTemplate) {
        allSteps = template.allSteps
        totalStepsCount = allSteps.count
        templateName = template.name
        templateID = template.id
        intervalResults = []
        currentStepIndex = 0
        isComplete = false

        if let first = allSteps.first {
            currentStep = first
            currentStepTimeRemaining = first.duration
            nextStep = allSteps.count > 1 ? allSteps[1] : nil
            stepElapsed = 0
            stepStartElapsed = 0
            stepStartDistance = 0
            stepHeartRateSamples = []
        }
    }

    // MARK: - Tick (called every 1s from WatchWorkoutManager)

    /// `workoutElapsed` is the manager's pause-corrected wall-clock elapsed time.
    /// The countdown is recomputed from it on every tick, so a late or dropped
    /// tick renders late but never loses time. Ticks are a render pulse only.
    func tick(heartRate: Int, distance: Double, workoutElapsed: TimeInterval) {
        guard !isComplete, currentStepIndex < allSteps.count else { return }

        // Collect HR sample
        if heartRate > 0 {
            stepHeartRateSamples.append(Double(heartRate))
        }

        // Complete every step whose wall-clock window has fully passed. A long
        // suspension can pass several steps at once; each gets its target
        // duration attributed, matching what actually happened on the clock.
        var elapsedInStep = max(0, workoutElapsed - stepStartElapsed)
        while !isComplete, let step = currentStep, elapsedInStep >= step.duration {
            stepElapsed = step.duration
            completeCurrentStep(distance: distance)
            stepStartElapsed += step.duration
            advanceToNextStep(distance: distance)
            elapsedInStep = max(0, workoutElapsed - stepStartElapsed)
        }

        guard !isComplete, let step = currentStep else { return }
        stepElapsed = elapsedInStep
        // Round to whole seconds so the displayed countdown matches the old
        // integer behavior (formatTimer truncates fractions).
        let newRemaining = max(0, (step.duration - elapsedInStep).rounded())

        // 5-second countdown haptic — fire once when crossing the 5s boundary
        #if os(watchOS)
        if currentStepTimeRemaining > 5, newRemaining <= 5, newRemaining > 0 {
            WKInterfaceDevice.current().play(.notification)
        }
        #endif

        currentStepTimeRemaining = newRemaining
    }

    // MARK: - Stop

    func stop(finalDistance: Double) -> (templateID: UUID?, templateName: String, results: [CompletedInterval]) {
        // Complete current step if still running
        if !isComplete, currentStepIndex < allSteps.count {
            completeCurrentStep(distance: finalDistance)
        }
        return (templateID, templateName, intervalResults)
    }

    // MARK: - Private

    private func completeCurrentStep(distance: Double) {
        guard currentStepIndex < allSteps.count else { return }
        let step = allSteps[currentStepIndex]

        let avgHR: Double? = stepHeartRateSamples.isEmpty ? nil :
            stepHeartRateSamples.reduce(0, +) / Double(stepHeartRateSamples.count)

        let stepDistance = distance - stepStartDistance

        let result = CompletedInterval(
            intervalType: step.type,
            label: step.label,
            targetDuration: step.duration,
            actualDuration: stepElapsed,
            averageHeartRate: avgHR,
            distance: stepDistance > 0 ? stepDistance : nil
        )
        intervalResults.append(result)
    }

    private func advanceToNextStep(distance: Double) {
        currentStepIndex += 1

        if currentStepIndex >= allSteps.count {
            // All steps done
            isComplete = true
            currentStep = nil
            nextStep = nil
            currentStepTimeRemaining = 0
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
            return
        }

        let step = allSteps[currentStepIndex]
        currentStep = step
        currentStepTimeRemaining = step.duration
        nextStep = (currentStepIndex + 1) < allSteps.count ? allSteps[currentStepIndex + 1] : nil
        stepElapsed = 0
        stepStartDistance = distance
        stepHeartRateSamples = []

        // Fire haptic based on step type
        fireHaptic(for: step.type)
    }

    private func fireHaptic(for stepType: IntervalType) {
        #if os(watchOS)
        let haptic: WKHapticType
        switch stepType {
        case .work: haptic = .start
        case .rest: haptic = .directionDown
        case .warmup, .cooldown: haptic = .click
        }
        WKInterfaceDevice.current().play(haptic)
        #endif
    }
}
