import SwiftUI

struct LiveWorkoutCard: View {
    @ObservedObject var sharedData: SharedDataManager

    private var activityIcon: String {
        switch sharedData.liveCurrentActivity {
        case "running": return "figure.run"
        case "walking": return "figure.walk"
        case "stationary": return "figure.stand"
        default: return "figure.mixed.cardio"
        }
    }

    private var activityColor: Color {
        switch sharedData.liveCurrentActivity {
        case "running": return ShuttlXColor.running
        case "walking": return ShuttlXColor.walking
        default: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ShuttlXColor.running)
                        .frame(width: 8, height: 8)
                        .modifier(PulseModifier())

                    Text(sharedData.liveIsPaused ? "Paused" : "Live Workout")
                        .font(ShuttlXFont.cardTitle)
                }

                Spacer()

                Image(systemName: activityIcon)
                    .font(.title3)
                    .foregroundStyle(activityColor)
            }

            // Timer
            Text(FormattingUtils.formatTimer(sharedData.liveElapsedTime))
                .font(ShuttlXFont.timerDisplay)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .center)

            // Metrics row
            HStack(spacing: 16) {
                if sharedData.liveHeartRate > 0 {
                    LiveMetricPill(
                        icon: "heart.fill",
                        value: "\(sharedData.liveHeartRate)",
                        color: ShuttlXColor.heartRate
                    )
                }

                if sharedData.liveDistance > 0 {
                    LiveMetricPill(
                        icon: "location.fill",
                        value: FormattingUtils.formatDistance(sharedData.liveDistance),
                        color: ShuttlXColor.running
                    )
                }

                if sharedData.liveCalories > 0 {
                    LiveMetricPill(
                        icon: "flame.fill",
                        value: "\(sharedData.liveCalories)",
                        color: ShuttlXColor.calories
                    )
                }

                if sharedData.livePace > 0 {
                    LiveMetricPill(
                        icon: "gauge.with.dots.needle.33percent",
                        value: FormattingUtils.formatPace(sharedData.livePace),
                        color: .purple
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShuttlXColor.running.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ShuttlXColor.running.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live workout in progress, \(FormattingUtils.formatTimeAccessible(sharedData.liveElapsedTime))")
    }
}

// MARK: - Sub-components

private struct LiveMetricPill: View {
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
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

#Preview {
    LiveWorkoutCard(sharedData: SharedDataManager.shared)
        .padding()
}
