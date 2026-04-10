import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct TrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var selectedTab = 0
    @State private var showingStopConfirmation = false
    @State private var showingSummary = false
    @State private var showingHealthKitError = false
    @State private var savedSummary: WorkoutSummary?
    @State private var pausePulse = false
    @State private var showingAuthDeniedAlert = false
    /// Tracks whether the high-intensity warning haptic has already fired this threshold crossing.
    @State private var highIntensityHapticFired = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var hrCalculator: HeartRateZoneCalculator {
        HeartRateZoneCalculator.fromSharedDefaults()
    }

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
        .alert("Health App Save Failed", isPresented: $showingHealthKitError) {
            Button("OK", role: .cancel) {
                workoutManager.healthKitSaveError = nil
            }
        } message: {
            Text(workoutManager.healthKitSaveError ?? "The workout was saved in ShuttlX but could not be written to the Health app.")
        }
        .onChange(of: workoutManager.healthKitSaveError) { _, newValue in
            showingHealthKitError = newValue != nil
        }
        .alert("Health Access Required", isPresented: $showingAuthDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("ShuttlX needs Health access to record your workout. Open the Health app or iPhone Settings to grant permission.")
        }
        .onChange(of: workoutManager.authorizationDenied) { _, isDenied in
            if isDenied {
                showingAuthDeniedAlert = true
            }
        }
    }

    // MARK: - Workout Display Tab (Full-Screen Stacked Metrics)

    @ViewBuilder
    private var workoutDisplayTab: some View {
        if isLuminanceReduced {
            aodMinimalView
        } else {
            fullWorkoutDisplayTab
        }
    }

    // MARK: - Always-On Display (Reduced Luminance)

    private var aodMinimalView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(FormattingUtils.formatTimer(workoutManager.elapsedTime))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.7))
            if workoutManager.heartRate > 0 {
                Text("\(workoutManager.heartRate) BPM")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.red.opacity(0.7))
            }
            if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine, let step = engine.currentStep {
                Text(step.type.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ShuttlXColor.forStepType(step.type).opacity(0.6))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Full Workout Display

    private var fullWorkoutDisplayTab: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let valueSize = max(20, h * 0.19)
            let labelSize = max(10, h * 0.08)
            let labelWidth = h * 0.20
            let rowSpacing = h * 0.025

            VStack(spacing: rowSpacing) {
                // Top row: workout name
                HStack {
                    Text(workoutManager.workoutName.uppercased())
                        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(workoutManager.isPaused && pausePulse ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pausePulse)
                    Spacer()
                }
                .onAppear { if workoutManager.isPaused { pausePulse = true } }

                // Timer row
                timerRow(valueSize: valueSize, labelSize: labelSize, labelWidth: labelWidth)

                // Metric rows — all same size as timer
                metricRow("DIST", distanceText, ShuttlXColor.textPrimary, valueSize, labelSize, labelWidth,
                          accessibilityText: "Distance \(accessibleDistance)")

                metricRow("HR", heartRateText, ShuttlXColor.forHRZone(workoutManager.heartRate), valueSize, labelSize, labelWidth,
                          accessibilityText: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) beats per minute" : "Heart rate no data")
                    .animation(.easeInOut(duration: 0.5), value: workoutManager.heartRate)
                    .onChange(of: workoutManager.heartRate) { _, newHR in
                        let isHigh = hrCalculator.isHighIntensityWarning(heartRate: Double(newHR))
                        if isHigh && !highIntensityHapticFired {
                            highIntensityHapticFired = true
                            #if os(watchOS)
                            WKInterfaceDevice.current().play(.notification)
                            #endif
                        } else if !isHigh {
                            highIntensityHapticFired = false
                        }
                    }

                // HIGH INTENSITY warning — shown when HR > 85% of estimated max HR
                if isHighIntensityWarning {
                    highIntensityWarningView(labelSize: labelSize)
                }

                metricRow("PACE", paceText, ShuttlXColor.textPrimary, valueSize, labelSize, labelWidth,
                          accessibilityText: accessiblePace)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ShuttlXSpacing.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Metric Row (unified for all metrics including timer)

    private func metricRow(_ label: String, _ value: String, _ color: Color,
                           _ valueSize: CGFloat, _ labelSize: CGFloat, _ labelWidth: CGFloat,
                           accessibilityText: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Timer Line

    @ViewBuilder
    private func timerRow(valueSize: CGFloat, labelSize: CGFloat, labelWidth: CGFloat) -> some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            intervalTimerLine(engine: engine)
        } else {
            metricRow("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                      ShuttlXColor.textPrimary, valueSize, labelSize, labelWidth,
                      accessibilityText: "Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
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
        guard workoutManager.heartRate > 0 else { return "\u{2014} BPM" }
        return "\(workoutManager.heartRate) BPM"
    }

    private var heartRateZoneName: String {
        let hr = workoutManager.heartRate
        guard hr > 0 else { return "" }
        return hrCalculator.zoneName(for: Double(hr))
    }

    private var isHighIntensityWarning: Bool {
        hrCalculator.isHighIntensityWarning(heartRate: Double(workoutManager.heartRate))
    }

    @ViewBuilder
    private func highIntensityWarningView(labelSize: CGFloat) -> some View {
        HStack {
            Spacer()
            Text("HIGH INTENSITY")
                .font(.system(size: max(9, labelSize * 0.85), weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.ctaDestructive)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ShuttlXColor.ctaDestructive, lineWidth: 1)
                )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.4), value: isHighIntensityWarning)
        .accessibilityLabel("High intensity warning: heart rate above 85 percent of maximum")
        .accessibilityAddTraits(.updatesFrequently)
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
