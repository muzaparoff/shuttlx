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
    @State private var pausePulse = false
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
        .themedScreenBackground()
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
        VStack(spacing: ShuttlXSpacing.md) {
            // Top row: workout name left, system time handled by watchOS
            HStack {
                Text(workoutManager.workoutName.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
                    .lineLimit(1)
                    .opacity(workoutManager.isPaused && pausePulse ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pausePulse)
                Spacer()
            }
            .onAppear { if workoutManager.isPaused { pausePulse = true } }

            Spacer(minLength: 0)

            // Timer row (countdown or elapsed) — same horizontal pattern
            timerLine

            // Metric rows — label left, value right
            metricWithLabel(
                label: "DIST",
                value: distanceText,
                color: ShuttlXColor.textPrimary,
                accessibilityText: "Distance \(accessibleDistance)"
            )

            metricWithLabel(
                label: "HR",
                value: heartRateText,
                color: ShuttlXColor.forHRZone(workoutManager.heartRate),
                accessibilityText: workoutManager.heartRate > 0
                    ? "\(workoutManager.heartRate) beats per minute, \(heartRateZoneName)"
                    : "Heart rate no data"
            )
            .animation(.easeInOut(duration: 0.5), value: workoutManager.heartRate)

            metricWithLabel(
                label: "PACE",
                value: paceText,
                color: ShuttlXColor.textPrimary,
                accessibilityText: accessiblePace
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ShuttlXSpacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Metric with Label

    private func metricWithLabel(label: String, value: String, color: Color, accessibilityText: String) -> some View {
        HStack {
            Text(label)
                .font(ShuttlXFont.watchControlLabel)
                .foregroundColor(ShuttlXColor.textSecondary)
                .frame(width: 44, alignment: .leading)
            Spacer()
            Text(value)
                .font(ShuttlXFont.watchMetricSecondary)
                .monospacedDigit()
                .foregroundColor(color)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Timer Line

    @ViewBuilder
    private var timerLine: some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            // Interval mode: progress ring + countdown + step counter
            intervalTimerLine(engine: engine)
        } else {
            // Free run mode: TIME label + elapsed value (horizontal row, larger)
            HStack {
                Text("TIME")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundColor(ShuttlXColor.textSecondary)
                    .frame(width: 44, alignment: .leading)
                Spacer()
                Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                    .font(ShuttlXFont.watchTimerDisplay)
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Interval Timer with Progress Ring

    private func intervalTimerLine(engine: IntervalEngine) -> some View {
        let stepColor = engine.currentStep.map { ShuttlXColor.forStepType($0.type) } ?? ShuttlXColor.textPrimary
        let stepProgress: Double = {
            guard let step = engine.currentStep, step.duration > 0 else { return 0 }
            return 1.0 - (engine.currentStepTimeRemaining / step.duration)
        }()

        return VStack(spacing: 2) {
            // Progress ring around countdown
            ZStack {
                // Track
                Circle()
                    .stroke(stepColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 56, height: 56)

                // Progress
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(stepColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: stepProgress)

                // Countdown text inside ring
                Text(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
                    .font(ShuttlXFont.watchMetricSecondary)
                    .monospacedDigit()
                    .foregroundColor(stepColor)
                    .contentTransition(.numericText())
            }

            // Step indicator: dot + label + counter
            HStack(spacing: ShuttlXSpacing.xs) {
                if let step = engine.currentStep {
                    Circle()
                        .fill(stepColor)
                        .frame(width: 10, height: 10)
                        .accessibilityLabel(step.type.displayName)
                }

                Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
                    .font(ShuttlXFont.watchStepLabel)
                    .foregroundColor(ShuttlXColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .id(engine.currentStepIndex)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.3), value: engine.currentStepIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), step \(engine.currentStepIndex + 1) of \(engine.totalStepsCount)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Controls Tab (Translucent Circles)

    private var controlsTab: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: ShuttlXSpacing.xxl) {
                // Pause / Resume
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(workoutManager.isPaused ? .directionUp : .directionDown)
                    #endif
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
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                // Finish
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                    showingStopConfirmation = true
                }) {
                    Image(systemName: "stop.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(ShuttlXColor.ctaDestructive)
                }
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            // Labels
            HStack(spacing: ShuttlXSpacing.xxl) {
                Text(workoutManager.isPaused ? "Resume" : "Pause")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
                Text("End")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
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
    @State private var showBadge = false

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                ThemedCompletionBadge()
                    .scaleEffect(showBadge ? 1 : 0.3)
                    .opacity(showBadge ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showBadge)
                    .themeModeTag("COMPLETE")

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
