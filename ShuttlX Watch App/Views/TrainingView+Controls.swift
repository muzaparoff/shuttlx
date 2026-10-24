import SwiftUI
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Controls Tab (two big circles: green Pause, red End)

    var controlsTab: some View {
        let d = max(56, WatchScale.pt(70))
        let hr = workoutManager.heartRate
        let headerSize = WatchScale.pt(16)
        let labelSize = max(10, screenHeight * 0.08)
        return VStack(spacing: 0) {
            // Time + BPM: HR never leaves the screen (audit W1 / 1E).
            HStack(alignment: .firstTextBaseline) {
                ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                                 clock: workoutManager.clock,
                                 baseSize: headerSize,
                                 availableWidth: (screenWidth - 16) * 0.55,
                                 weight: .semibold,
                                 color: workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(hr > 0 ? "\(hr)" : "\u{2014}")
                        .font(.system(size: headerSize, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(ShuttlXColor.heartRate)
                        .fixedSize()
                    Text("BPM")
                        .font(.system(size: WatchScale.text(10), weight: .bold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .fixedSize()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hr > 0 ? "Heart rate \(hr) beats per minute" : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, WatchScale.pt(10))

            HStack(spacing: WatchScale.pt(16)) {
                Button(action: {
                    // Pause = stop, resume = start (Apple Workout pairing). Rest steps keep
                    // directionDown, so a pause no longer feels like a rest step.
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(workoutManager.isPaused ? .start : .stop)
                    #endif
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    controlCircle(workoutManager.isPaused ? "RESUME" : "PAUSE",
                                  fill: ShuttlXColor.ctaPrimary, text: ShuttlXColor.iconOnCTA, diameter: d)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                // No haptic on the tap: nothing has stopped yet. The confirm card plays
                // `.stop` after End & Save or Discard.
                Button(action: { endPrompt = .confirm }) {
                    controlCircle("END", fill: ShuttlXColor.ctaDestructive, text: .white, diameter: d)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End workout")
                .accessibilityHint("Asks to save and end, or keep going")
            }

            if isHighIntensityWarning {
                highIntensityWarningView(labelSize: labelSize)
                    .padding(.horizontal, 8)
                    .padding(.top, WatchScale.pt(10))
            } else if workoutManager.noHeartRateDetected {
                noHeartRateBanner(labelSize: labelSize)
                    .padding(.top, WatchScale.pt(10))
            } else {
                Text("Swipe right: back to workout")
                    .font(.system(size: WatchScale.text(11)))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .padding(.top, WatchScale.pt(14))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlCircle(_ label: String, fill: Color, text: Color, diameter: CGFloat) -> some View {
        Text(label)
            .font(.system(size: WatchScale.pt(12), weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(text)
            .lineLimit(1)
            .fixedSize()
            .frame(width: diameter, height: diameter)
            .background(fill, in: Circle())
            .contentShape(Circle())
    }
}

/// END: confirm first, Discard needs a second confirmation (audit W6 / 6B).
enum EndPromptStage { case confirm, discard }

extension TrainingView {
    /// "0:24:13 · 3.42 km" for the end card.
    var endSummaryLine: String {
        "\(FormattingUtils.formatTimer(workoutManager.elapsedTime)) \u{00B7} \(distanceText)"
    }
}

/// End & Save is the primary action; Discard is small and asks again.
struct EndWorkoutPrompt: View {
    let stage: EndPromptStage
    let summaryLine: String
    let onEndAndSave: () -> Void
    let onKeepGoing: () -> Void
    let onAskDiscard: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        switch stage {
        case .confirm:
            WatchPromptCard(announcement: "End workout? \(summaryLine)") {
                Text("End workout?")
                    .font(.system(size: WatchScale.pt(17), weight: .heavy))
                Text(summaryLine)
                    .font(.system(size: WatchScale.text(12)))
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.top, WatchScale.pt(3))
            } buttons: {
                Button("End & Save", action: onEndAndSave)
                    .buttonStyle(WatchPillButtonStyle.primary)
                    .accessibilityHint("Saves the workout and shows your summary")
                Button("Keep going", action: onKeepGoing)
                    .buttonStyle(WatchPillButtonStyle.neutral)
                    .accessibilityHint("Goes back to the workout")
                Button("Discard", action: onAskDiscard)
                    .font(.system(size: WatchScale.text(12), weight: .semibold))
                    .foregroundStyle(ShuttlXColor.ctaDestructive)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .contentShape(Rectangle().inset(by: -10))   // ~44pt hit area
                    .accessibilityHint("Asks again before deleting this workout")
            }
        case .discard:
            WatchPromptCard(announcement: "Discard this workout? It won't be saved to Health or ShuttlX.") {
                Text("Discard workout?")
                    .font(.system(size: WatchScale.pt(17), weight: .heavy))
                Text("It won't be saved to Health or ShuttlX.")
                    .font(.system(size: WatchScale.text(11)))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, WatchScale.pt(3))
            } buttons: {
                Button("Keep", action: onKeepGoing)
                    .buttonStyle(WatchPillButtonStyle.primary)
                    .accessibilityHint("Goes back to the workout")
                Button("Discard", action: onDiscard)
                    .buttonStyle(WatchPillButtonStyle.endAndSave)
                    .accessibilityHint("Deletes this workout")
            }
        }
    }
}
