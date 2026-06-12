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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager

    @State private var hrCalculator = HeartRateZoneCalculator.fromSharedDefaults()
    #if os(watchOS)
    private let screenHeight = WKInterfaceDevice.current().screenBounds.height
    #else
    private let screenHeight: CGFloat = 224
    #endif

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
        ZStack {
            // Background sits behind the TabView as a non-interactive layer.
            // drawingGroup() was previously used here but it prevents dynamic
            // theme switching mid-workout and is unnecessary now that engine
            // objectWillChange forwarding was removed (that was the real source
            // of 3-6x/sec background re-renders).
            Color.clear
                .themedScreenBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            TabView(selection: $selectedTab) {
                // Tab 1: Full-screen stacked metrics
                workoutDisplayTab
                    .tag(0)

                // Tab 2: Controls
                controlsTab
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
        .alert("Finish Workout", isPresented: $showingStopConfirmation) {
            Button("Save & Finish") {
                let captures = workoutManager.completedCaptures
                let avgHRR1: Double? = {
                    let vals = captures.compactMap { $0.hrr1 }
                    guard !vals.isEmpty else { return nil }
                    return Double(vals.reduce(0, +)) / Double(vals.count)
                }()
                let summary = WorkoutSummary(
                    duration: workoutManager.elapsedTime,
                    distance: workoutManager.totalDistance,
                    avgHeartRate: workoutManager.averageHeartRate,
                    calories: workoutManager.calories,
                    steps: workoutManager.totalSteps,
                    avgPace: workoutManager.currentPace,
                    splitsCount: workoutManager.lastCompletedKm,
                    completedSets: workoutManager.workoutMode == .gymRecovery ? captures.count : nil,
                    averageHRR1: avgHRR1
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
        } else if workoutManager.workoutMode == .gymRecovery {
            RecoveryWorkoutView()
                .environmentObject(workoutManager)
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
                .foregroundColor(ShuttlXColor.textPrimary.opacity(0.7))
            if workoutManager.heartRate > 0 {
                Text("\(workoutManager.heartRate) BPM")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.heartRate.opacity(0.7))
            }
            if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine, let step = engine.currentStep {
                Text(step.type.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ShuttlXColor.forStepType(step.type))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Full Workout Display

    private var fullWorkoutDisplayTab: some View {
        let h = screenHeight
        let heroSize = max(44, h * 0.26)              // countdown hero — only used in interval mode
        let valueSize = max(40, h * 0.19)             // HR (still large, second-tier)
        let tertiarySize = max(16, h * 0.10)          // DIST / PACE / TIME / CAD — compact row
        let labelSize = max(10, h * 0.08)
        let labelWidth = h * 0.20
        let rowSpacing = h * 0.025

        let isInterval = workoutManager.workoutMode == .interval

        return ZStack {
            // Subtle step-type wash so the user can read state pre-attentively.
            // Hosted in a dedicated subview that observes the engine directly so
            // its body invalidation is independent of the manager's tick cadence.
            // (Reading intervalEngine?.currentStep?.type in a view modifier on the
            // main body forced re-evaluation on every manager @Published change.)
            if isInterval, let engine = workoutManager.intervalEngine {
                IntervalStepWash(engine: engine)
            }

            VStack(spacing: rowSpacing) {
                // Workout name + step pill (interval only)
                HStack(spacing: 6) {
                    Text(workoutManager.workoutName.uppercased())
                        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity((!reduceMotion && workoutManager.isPaused && pausePulse) ? 0.3 : 1.0)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pausePulse
                        )
                    Spacer()
                    // Step pill moved to the same line as the countdown hero below
                    // (intervalCountdownHero) — the workout name keeps the header
                    // to itself so the two decision-critical pieces (remaining
                    // time + phase) read together.
                }
                .onAppear { if workoutManager.isPaused && !reduceMotion { pausePulse = true } }

                // Hero: interval countdown (interval) or elapsed time (free run)
                timerRow(valueSize: valueSize, labelSize: labelSize, labelWidth: labelWidth,
                         heroSize: heroSize)

                // HR row — second tier
                HStack {
                    Text("HR")
                        .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                        .frame(width: labelWidth, alignment: .leading)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(heartRateText)
                            .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if heartRateZoneNumber > 0 {
                            Text("Z\(heartRateZoneNumber)")
                                .font(.system(size: max(10, labelSize), weight: .bold, design: .monospaced))
                                .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate).opacity(0.8))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(ShuttlXColor.forHRZone(workoutManager.heartRate).opacity(0.5), lineWidth: 1))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate) beats per minute, Zone \(heartRateZoneNumber)" : "Heart rate no data")
                .accessibilityValue(heartRateZoneNumber > 0 ? "Zone \(heartRateZoneNumber)" : "")
                .accessibilityAddTraits(.updatesFrequently)
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

                if isHighIntensityWarning {
                    highIntensityWarningView(labelSize: labelSize)
                }

                // Tertiary two-up rows: DIST / PACE then TIME / CAD
                if isInterval {
                    HStack(spacing: 8) {
                        compactMetric("DIST", distanceText, tertiarySize, labelSize)
                        compactMetric("PACE", paceText, tertiarySize, labelSize)
                    }
                    HStack(spacing: 8) {
                        compactMetric("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                                      tertiarySize, labelSize)
                        compactMetric("SPM",
                                      workoutManager.currentCadence > 0 ? "\(workoutManager.currentCadence)" : "—",
                                      tertiarySize, labelSize)
                    }
                } else {
                    // Free-run: compact two-up rows for tertiary metrics. Three
                    // full-size metricRow calls (DIST/PACE/CAD at ~42pt each) +
                    // TIME hero + HR row exceeded the 41mm watch's ~180pt usable
                    // height and pushed the HR row off-screen — the cause of the
                    // long-standing "BPM not showing in walk/run" complaint.
                    HStack(spacing: 8) {
                        compactMetric("DIST", distanceText, tertiarySize, labelSize)
                        compactMetric("PACE", paceText, tertiarySize, labelSize)
                    }
                    HStack(spacing: 8) {
                        compactMetric("SPM",
                                      workoutManager.currentCadence > 0 ? "\(workoutManager.currentCadence)" : "—",
                                      tertiarySize, labelSize)
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ShuttlXSpacing.xs)
            .padding(.leading, themeManager.current.id == "fmtuner" ? 5 : (themeManager.current.id == "mixtape" ? 60 : 0))
            .padding(.trailing, themeManager.current.id == "vumeter" ? 18 : 0)
            .padding(.top, watchTimerTopPadding(themeManager.current.id))
            .padding(.bottom, watchTimerBottomPadding(themeManager.current.id))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Synthwave chrome — non-interactive backdrop, only when active.
            // Renders horizon grid + sun halo + timer bloom behind the metrics.
            // No frame, no chevron, no needle gauges (cut from the iPhone variant).
            if themeManager.current.id == "synthwave" {
                SynthwaveTimerOverlay(workoutManager: workoutManager)
            }

            // Mixtape chrome — non-interactive single reel pinned to the
            // upper-left, spinning with elapsed time. Cassette body shell,
            // second reel, and transport row from the iPhone variant are cut
            // (see MixtapeTimerOverlay header for rationale). The metrics
            // VStack above gets a 60pt leading inset so HR / step / step-pill
            // never sit under the reel.
            if themeManager.current.id == "mixtape" {
                MixtapeTimerOverlay(workoutManager: workoutManager)
            }

            // Arcade chrome — non-interactive pixel-border bezel + faint
            // scanline backdrop. The iPhone variant's 7-segment HI-SCORE
            // digits, ★ HI-SCORE ★ banner, interval-dot row, and WORK power
            // bar are all cut for the watch (see ArcadeTimerOverlay header).
            // The metrics VStack above gets a 6pt top/bottom inset so the HR
            // row and tertiary metrics clear the pixel border.
            if themeManager.current.id == "arcade" {
                ArcadeTimerOverlay(workoutManager: workoutManager)
            }

            // Classic Radio chrome — non-interactive thin tuning-dial strip
            // pinned to the top, plus a wood-grain backdrop band behind it.
            // The iPhone variant's bakelite knobs (TONE / VOLUME / BAND),
            // brand plate header, and station-name labels are all cut for
            // the watch (see ClassicRadioTimerOverlay header). The dial is
            // demoted from hero to a "you are here" progress strip — the
            // amber backlit numeric the base TrainingView already paints in
            // monospaced is the actual hero. The metrics VStack above gets
            // a 16pt top inset so the workout-name row + step pill clear
            // the dial strip.
            if themeManager.current.id == "classicradio" {
                ClassicRadioTimerOverlay(workoutManager: workoutManager)
            }

            // VU Meter chrome — non-interactive vertical VU strip pinned to
            // the right edge with an HR-driven needle and a peak-hold LED at
            // the top. The iPhone variant's horizontal arc, secondary step-
            // countdown needle, side strips, and "rec level" pace caption
            // are all cut for the watch (see VUMeterTimerOverlay header).
            // The metrics VStack above gets an 18pt trailing inset so the HR
            // row and tertiary metrics clear the strip.
            if themeManager.current.id == "vumeter" {
                VUMeterTimerOverlay(workoutManager: workoutManager)
            }

            // Neovim chrome — non-interactive nvim buffer chrome: top tabline
            // strip with `workout.log [+]` filename, left line-number gutter
            // with a single bright CursorLineNr digit, and a bottom modal
            // status line (`-- INSERT --` WORK / `-- NORMAL --` REST / `-- VISUAL --`
            // PAUSED). The iPhone variant's 11-line buffer view, multi-line
            // `step[3] = { ... }` block, `~` empty-line column, `:` command
            // line, and ruler are all cut for the watch (see NeovimTimerOverlay
            // header for the cut list). The metrics VStack above gets a 16pt
            // top and bottom inset so the workout-name row + step pill clear
            // the tabline, and the HR row + tertiary metrics clear the
            // status line.
            if themeManager.current.id == "neovim" {
                NeovimTimerOverlay(workoutManager: workoutManager)
            }

            // FM Tuner chrome — non-interactive overlays, only when active
            if themeManager.current.id == "fmtuner" {
                VStack(spacing: 0) {
                    FMTunerCompactHeader()
                    Spacer()
                    FMTunerSingleLineFooter(text: watchFMFooterText)
                        .padding(.horizontal, ShuttlXSpacing.xs)
                        .padding(.bottom, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                HStack(alignment: .top, spacing: 0) {
                    FMTunerWatchVUColumn(level: watchVULevel)
                        .padding(.top, 20)
                        .padding(.leading, 1)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
    }

    // Compact two-up metric (used in interval mode's tertiary rows).
    // MARK: - Theme Padding Helpers

    /// Top padding for the metrics VStack in `fullWorkoutDisplayTab`, keyed by theme id.
    /// Extracted from a nested ternary to aid readability and future maintenance.
    private func watchTimerTopPadding(_ themeID: String) -> CGFloat {
        switch themeID {
        case "fmtuner":     return 18
        case "synthwave":   return 4
        case "arcade":      return 6
        case "classicradio": return 16
        case "neovim":      return 16
        default:            return 0
        }
    }

    /// Bottom padding for the metrics VStack in `fullWorkoutDisplayTab`, keyed by theme id.
    private func watchTimerBottomPadding(_ themeID: String) -> CGFloat {
        switch themeID {
        case "fmtuner":   return 16
        case "synthwave": return 6
        case "arcade":    return 6
        case "neovim":    return 16
        default:          return 0
        }
    }

    private func compactMetric(_ label: String, _ value: String,
                               _ valueSize: CGFloat, _ labelSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Timer Line

    @ViewBuilder
    private func timerRow(valueSize: CGFloat, labelSize: CGFloat, labelWidth: CGFloat, heroSize: CGFloat) -> some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            intervalCountdownHero(engine: engine, heroSize: heroSize, labelSize: labelSize)
        } else {
            metricRow("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                      ShuttlXColor.textPrimary, valueSize, labelSize, labelWidth,
                      accessibilityText: "Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
        }
    }

    // MARK: - Interval Countdown Hero (replaces the old 56pt progress ring)
    //
    // The countdown to the next interval transition is the most decision-critical
    // number on the screen during interval work. It must be the largest element so
    // a sweaty mid-treadmill glance reads it immediately. A thin capsule progress
    // bar beneath conveys remaining time pre-attentively without the battery cost
    // of a continuously redrawn radial ring.
    private func intervalCountdownHero(engine: IntervalEngine, heroSize: CGFloat, labelSize: CGFloat) -> some View {
        let stepColor = engine.currentStep.map { ShuttlXColor.forStepType($0.type) } ?? ShuttlXColor.textPrimary
        let stepProgress: Double = {
            guard let step = engine.currentStep, step.duration > 0 else { return 0 }
            return 1.0 - (engine.currentStepTimeRemaining / step.duration)
        }()

        return VStack(spacing: 4) {
            // Countdown + phase pill on the same row — saves vertical space and
            // pairs the two most decision-critical bits (remaining time + which
            // phase you're in).
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
                    .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(stepColor)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let step = engine.currentStep {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.type.displayName.uppercased())
                            .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                            .foregroundColor(stepColor)
                            .lineLimit(1)
                        Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
                            .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                            .foregroundColor(ShuttlXColor.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(stepColor.opacity(0.15))
                    Capsule()
                        .fill(stepColor)
                        .frame(width: max(0, proxy.size.width * stepProgress))
                        .animation(.linear(duration: 1), value: stepProgress)
                }
            }
            .frame(height: 3)
            .frame(maxWidth: heroSize * 2.4)   // arc never wider than the digits
        }
        .frame(maxWidth: .infinity)
        .id(engine.currentStepIndex)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: engine.currentStepIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining in \(engine.currentStep?.type.displayName ?? "step"), \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), step \(engine.currentStepIndex + 1) of \(engine.totalStepsCount)")
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

    private var watchVULevel: Double {
        guard workoutManager.heartRate > 0 else { return 0 }
        return min(1.0, Double(workoutManager.heartRate) / 200.0)
    }

    private var watchFMFooterText: String {
        let t = FormattingUtils.formatTimer(workoutManager.elapsedTime)
        if workoutManager.workoutMode == .interval,
           let step = workoutManager.intervalEngine?.currentStep {
            return "\(step.type.displayName.uppercased()) · \(t)"
        }
        return "\(workoutManager.workoutName.uppercased()) · \(t)"
    }

    private var heartRateText: String {
        guard workoutManager.heartRate > 0 else { return "\u{2014} BPM" }
        return "\(workoutManager.heartRate) BPM"
    }

    private var heartRateZoneName: String {
        let hr = workoutManager.heartRate
        guard hr > 0 else { return "" }
        return hrCalculator.zoneName(for: Double(hr))
    }

    private var heartRateZoneNumber: Int {
        hrCalculator.zone(for: Double(workoutManager.heartRate))
    }

    private var isHighIntensityWarning: Bool {
        hrCalculator.isHighIntensityWarning(heartRate: Double(workoutManager.heartRate))
    }

    @ViewBuilder
    private func highIntensityWarningView(labelSize: CGFloat) -> some View {
        HStack {
            Spacer()
            Text("Heart rate high — ease off")
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
        .accessibilityLabel("Heart rate high — ease off. Heart rate above 70 percent of maximum.")
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

// MARK: - Interval Step Wash
//
// Observes the IntervalEngine directly (not through WatchWorkoutManager) so its
// body re-evaluation is decoupled from the manager's once-per-second elapsedTime
// publish. The wash only redraws when the engine's `currentStep` actually changes,
// not on every metric tick.
private struct IntervalStepWash: View {
    @ObservedObject var engine: IntervalEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let step = engine.currentStep {
            ShuttlXColor.forStepType(step.type)
                .opacity(0.08)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4),
                           value: step.type)
        }
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
