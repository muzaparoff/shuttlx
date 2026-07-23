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
}

// MARK: - Post-Workout Summary Screen

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void
    @State private var showBadge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                ThemedCompletionBadge()
                    .scaleEffect(reduceMotion ? 1 : (showBadge ? 1 : 0.3))
                    .opacity(showBadge ? 1 : 0)
                    .animation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.6), value: showBadge)

                if ThemeManager.shared.current.id == "mixtape" {
                    // Cassette idiom: the tape has reached the end of SIDE A.
                    VStack(spacing: ShuttlXSpacing.xs) {
                        Text("SIDE A COMPLETE")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(ShuttlXColor.ctaPrimary)
                            .tracking(1)
                        MixtapeParkedReel()
                            .frame(width: 64, height: 30)
                    }
                } else {
                    Text("Workout Complete")
                        .font(ShuttlXFont.watchHeroTitle)
                }

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
        .onAppear {
            showBadge = true
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        }
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

