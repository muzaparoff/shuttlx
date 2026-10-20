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
}

// MARK: - Post-Workout Summary Screen

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void
    @State private var showBadge = false
    /// nil = skipped. Saved on disappear (Done), never to Health.
    @State private var effort: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                ThemedCompletionBadge()
                    .scaleEffect(reduceMotion ? 1 : (showBadge ? 1 : 0.3))
                    .opacity(showBadge ? 1 : 0)
                    .animation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.6), value: showBadge)

                Text("Workout Complete")
                    .font(ShuttlXFont.watchHeroTitle)

                Text(FormattingUtils.formatTimer(summary.duration))
                    .font(ShuttlXFont.watchSummaryTimer)
                    .foregroundColor(ShuttlXColor.textPrimary)

                // Metrics
                VStack(spacing: ShuttlXSpacing.md) {
                    if summary.distance > 0 {
                        summaryRow(icon: "location.fill", color: ShuttlXColor.running,
                                   label: "Distance", value: FormattingUtils.formatDistance(summary.distance))
                    }

                    if summary.avgHeartRate > 0 {
                        summaryRow(icon: "heart.fill", color: ShuttlXColor.heartRate,
                                   label: "Avg Heart Rate", value: "\(summary.avgHeartRate) BPM")
                    }

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

                    if summary.splitsCount > 0 {
                        summaryRow(icon: "flag.fill", color: ShuttlXColor.running,
                                   label: "Km Splits", value: "\(summary.splitsCount)")
                    }

                    if let sets = summary.completedSets {
                        summaryRow(icon: "figure.strengthtraining.traditional",
                                   color: ShuttlXColor.ctaPrimary,
                                   label: "Sets monitored", value: "\(sets)")
                    }

                    if let hrr1 = summary.averageHRR1 {
                        summaryRow(icon: "arrow.down.heart.fill",
                                   color: ShuttlXColor.heartRate,
                                   label: "Avg HRR (1min)", value: "\(Int(hrr1.rounded())) BPM")
                    }
                }
                .padding(.horizontal)
                .themedCard(
                    accent: ShuttlXColor.positive,
                    statusLine: (mode: "DONE", file: "saved", position: "ok"),
                    headerLabel: "WORKOUT"
                )

                if summary.bodyMassUnavailable {
                    // Deliberately non-blocking and single-line: the workout is
                    // saved and Apple's calories are still shown. Without a weight
                    // we simply decline to invent ShuttlX's own estimate.
                    HStack(alignment: .top, spacing: ShuttlXSpacing.xs) {
                        Image(systemName: "scalemass")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundColor(ShuttlXColor.textSecondary)
                            .accessibilityHidden(true)
                        Text("Add your weight in the Health app for accurate calories.")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundColor(ShuttlXColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                }

                if summary.sessionID != nil, WatchSyncCoordinator.shared.heartSafety.showEffortOnWatch {
                    effortPicker
                }

                // Done button — primary CTA style
                Button(action: onDismiss) {
                    Text("Done")
                        .font(ShuttlXFont.cardTitle)
                        .foregroundColor(ShuttlXColor.iconOnCTA)
                        .padding(.vertical, ShuttlXSpacing.lg)
                }
                .buttonStyle(ShuttlXPrimaryCTAStyle())
                .padding(.horizontal)
                .padding(.top, ShuttlXSpacing.md)
            }
            .padding(.vertical)
        }
        .themedScreenBackground()
        .onDisappear {
            if let effort, let id = summary.sessionID {
                WatchSyncCoordinator.shared.updateSessionEffort(id: id, effortRPE: effort)
            }
        }
        .onAppear {
            showBadge = true
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        }
    }

    /// Skippable 0-10 effort question. Wheel picker = Digital Crown for free.
    private var effortPicker: some View {
        VStack(spacing: ShuttlXSpacing.xs) {
            Text("How hard was it?")
                .font(ShuttlXFont.cardCaption)
                .foregroundColor(ShuttlXColor.textSecondary)
            Picker("How hard was it?", selection: $effort) {
                Text("Skip").tag(Int?.none)
                ForEach(0...10, id: \.self) { n in
                    Text(n == 0 ? "0 Rest" : n == 10 ? "10 Max" : "\(n)")
                        .monospacedDigit()
                        .tag(Int?.some(n))
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 56)
            .accessibilityLabel("How hard was it? 0 rest to 10 max")
        }
        .padding(.horizontal)
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

#Preview {
    NavigationStack {
        TrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}

