import SwiftUI
import ShuttlXShared

// Staleness threshold: watch broadcasts every 3s; >5s means 1-2 missed cycles.
private let stalenessThreshold: TimeInterval = 5

struct LiveWorkoutCard: View {
    @ObservedObject var sharedData: PhoneSyncCoordinator
    @State private var showStopConfirmation = false
    /// Decoded once (and on appear), not once per second per redraw.
    @State private var heart = HeartSafetySettings.load()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let isStale: Bool = {
                guard let last = sharedData.liveMetricsLastUpdated else { return false }
                return context.date.timeIntervalSince(last) > stalenessThreshold
            }()
            content(isStale: isStale)
        }
        .onAppear { heart = HeartSafetySettings.load() }
        .confirmationDialog(
            "End & Save?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("End & Save", role: .destructive) {
                sharedData.stopWatchWorkout()
                // Clear iOS state immediately — don't wait for watch confirmation
                // (which arrives via workoutStopped notification after the watch
                // saves and tears down, potentially 5–15s later). The stop command
                // is already queued on two channels; a duplicate clear on arrival
                // is harmless.
                sharedData.clearLiveWorkoutState()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will save your workout and stop the session on Apple Watch.")
        }
    }

    private var activityWord: String {
        switch sharedData.liveCurrentActivity {
        case "running": return "RUN"
        case "walking": return "WALK"
        case "cycling": return "CYCLE"
        default: return "WORKOUT"
        }
    }

    private var summaryLine: String {
        var parts: [String] = []
        if sharedData.liveDistance > 0 { parts.append(FormattingUtils.formatDistance(sharedData.liveDistance, unit: .current)) }
        if sharedData.livePace > 0 { parts.append(FormattingUtils.formatPaceWithUnit(sharedData.livePace, unit: .current)) }
        if sharedData.liveCalories > 0 { parts.append("\u{2248} \(sharedData.liveCalories) cal estimate") }
        return parts.joined(separator: " \u{00B7} ")
    }

    private var zoneWord: String? {
        guard sharedData.liveHeartRate > 0 else { return nil }
        return heart.zoneWord(hr: sharedData.liveHeartRate, age: DeviceManager.shared.userAge)
    }

    private func pillButton(_ title: String, fill: Color, text: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ShuttlXFont.cardCaption.weight(.semibold))
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private func togglePause() {
        if sharedData.liveIsPaused { sharedData.resumeWatchWorkout() } else { sharedData.pauseWatchWorkout() }
    }

    @ViewBuilder
    private func content(isStale: Bool) -> some View {
        if sharedData.liveIsPaused && sharedData.livePauseReason == "noMotion" && !isStale {
            autoPausedCard
        } else {
            liveCard(isStale: isStale)
        }
    }

    private var autoPausedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("PAUSED AUTOMATICALLY", systemImage: "pause.fill")
                .font(ShuttlXFont.cardCaption.weight(.heavy))
                .tracking(0.7)
                .foregroundStyle(ShuttlXColor.ctaWarning)
            Text("Still training?")
                .font(ShuttlXFont.metricMedium)
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text("Your watch did not move for a while, so the workout is paused. The clock stopped at \(FormattingUtils.formatTimer(sharedData.liveElapsedTime)).")
                .font(ShuttlXFont.cardSubtitle.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textPrimary.opacity(0.75))
            HStack(spacing: 8) {
                pillButton("Resume", fill: ShuttlXColor.ctaPrimary, text: ShuttlXColor.iconOnCTA) { sharedData.resumeWatchWorkout() }
                pillButton("End & Save", fill: ShuttlXColor.ctaDestructive.opacity(0.12), text: ShuttlXColor.ctaDestructive) { showStopConfirmation = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ShuttlXColor.ctaWarning.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func liveCard(isStale: Bool) -> some View {
        let tint = isStale ? Color.yellow : (sharedData.liveIsPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.running)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if isStale {
                    Label("SIGNAL LOST", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .font(ShuttlXFont.cardCaption.weight(.heavy)).tracking(0.7).foregroundStyle(.yellow)
                } else {
                    HStack(spacing: 6) {
                        Circle().fill(tint).frame(width: 8, height: 8)
                            .modifier(PulseModifier(animate: !sharedData.liveIsPaused))
                        Text(sharedData.liveIsPaused ? "PAUSED" : "\(activityWord) \u{00B7} LIVE")
                            .font(ShuttlXFont.cardCaption.weight(.heavy)).tracking(0.7).foregroundStyle(tint)
                    }
                }
                Spacer()
                Label("Apple Watch", systemImage: "heart.fill")
                    .font(ShuttlXFont.cardCaption.weight(.bold))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            HStack(alignment: .bottom) {
                Text(FormattingUtils.formatTimer(sharedData.liveElapsedTime))
                    .font(ShuttlXFont.timerDisplay)
                    .contentTransition(.numericText())
                    .foregroundStyle(isStale ? ShuttlXColor.textSecondary : ShuttlXColor.textPrimary)
                Spacer()
                if sharedData.liveHeartRate > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(sharedData.liveHeartRate)")
                                .font(ShuttlXFont.metricMedium.monospacedDigit())
                                .foregroundStyle(ShuttlXColor.heartRate)
                                .contentTransition(.numericText())
                            Text("bpm").font(ShuttlXFont.cardCaption).foregroundStyle(ShuttlXColor.textSecondary)
                        }
                        if let zoneWord {
                            Text(zoneWord)
                                .font(ShuttlXFont.cardCaption.weight(.heavy))
                                .foregroundStyle(zoneWord == "HARD" ? ShuttlXColor.ctaDestructive : ShuttlXColor.running)
                        }
                    }
                }
            }
            if !summaryLine.isEmpty {
                Text(summaryLine).font(ShuttlXFont.cardCaption.monospacedDigit()).foregroundStyle(ShuttlXColor.textSecondary)
            }
            HStack(spacing: 8) {
                pillButton(sharedData.liveIsPaused ? "Resume" : "Pause",
                           fill: ShuttlXColor.ctaPrimary.opacity(0.12), text: ShuttlXColor.ctaPrimary, action: togglePause)
                pillButton("End & Save", fill: ShuttlXColor.ctaDestructive.opacity(0.12), text: ShuttlXColor.ctaDestructive) { showStopConfirmation = true }
            }
        }
        .padding(14)
        .timelineCard(radius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            isStale
                ? "Watch signal lost. Last known: \(FormattingUtils.formatTimeAccessible(sharedData.liveElapsedTime))"
                : "Live workout in progress, \(FormattingUtils.formatTimeAccessible(sharedData.liveElapsedTime))"
        )
    }
}

// MARK: - Sub-components

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
