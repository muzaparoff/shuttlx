import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingStopConfirmation = false
    @State private var showingSummary = false
    @State private var savedSummary: WorkoutSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if showingSummary, let summary = savedSummary {
            WorkoutSummaryView(summary: summary) {
                showingSummary = false
                savedSummary = nil
            }
        } else {
            workoutTabView
        }
    }

    private var workoutTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Full-screen stacked metrics
            workoutDisplayTab
                .tag(0)

            // Tab 2: Controls
            controlsTab
                .tag(1)
        }
        .navigationBarHidden(true)
        .tabViewStyle(PageTabViewStyle())
        .alert("Finish Workout", isPresented: $showingStopConfirmation) {
            Button("Save & Finish") {
                let summary = WorkoutSummary(
                    duration: workoutManager.elapsedTime,
                    distance: workoutManager.totalDistance,
                    avgHeartRate: workoutManager.averageHeartRate,
                    calories: workoutManager.calories,
                    steps: workoutManager.totalSteps,
                    avgPace: workoutManager.currentPace,
                    splitsCount: workoutManager.lastCompletedKm
                )
                workoutManager.saveWorkoutData()
                workoutManager.stopWorkout()
                savedSummary = summary
                showingSummary = true
            }
            Button("Discard", role: .destructive) {
                workoutManager.stopWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this training session?")
        }
    }

    // MARK: - Workout Display Tab (Full-Screen Stacked Metrics)

    private var workoutDisplayTab: some View {
        VStack(spacing: ShuttlXSpacing.xs) {
            Spacer(minLength: 0)

            // Line 1: Timer (countdown or elapsed)
            timerLine

            // Line 2: Distance
            Text(distanceText)
                .font(ShuttlXFont.watchMetricDisplay)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Distance \(accessibleDistance)")

            // Line 3: Heart rate — colored by zone
            Text(heartRateText)
                .font(ShuttlXFont.watchMetricDisplay)
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(workoutManager.heartRate > 0
                    ? "\(workoutManager.heartRate) beats per minute, \(heartRateZoneName)"
                    : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)

            // Line 4: Pace
            Text(paceText)
                .font(ShuttlXFont.watchMetricDisplay)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(accessiblePace)

            // Status badge
            if workoutManager.isPaused {
                Text("PAUSED")
                    .font(ShuttlXFont.watchStatusBadge)
                    .foregroundColor(ShuttlXColor.ctaWarning)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ShuttlXSpacing.md)
    }

    // MARK: - Timer Line

    @ViewBuilder
    private var timerLine: some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            // Interval mode: colored dot + countdown + step counter
            HStack(spacing: ShuttlXSpacing.sm) {
                if let step = engine.currentStep {
                    Circle()
                        .fill(ShuttlXColor.forStepType(step.type))
                        .frame(width: ShuttlXSize.stepDotSize, height: ShuttlXSize.stepDotSize)
                        .accessibilityLabel(step.type.displayName)
                }

                Text(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
                    .font(ShuttlXFont.watchTimerDisplay)
                    .monospacedDigit()
                    .foregroundColor(engine.currentStep.map { ShuttlXColor.forStepType($0.type) } ?? .primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
                    .font(ShuttlXFont.watchStepLabel)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Time remaining \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), step \(engine.currentStepIndex + 1) of \(engine.totalStepsCount)")
            .accessibilityAddTraits(.updatesFrequently)
        } else {
            // Free run mode: plain elapsed time
            Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                .font(ShuttlXFont.watchTimerDisplay)
                .monospacedDigit()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Controls Tab (Translucent Circles)

    private var controlsTab: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: ShuttlXSpacing.xxl) {
                // Pause / Resume
                Button(action: {
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaPrimary : ShuttlXColor.ctaPause)
                }
                .buttonStyle(ShuttlXControlButtonStyle())
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                // Finish
                Button(action: {
                    showingStopConfirmation = true
                }) {
                    Image(systemName: "stop.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(ShuttlXColor.ctaDestructive)
                }
                .buttonStyle(ShuttlXControlButtonStyle())
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            // Labels
            HStack(spacing: ShuttlXSpacing.xxl) {
                Text(workoutManager.isPaused ? "Resume" : "Pause")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(.secondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
                Text("End")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(.secondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
            }
            .padding(.top, ShuttlXSpacing.sm)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var heartRateText: String {
        guard workoutManager.heartRate > 0 else { return "-- BPM" }
        return "\(workoutManager.heartRate) BPM"
    }

    private var heartRateZoneName: String {
        let hr = workoutManager.heartRate
        if hr <= 0 { return "" }
        if hr < 104 { return "Zone 1 Easy" }
        if hr < 125 { return "Zone 2 Fat Burn" }
        if hr < 146 { return "Zone 3 Cardio" }
        if hr < 167 { return "Zone 4 Hard" }
        return "Zone 5 Peak"
    }

    private var distanceText: String {
        FormattingUtils.formatDistance(workoutManager.totalDistance)
    }

    private var accessibleDistance: String {
        let dist = workoutManager.totalDistance
        if dist < 1.0 {
            return "\(Int(dist * 1000)) meters"
        }
        return String(format: "%.2f kilometers", dist)
    }

    private var paceText: String {
        guard let pace = workoutManager.currentPace else { return "-- /KM" }
        return "\(FormattingUtils.formatPace(pace)) /KM"
    }

    private var accessiblePace: String {
        guard let pace = workoutManager.currentPace else { return "Average pace no data" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "Average pace \(minutes) minutes \(seconds) seconds per kilometer"
    }
}

// MARK: - Workout Summary Data

struct WorkoutSummary {
    let duration: TimeInterval
    let distance: Double
    let avgHeartRate: Int
    let calories: Int
    let steps: Int
    let avgPace: TimeInterval?
    let splitsCount: Int
}

// MARK: - Post-Workout Summary Screen

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(ShuttlXColor.ctaPrimary)

                Text("Workout Complete")
                    .font(ShuttlXFont.cardTitle)

                Text(FormattingUtils.formatTimer(summary.duration))
                    .font(ShuttlXFont.watchSummaryTimer)
                    .foregroundColor(.primary)

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
                }
                .padding(.horizontal)

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
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundColor(.secondary)
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
