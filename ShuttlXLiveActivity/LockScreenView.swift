import SwiftUI
import WidgetKit
import ActivityKit

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(context.state.isPaused ? .orange : .green)
                        .frame(width: 8, height: 8)
                    Text(context.state.isPaused ? "Paused" : activityLabel(context.state.currentActivity))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: activityIcon(context.state.currentActivity))
                    .foregroundStyle(activityColor(context.state.currentActivity))
            }

            timerText
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                // `Text(timerInterval:)` is greedy — it claims the full width
                // proposed by the VStack (which stretches to match the header
                // row above) and lays its digits out leading-aligned by
                // default. Explicitly center both the frame and the glyphs
                // inside it so running/paused states render identically.
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                if context.state.heartRate > 0 {
                    MetricPill(icon: "heart.fill", value: "\(context.state.heartRate)", color: .red)
                        .accessibilityLabel("Heart rate \(context.state.heartRate) beats per minute")
                }
                if context.state.distance > 0 {
                    MetricPill(icon: "location.fill", value: formatDistance(context.state.distance), color: .green)
                        .accessibilityLabel("Distance \(formatDistance(context.state.distance))")
                }
                if context.state.calories > 0 {
                    MetricPill(icon: "flame.fill", value: "\(context.state.calories)", color: .orange)
                        .accessibilityLabel("Calories \(context.state.calories) kilocalories")
                }
                if context.state.pace > 0 && context.state.pace < 3600 {
                    MetricPill(icon: "gauge.with.dots.needle.33percent", value: formatPace(context.state.pace), color: .purple)
                        .accessibilityLabel("Pace \(formatPace(context.state.pace)) per kilometre")
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.75))
        // Tapping the Lock Screen / Notification Center Live Activity deep-links
        // back into ShuttlX. The host app's onOpenURL routes the user to the
        // running iPhone workout (if the controller is active) or just brings
        // the app to the foreground for a watch-driven workout. See
        // ShuttlX/ShuttlXApp.swift for the URL handler.
        .widgetURL(URL(string: "shuttlx://workout/active"))
    }

    // MARK: - Timer

    /// System-rendered ticking timer while the workout is running — the OS
    /// advances this itself between our updates (roughly every 3s from the
    /// Watch), instead of the old pre-formatted string that only moved when
    /// an `activity.update()` call landed. Falls back to a static formatted
    /// string while paused, since `timerReferenceDate` isn't meaningful once
    /// the Watch stops broadcasting.
    @ViewBuilder
    private var timerText: some View {
        if context.state.isPaused {
            Text(formatTimer(context.state.elapsedTime))
                .contentTransition(.numericText())
        } else {
            Text(timerInterval: context.state.timerReferenceDate...Date.distantFuture, countsDown: false)
        }
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

    private func activityLabel(_ activity: String) -> String {
        switch activity {
        case "running": return "Running"
        case "walking": return "Walking"
        default: return "Workout Active"
        }
    }
}

private struct MetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
