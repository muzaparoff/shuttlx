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
                        Text(formatTimer(context.state.elapsedTime))
                            .font(.system(.title2, design: .monospaced).weight(.semibold))
                            .contentTransition(.numericText())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.heartRate > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("\(context.state.heartRate)")
                                .font(.system(.title3, design: .rounded).weight(.medium))
                        }
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
                }
            } compactLeading: {
                Image(systemName: activityIcon(context.state.currentActivity))
                    .foregroundStyle(context.state.isPaused ? .secondary : activityColor(context.state.currentActivity))
            } compactTrailing: {
                Text(formatTimer(context.state.elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(context.state.isPaused ? .secondary : .primary)
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: activityIcon(context.state.currentActivity))
                    .foregroundStyle(.green)
            }
        }
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
}
