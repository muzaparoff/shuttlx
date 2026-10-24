import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

// MARK: - Workout Summary Data

struct WorkoutSummary {
    let duration: TimeInterval
    let distance: Double
    let avgHeartRate: Int
    let calories: Int
    let steps: Int
    let avgPace: TimeInterval?
    let splitsCount: Int
    var completedSets: Int? = nil
    var averageHRR1: Double? = nil
    /// No body mass in Health (or read access withheld), so ShuttlX's per-phase
    /// MET calorie estimate was suppressed rather than run against a placeholder
    /// weight — Phase 2 / plan item 5.
    var bodyMassUnavailable: Bool = false
    /// Id of the saved TrainingSession, so the effort answer can be attached to it.
    var sessionID: UUID? = nil
    /// Finalized parts, for the summary ribbon.
    var segments: [ActivitySegment] = []
}

// MARK: - Post-Workout Summary Screen (timeline mockup watch screens 7 + 8)

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void
    @EnvironmentObject private var workoutManager: WatchWorkoutManager
    /// Done -> the effort screen (when enabled), whose Save/Skip dismisses.
    @State private var showingEffort: Bool

    init(summary: WorkoutSummary, startOnEffort: Bool = false, onDismiss: @escaping () -> Void) {
        self.summary = summary
        self.onDismiss = onDismiss
        _showingEffort = State(initialValue: startOnEffort)
    }

    private var asksEffort: Bool {
        summary.sessionID != nil && WatchSyncCoordinator.shared.heartSafety.showEffortOnWatch
    }

    var body: some View {
        if showingEffort {
            EffortView(
                onSave: { value in
                    if let id = summary.sessionID {
                        WatchSyncCoordinator.shared.updateSessionEffort(id: id, effortRPE: value)
                    }
                    onDismiss()
                },
                onSkip: onDismiss
            )
        } else {
            summaryPage
        }
    }

    private var summaryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("WORKOUT COMPLETE")
                    .font(.system(size: WatchScale.text(11), weight: .bold))
                    .tracking(WatchScale.text(11) * 0.08)
                    .foregroundStyle(ShuttlXColor.ctaPrimary)
                Text(FormattingUtils.formatTimer(summary.duration))
                    .font(.system(size: WatchScale.pt(38), weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .fixedSize()
                    .padding(.top, WatchScale.pt(6))
                if !summary.segments.isEmpty {
                    ActivityRibbon(segments: summary.segments, height: WatchScale.pt(8))
                        .padding(.top, WatchScale.pt(8))
                }
                HStack(alignment: .firstTextBaseline) {
                    if summary.distance > 0 {
                        valueUnit(String(format: "%.1f", summary.distance), "km", ShuttlXColor.textPrimary)
                    }
                    Spacer(minLength: 4)
                    if summary.avgHeartRate > 0 {
                        valueUnit("\(summary.avgHeartRate)", "bpm", ShuttlXColor.heartRate)
                    }
                }
                .padding(.top, WatchScale.pt(12))
                // Saved only after HealthKit confirmed finishWorkout(). The failure
                // line replaces the old TrainingView alert, which was set after this
                // screen had already replaced the workout and so never appeared.
                if workoutManager.healthKitSaved {
                    Text("Saved to Health \u{2713}")
                        .font(.system(size: WatchScale.text(11)))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .padding(.top, WatchScale.pt(4))
                } else if workoutManager.healthKitSaveError != nil {
                    Text("Not saved to Health")
                        .font(.system(size: WatchScale.text(11), weight: .semibold))
                        .foregroundStyle(ShuttlXColor.ctaWarning)
                        .padding(.top, WatchScale.pt(4))
                        .accessibilityLabel("Not saved to Health. The workout is kept in ShuttlX.")
                }
                Button("Done") {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                    if asksEffort { showingEffort = true } else { onDismiss() }
                }
                .buttonStyle(WatchPillButtonStyle.primary)
                .padding(.top, WatchScale.pt(12))
            }
            .padding(.horizontal, 8)

            // Below the fold: everything the mockup's first screen leaves out.
            extraRows
                .padding(.horizontal, 8)
                .padding(.top, WatchScale.pt(20))
        }
        .scrollIndicators(.hidden)
        // One haptic for the Health outcome, when it is known: success when saved,
        // failure for "Not saved to Health" (it used to play success either way).
        .onChange(of: healthOutcome, initial: true) { _, outcome in
            #if os(watchOS)
            switch outcome {
            case true?: WKInterfaceDevice.current().play(.success)
            case false?: WKInterfaceDevice.current().play(.failure)
            case nil: break
            }
            #endif
        }
    }

    /// nil until HealthKit answers; true saved, false failed.
    private var healthOutcome: Bool? {
        workoutManager.healthKitSaved ? true : workoutManager.healthKitSaveError != nil ? false : nil
    }

    private func valueUnit(_ value: String, _ unit: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: WatchScale.pt(20), weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: WatchScale.pt(13)))
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var extraRows: some View {
        VStack(spacing: ShuttlXSpacing.md) {
            if summary.calories > 0 {
                summaryRow(icon: "flame.fill", color: ShuttlXColor.calories,
                           label: "Calories", value: "\(summary.calories) kcal")
            }
            if let pace = summary.avgPace, pace > 0, pace < 3600 {
                summaryRow(icon: "gauge.with.dots.needle.33percent", color: ShuttlXColor.pace,
                           label: "Avg Pace", value: FormattingUtils.formatPace(pace))
            }
            if summary.steps > 0 {
                summaryRow(icon: "shoeprints.fill", color: ShuttlXColor.steps,
                           label: "Steps", value: "\(summary.steps)")
            }
            if let sets = summary.completedSets {
                summaryRow(icon: "figure.strengthtraining.traditional", color: ShuttlXColor.ctaPrimary,
                           label: "Sets monitored", value: "\(sets)")
            }
            if let hrr1 = summary.averageHRR1 {
                summaryRow(icon: "arrow.down.heart.fill", color: ShuttlXColor.heartRate,
                           label: "Avg HRR (1min)", value: "\(Int(hrr1.rounded())) BPM")
            }
            if summary.bodyMassUnavailable {
                // Non-blocking: without a weight ShuttlX declines to invent its own estimate.
                Text("Add your weight in the Health app for accurate calories.")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundColor(ShuttlXColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, ShuttlXSpacing.lg)
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(ShuttlXFont.cardCaption)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundColor(ShuttlXColor.textSecondary)
            Spacer()
            Text(value)
                .font(ShuttlXFont.watchSummaryMetric)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Effort 0-10 (Digital Crown)

struct EffortView: View {
    let onSave: (Int) -> Void
    let onSkip: () -> Void
    @State private var crown: Double = 5
    @FocusState private var focused: Bool

    private var value: Int { Int(crown.rounded()) }

    /// Borg CR10 anchors (mockup: 6 = "Hard").
    static func word(_ n: Int) -> String {
        switch n {
        case 0: return "Rest"
        case 1: return "Very easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Somewhat hard"
        case 5, 6: return "Hard"
        case 7, 8, 9: return "Very hard"
        default: return "Max"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // One adjustable element for VoiceOver: swipe up/down = the Crown.
            VStack(spacing: 0) {
                Text("How hard was it?")
                    .font(.system(size: WatchScale.pt(15), weight: .heavy))
                Text("\(value)")
                    .font(.system(size: WatchScale.pt(58), weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.ctaWarning)
                    .fixedSize()
                Text(Self.word(value))
                    .font(.system(size: WatchScale.pt(12), weight: .bold))
                    .foregroundStyle(ShuttlXColor.ctaWarning)
                HStack(spacing: 3) {
                    ForEach(0...10, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i <= value ? ShuttlXColor.ctaWarning : Color.white.opacity(0.14))
                            .frame(height: WatchScale.pt(8))
                    }
                }
                .padding(.top, WatchScale.pt(10))
                HStack {
                    Text("0 rest")
                    Spacer()
                    Text("10 max")
                }
                .font(.system(size: WatchScale.text(10)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.top, WatchScale.pt(4))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("How hard was it?")
            .accessibilityValue("\(value) of 10, \(Self.word(value))")
            .accessibilityHint("Swipe up or down, or turn the Digital Crown, to change.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: crown = min(10, Double(value + 1))
                case .decrement: crown = max(0, Double(value - 1))
                @unknown default: break
                }
            }
            HStack(spacing: 6) {
                Button("Skip", action: onSkip)
                    .buttonStyle(WatchPillButtonStyle.neutral)
                    .accessibilityHint("Closes without saving an effort")
                Button("Save") { onSave(value) }
                    .buttonStyle(WatchPillButtonStyle.primary)
                    .accessibilityHint("Saves effort \(value) of 10")
            }
            .padding(.top, WatchScale.pt(8))
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($focused)
        .digitalCrownRotation($crown, from: 0, through: 10, by: 1, sensitivity: .low,
                              isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { focused = true }
    }
}

#Preview {
    NavigationStack {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}

