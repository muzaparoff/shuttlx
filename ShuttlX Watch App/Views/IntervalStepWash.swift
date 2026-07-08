import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

// MARK: - Interval Step Wash
//
// Observes the IntervalEngine directly (not through WatchWorkoutManager) so its
// body re-evaluation is decoupled from the manager's once-per-second elapsedTime
// publish. The wash only redraws when the engine's `currentStep` actually changes,
// not on every metric tick.
struct IntervalStepWash: View {
    @ObservedObject var engine: IntervalEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let step = engine.currentStep {
            ShuttlXColor.forStepType(step.type)
                .opacity(0.08)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4),
                           value: step.type)
        }
    }
}
