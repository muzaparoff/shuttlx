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
            stepStartDistance = 0
            stepHeartRateSamples = []
        }
    }

    // MARK: - Tick (called every 1s from WatchWorkoutManager)

    func tick(heartRate: Int, distance: Double) {
        guard !isComplete, currentStepIndex < allSteps.count else { return }

        stepElapsed += 1
        currentStepTimeRemaining -= 1

        // Collect HR sample
        if heartRate > 0 {
            stepHeartRateSamples.append(Double(heartRate))
        }

        // Step complete?
        if currentStepTimeRemaining <= 0 {
            completeCurrentStep(distance: distance)
            advanceToNextStep(distance: distance)
        }
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
        case .rest: haptic = .stop
        case .warmup, .cooldown: haptic = .click
        }
        WKInterfaceDevice.current().play(haptic)
        #endif
    }
}
