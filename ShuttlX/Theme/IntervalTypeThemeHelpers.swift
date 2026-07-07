import SwiftUI
import ShuttlXShared

// MARK: - Shared interval-type theme helpers
//
// Single source of truth for the ShuttlXShared.IntervalType → app-side theming
// bridge. These were previously byte-identical private copies in
// iPhoneWorkoutTimerView and all five *TimerHero files — a change to HR zone
// thresholds required six identical edits.

/// Bridges the package engine's IntervalType to the app-side enum that
/// `ShuttlXColor.forStepType(_:)` expects. Same raw values, so `?? .work`
/// is a guaranteed fallback.
func appType(for sharedType: ShuttlXShared.IntervalType) -> IntervalType {
    IntervalType(rawValue: sharedType.rawValue) ?? .work
}

func stepColor(for sharedType: ShuttlXShared.IntervalType) -> Color {
    ShuttlXColor.forStepType(appType(for: sharedType))
}

func displayName(for sharedType: ShuttlXShared.IntervalType) -> String {
    appType(for: sharedType).displayName
}

func hrZoneLabel(_ bpm: Int) -> String {
    guard bpm > 0 else { return "" }
    let pct = Double(bpm) / 185.0
    switch pct {
    case ..<0.60: return "Z1"
    case 0.60..<0.70: return "Z2"
    case 0.70..<0.80: return "Z3"
    case 0.80..<0.90: return "Z4"
    default: return "Z5"
    }
}

/// Label + color pair for the step pill shown by timer heroes.
struct StepPillInfo {
    let label: String
    let color: Color
}
