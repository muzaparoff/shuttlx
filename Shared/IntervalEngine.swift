import Foundation
import Combine

/// Drives an interval workout: countdown per step, transitions, captured results.
///
/// Pure value/reference-type logic — no `WatchKit`, no `UIKit`, no `HealthKit`
/// dependencies. Platform-specific behavior (haptics) is injected via the
/// `HapticPlayer` protocol; tests can pass `nil` to silence it.
///
/// This is the canonical implementation. The iOS target imports `ShuttlXShared`
/// and consumes this type directly (iPhoneWorkoutController + timer heroes).
/// The WATCH target does NOT yet — it still runs its own older, differently-
/// shaped `ShuttlX Watch App/Services/IntervalEngine.swift` (WorkoutTemplate-
/// coupled, direct WKInterfaceDevice haptics).
///
/// NOTE: Do NOT delete the watch's parallel IntervalEngine until the watch is
/// migrated onto this engine (adapter at the WatchWorkoutManager call sites +
/// a WatchHapticPlayer). See docs/plans/2026-07-codebase-refactor-plan.md Phase 4 —
/// that migration is behavior-affecting and gated behind dual-engine tests + QA.
@MainActor
public final class IntervalEngine: ObservableObject {
    @Published public private(set) var currentStepIndex: Int = 0
    @Published public private(set) var currentStepTimeRemaining: TimeInterval = 0
    @Published public private(set) var currentStep: IntervalStepDescriptor?
    @Published public private(set) var nextStep: IntervalStepDescriptor?
    @Published public private(set) var isComplete: Bool = false
    @Published public private(set) var totalStepsCount: Int = 0

    /// Optional — tests pass `nil`.
    private let haptics: HapticPlayer?

    private var allSteps: [IntervalStepDescriptor] = []
    private var intervalResults: [IntervalResult] = []
    private var stepStartDistance: Double = 0
    private var stepHeartRateSamples: [Double] = []
    private var stepElapsed: TimeInterval = 0
    private var templateName: String = ""
    private var templateID: UUID?

    public init(haptics: HapticPlayer? = nil) {
        self.haptics = haptics
    }

    // MARK: - Setup

    public func configure(steps: [IntervalStepDescriptor], templateName: String, templateID: UUID?) {
        allSteps = steps
        totalStepsCount = steps.count
        self.templateName = templateName
        self.templateID = templateID
        intervalResults = []
        currentStepIndex = 0
        isComplete = false

        if let first = steps.first {
            currentStep = first
            currentStepTimeRemaining = first.duration
            nextStep = steps.count > 1 ? steps[1] : nil
            stepElapsed = 0
            stepStartDistance = 0
            stepHeartRateSamples = []
        }
    }

    // MARK: - Tick (called every 1s from the workout controller)

    public func tick(heartRate: Int, distance: Double) {
        guard !isComplete, currentStepIndex < allSteps.count else { return }

        stepElapsed += 1
        currentStepTimeRemaining -= 1

        // Collect HR sample for the per-step average
        if heartRate > 0 {
            stepHeartRateSamples.append(Double(heartRate))
        }

        // 5-second countdown haptic
        if currentStepTimeRemaining == 5 {
            haptics?.play(.countdownTick)
        }

        // Step complete?
        if currentStepTimeRemaining <= 0 {
            completeCurrentStep(distance: distance)
            advanceToNextStep(distance: distance)
        }
    }

    // MARK: - Stop

    public func stop(finalDistance: Double) -> StopResult {
        if !isComplete, currentStepIndex < allSteps.count {
            completeCurrentStep(distance: finalDistance)
        }
        return StopResult(templateID: templateID, templateName: templateName, results: intervalResults)
    }

    public struct StopResult: Sendable {
        public let templateID: UUID?
        public let templateName: String
        public let results: [IntervalResult]
    }

    // MARK: - Private

    private func completeCurrentStep(distance: Double) {
        guard currentStepIndex < allSteps.count else { return }
        let step = allSteps[currentStepIndex]

        let avgHR: Double? = stepHeartRateSamples.isEmpty
            ? nil
            : stepHeartRateSamples.reduce(0, +) / Double(stepHeartRateSamples.count)

        let stepDistance = distance - stepStartDistance

        let result = IntervalResult(
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
            isComplete = true
            currentStep = nil
            nextStep = nil
            currentStepTimeRemaining = 0
            haptics?.play(.complete)
            return
        }

        let step = allSteps[currentStepIndex]
        currentStep = step
        currentStepTimeRemaining = step.duration
        nextStep = (currentStepIndex + 1) < allSteps.count ? allSteps[currentStepIndex + 1] : nil
        stepElapsed = 0
        stepStartDistance = distance
        stepHeartRateSamples = []

        switch step.type {
        case .work:                 haptics?.play(.workStart)
        case .rest:                 haptics?.play(.restStart)
        case .warmup, .cooldown:    haptics?.play(.stepTransition)
        }
    }
}

// MARK: - Plain value types (no app-target dependencies)

/// Mirror of the app's `IntervalStep` model — kept here so `IntervalEngine`
/// doesn't depend on app-target types. App targets construct these from their
/// own `WorkoutTemplate.allSteps` arrays.
public struct IntervalStepDescriptor: Sendable, Equatable {
    public let type: IntervalType
    public let label: String?
    public let duration: TimeInterval

    public init(type: IntervalType, label: String?, duration: TimeInterval) {
        self.type = type
        self.label = label
        self.duration = duration
    }
}

public enum IntervalType: String, Sendable, Codable, CaseIterable {
    case warmup
    case work
    case rest
    case cooldown
}

/// Mirror of the app's `CompletedInterval` — produced by `IntervalEngine.stop()`.
/// Callers convert this to the app-target `CompletedInterval` for persistence.
public struct IntervalResult: Sendable, Equatable {
    public let intervalType: IntervalType
    public let label: String?
    public let targetDuration: TimeInterval
    public let actualDuration: TimeInterval
    public let averageHeartRate: Double?
    public let distance: Double?

    public init(
        intervalType: IntervalType,
        label: String?,
        targetDuration: TimeInterval,
        actualDuration: TimeInterval,
        averageHeartRate: Double?,
        distance: Double?
    ) {
        self.intervalType = intervalType
        self.label = label
        self.targetDuration = targetDuration
        self.actualDuration = actualDuration
        self.averageHeartRate = averageHeartRate
        self.distance = distance
    }
}
