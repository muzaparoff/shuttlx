import SwiftUI
import ShuttlXShared

// Staleness threshold: watch broadcasts every 3s; >5s means 1-2 missed cycles.
private let stalenessThreshold: TimeInterval = 5

struct LiveWorkoutCard: View {
    @ObservedObject var sharedData: PhoneSyncCoordinator
    @State private var showStopConfirmation = false

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
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let isStale: Bool = {
                guard let last = sharedData.liveMetricsLastUpdated else { return false }
                return context.date.timeIntervalSince(last) > stalenessThreshold
            }()
            content(isStale: isStale)
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                sharedData.stopWatchWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will save your workout and stop the session on Apple Watch.")
        }
    }

    @ViewBuilder
    private func content(isStale: Bool) -> some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    if isStale {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.yellow)
                        Text("Signal lost")
                            .font(ShuttlXFont.cardTitle)
                            .foregroundStyle(.yellow)
                    } else {
                        Circle()
                            .fill(sharedData.liveIsPaused ? Color.orange : ShuttlXColor.running)
                            .frame(width: 8, height: 8)
                            .modifier(PulseModifier(animate: !sharedData.liveIsPaused))
                        Text(sharedData.liveIsPaused ? "Paused" : "Live Workout")
                            .font(ShuttlXFont.cardTitle)
                    }
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
                .foregroundStyle(isStale ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Metrics row
            HStack(spacing: 16) {
                if sharedData.liveHeartRate > 0 {
                    LiveMetricPill(
                        icon: "heart.fill",
                        value: "\(sharedData.liveHeartRate)",
                        color: isStale ? ShuttlXColor.heartRate.opacity(0.5) : ShuttlXColor.heartRate
                    )
                }

                if sharedData.liveDistance > 0 {
                    LiveMetricPill(
                        icon: "location.fill",
                        value: FormattingUtils.formatDistance(sharedData.liveDistance),
                        color: isStale ? ShuttlXColor.running.opacity(0.5) : ShuttlXColor.running
                    )
                }

                if sharedData.liveCalories > 0 {
                    LiveMetricPill(
                        icon: "flame.fill",
                        value: "\(sharedData.liveCalories)",
                        color: isStale ? ShuttlXColor.calories.opacity(0.5) : ShuttlXColor.calories
                    )
                }

                if sharedData.livePace > 0 {
                    LiveMetricPill(
                        icon: "gauge.with.dots.needle.33percent",
                        value: FormattingUtils.formatPace(sharedData.livePace),
                        color: isStale ? ShuttlXColor.pace.opacity(0.5) : ShuttlXColor.pace
                    )
                }
            }

            Divider()
                .opacity(0.3)

            // Remote controls — pause/resume on left, stop on right
            HStack {
                Button {
                    if sharedData.liveIsPaused {
                        sharedData.resumeWatchWorkout()
                    } else {
                        sharedData.pauseWatchWorkout()
                    }
                } label: {
                    Label(
                        sharedData.liveIsPaused ? "Resume" : "Pause",
                        systemImage: sharedData.liveIsPaused ? "play.fill" : "pause.fill"
                    )
                    .font(ShuttlXFont.cardTitle)
                    .foregroundStyle(sharedData.liveIsPaused ? ShuttlXColor.ctaPrimary : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isStale)

                Button {
                    showStopConfirmation = true
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .font(ShuttlXFont.cardTitle)
                        .foregroundStyle(ShuttlXColor.ctaDestructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ShuttlXColor.ctaDestructive.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isStale)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill((isStale ? Color.yellow : ShuttlXColor.running).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder((isStale ? Color.yellow : ShuttlXColor.running).opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isStale
                ? "Watch signal lost. Last known: \(FormattingUtils.formatTimeAccessible(sharedData.liveElapsedTime))"
                : "Live workout in progress, \(FormattingUtils.formatTimeAccessible(sharedData.liveElapsedTime))"
        )
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
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(color)
            Text(value)
                .font(ShuttlXFont.cardCaption.monospacedDigit())
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PulseModifier: ViewModifier {
    let animate: Bool
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || !animate ? 1.0 : (isAnimating ? 0.3 : 1.0))
            .animation(
                (reduceMotion || !animate) ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                if !reduceMotion && animate { isAnimating = true }
            }
            .onChange(of: animate) { _, newVal in
                isAnimating = newVal && !reduceMotion
            }
    }
}

#Preview {
    LiveWorkoutCard(sharedData: PhoneSyncCoordinator.shared)
        .padding()
}
