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

            Text(formatTimer(context.state.elapsedTime))
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                .contentTransition(.numericText())

            HStack(spacing: 16) {
                if context.state.heartRate > 0 {
                    MetricPill(icon: "heart.fill", value: "\(context.state.heartRate)", color: .red)
                }
                if context.state.distance > 0 {
                    MetricPill(icon: "location.fill", value: formatDistance(context.state.distance), color: .green)
                }
                if context.state.calories > 0 {
                    MetricPill(icon: "flame.fill", value: "\(context.state.calories)", color: .orange)
                }
                if context.state.pace > 0 && context.state.pace < 3600 {
                    MetricPill(icon: "gauge.with.dots.needle.33percent", value: formatPace(context.state.pace), color: .purple)
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.75))
    }

    // MARK: - Formatting Helpers

    private func formatTimer(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
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
