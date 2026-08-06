import ActivityKit
import WidgetKit
import SwiftUI

struct ShuttlXLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: activityIcon(context.state.currentActivity))
                            .foregroundStyle(activityColor(context.state.currentActivity))
                        timerText(for: context, font: .system(.title2, design: .monospaced).weight(.semibold))
                    }
                    .widgetURL(URL(string: "shuttlx://workout/active"))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.heartRate > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("\(context.state.heartRate)")
                                .font(.system(.title3, design: .rounded).weight(.medium))
                        }
                        .widgetURL(URL(string: "shuttlx://workout/active"))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        if context.state.distance > 0 {
                            Label(formatDistance(context.state.distance), systemImage: "location.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        if context.state.calories > 0 {
                            Label("\(context.state.calories) cal", systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if context.state.pace > 0 && context.state.pace < 3600 {
                            Label(formatPace(context.state.pace), systemImage: "gauge.with.dots.needle.33percent")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                    .widgetURL(URL(string: "shuttlx://workout/active"))
                }
            } compactLeading: {
                Image(systemName: activityIcon(context.state.currentActivity))
                    .foregroundStyle(context.state.isPaused ? .secondary : activityColor(context.state.currentActivity))
            } compactTrailing: {
                // Constrained width: `Text(timerInterval:)` renders wider than
                // a fixed "MM:SS" string once the workout crosses an hour, and
                // the Dynamic Island compact region is tight — clamp with a
                // fixed frame + minimumScaleFactor so it never gets truncated
                // or pushes the compactLeading icon out.
                timerText(for: context, font: .system(.body, design: .monospaced))
                    .foregroundStyle(context.state.isPaused ? .secondary : .primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 56, alignment: .trailing)
            } minimal: {
                Image(systemName: activityIcon(context.state.currentActivity))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Timer

    /// System-rendered ticking timer while the workout is running — the OS
    /// advances this itself between our updates (roughly every 3s from the
    /// Watch), instead of the old pre-formatted string that only moved when
    /// an `activity.update()` call landed. Falls back to a static formatted
    /// string while paused, since `timerReferenceDate` isn't meaningful once
    /// the Watch stops broadcasting.
    @ViewBuilder
    private func timerText(for context: ActivityViewContext<WorkoutActivityAttributes>, font: Font) -> some View {
        // `Text(timerInterval:)` is greedy — it claims the full width
        // proposed by its container and lays its digits out leading-aligned
        // by default, which visibly shifts the expanded-leading Dynamic
        // Island timer left. Center the glyphs explicitly; the paused-state
        // static text gets the same treatment so pause/resume doesn't shift
        // the digits. `compactTrailing` layers its own trailing frame on top
        // of this at the call site and is unaffected.
        Group {
            if context.state.isPaused {
                Text(formatTimer(context.state.elapsedTime))
                    .contentTransition(.numericText())
            } else {
                Text(timerInterval: context.state.timerReferenceDate...Date.distantFuture, countsDown: false)
            }
        }
        .font(font)
        .multilineTextAlignment(.center)
    }

    // MARK: - Formatting Helpers

    private func formatTimer(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatDistance(_ km: Double) -> String {
        if km < 1.0 { return "\(Int(km * 1000)) m" }
        return String(format: "%.2f km", km)
    }

    private func formatPace(_ secondsPerKm: TimeInterval) -> String {
        let totalSeconds = Int(secondsPerKm)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d'%02d\"", m, s)
    }

    private func activityIcon(_ activity: String) -> String {
        switch activity {
        case "running": return "figure.run"
        case "walking": return "figure.walk"
        case "stationary": return "figure.stand"
        default: return "figure.mixed.cardio"
        }
    }

    private func activityColor(_ activity: String) -> Color {
        switch activity {
        case "running": return .green
        case "walking": return .orange
        default: return .secondary
        }
    }
}
