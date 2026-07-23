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
    let z = hrZoneNumber(bpm)
    return z > 0 ? "Z\(z)" : ""
}

func hrZoneNumber(_ bpm: Int) -> Int {
    guard bpm > 0 else { return 0 }
    let calculator = HeartRateZoneCalculator.fromSharedDefaults()
    return calculator.zone(for: Double(bpm))
}

/// Compact duration for next-step preview: "45s" under 60s, "1:30" otherwise.
func formatStepDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    if s < 60 { return "\(s)s" }
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - HR Zone Arc (iOS)

/// Gauge-style arc showing the current HR zone (1–5). Identical visual
/// language to the watchOS `HRZoneArc` — 5 segments, 140° sweep.
struct HRZoneArc: View {
    let zone: Int

    private static let zoneColors: [Color] = [
        ShuttlXColor.hrZone1,
        ShuttlXColor.hrZone2,
        ShuttlXColor.hrZone3,
        ShuttlXColor.hrZone4,
        ShuttlXColor.hrZone5,
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height + 1
            let radius = size.height - 1
            let lineWidth: CGFloat = 4

            for i in 0..<5 {
                let segStart = 200.0 + Double(i) * 29.0
                let segEnd = segStart + 24.0
                let isFilled = zone > 0 && (i + 1) <= zone

                var path = Path()
                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: radius,
                    startAngle: .degrees(segStart),
                    endAngle: .degrees(segEnd),
                    clockwise: false
                )

                ctx.stroke(
                    path,
                    with: .color(isFilled
                        ? HRZoneArc.zoneColors[i]
                        : Color.white.opacity(0.12)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .accessibilityLabel(zone > 0 ? "Zone \(zone)" : "Heart rate zone unknown")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Label + color pair for the step pill shown by timer heroes.
struct StepPillInfo {
    let label: String
    let color: Color
}
