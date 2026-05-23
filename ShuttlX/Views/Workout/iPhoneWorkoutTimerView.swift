import SwiftUI
import ShuttlXShared

/// Full-screen iPhone workout view. Drives `iPhoneWorkoutController` and
/// renders a mode-branched body:
///
///   - `.freeRun`     — elapsed timer hero + metric grid
///   - `.interval`    — step-countdown hero with step-color wash + step pill
///                      + tertiary 2-up rows; identical visual hierarchy to
///                      the watch's Sprint-2 design, scaled up for iPhone
///   - `.gymRecovery` — idle/work/rest sub-views mirroring the watch's
///                      `RecoveryWorkoutView`
///
/// Theme-aware (`.themedScreenBackground()` + `ShuttlXColor.*` / `ShuttlXFont.*`)
/// across all 7 themes. Controls bar is sticky at the bottom with safe-area
/// insets honored. Presented as `.fullScreenCover` so the workout dominates
/// the device during the session.
struct iPhoneWorkoutTimerView: View {
    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack {
            // Step-color wash (interval mode only). 8% opacity is the cap that
            // doesn't crush text contrast against Classic Radio / Neovim grounds.
            if let washColor = intervalStepColor {
                washColor
                    .opacity(0.08)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4),
                               value: controller.intervalEngine?.currentStep?.label)
            }

            if themeManager.current.id == "fmtuner" {
                fmTunerContent
            } else {
                VStack(spacing: 24) {
                    header
                    heroSection
                    metricsSection
                    Spacer(minLength: 0)
                    controlsBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
        .themedScreenBackground()
        .alert("Finish Workout", isPresented: $showingFinishConfirmation) {
            Button("Save & Finish") {
                _ = controller.finish()
                dismiss()
            }
            Button("Discard", role: .destructive) {
                controller.cancel()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save this workout to your history?")
        }
        .alert("Cancel Workout?", isPresented: $showingCancelConfirmation) {
            Button("Discard", role: .destructive) {
                controller.cancel()
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("This will end the workout without saving.")
        }
    }

    // MARK: - Header (workout name + step pill)

    private var header: some View {
        HStack(spacing: 8) {
            Text(controller.workoutName.uppercased())
                .font(ShuttlXFont.sectionHeader)
                .foregroundStyle(controller.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if controller.mode == .interval,
               let engine = controller.intervalEngine,
               let step = engine.currentStep {
                HStack(spacing: 6) {
                    Circle()
                        .fill(stepColor(for: step.type))
                        .frame(width: 8, height: 8)
                    Text(displayName(for: step.type).uppercased())
                        .font(ShuttlXFont.cardCaption.weight(.bold))
                        .foregroundStyle(stepColor(for: step.type))
                    Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(stepColor(for: step.type).opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Hero (the largest element on screen)

    @ViewBuilder
    private var heroSection: some View {
        switch controller.mode {
        case .freeRun:
            elapsedTimerHero
        case .interval:
            intervalCountdownHero
        case .gymRecovery:
            recoveryHero
        }
    }

    /// Free-run hero: elapsed time, theme-tinted.
    private var elapsedTimerHero: some View {
        VStack(spacing: 4) {
            Text(FormattingUtils.formatTimer(controller.elapsedTime))
                .font(.system(size: 88, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.textPrimary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("ELAPSED")
                .font(ShuttlXFont.cardCaption.weight(.bold))
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Interval hero: step countdown with capsule progress bar — same visual
    /// language as the watch's `intervalCountdownHero`, scaled up.
    private var intervalCountdownHero: some View {
        let engine = controller.intervalEngine
        let stepColor = engine?.currentStep.map { ShuttlXColor.forStepType(appType(for: $0.type)) } ?? ShuttlXColor.textPrimary
        let progress: Double = {
            guard let step = engine?.currentStep, step.duration > 0,
                  let remaining = engine?.currentStepTimeRemaining else { return 0 }
            return 1.0 - (remaining / step.duration)
        }()
        let remaining = engine?.currentStepTimeRemaining ?? 0

        return VStack(spacing: 8) {
            Text(FormattingUtils.formatTimer(max(0, remaining)))
                .font(.system(size: 104, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(stepColor)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(stepColor.opacity(0.15))
                    Capsule()
                        .fill(stepColor)
                        .frame(width: max(0, proxy.size.width * progress))
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining in \(engine?.currentStep.map { displayName(for: $0.type) } ?? "step"), \(FormattingUtils.formatTimeAccessible(remaining))")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Gym-recovery hero — single unified layout in every state (Sprint 7
    /// redesign). HR is permanently the largest number on screen; the state
    /// pill above + station/rest clock under it communicate "where in the
    /// flow am I", and the two stacked buttons (rendered separately, in the
    /// controls bar) drive the manual transitions.
    private var recoveryHero: some View {
        let bpm = controller.heartRateMonitor.current
        let isRest = controller.recoveryState == .rest

        return VStack(spacing: 10) {
            // State pill — READY / STATION N · station-elapsed / REST · rest-elapsed
            recoveryStatePill

            // HR hero — 104pt in every state (the audit's #1 ask)
            Text(bpm > 0 ? "\(bpm)" : "—")
                .font(.system(size: 104, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(bpm > 0 ? ShuttlXColor.forHRZone(bpm) : ShuttlXColor.textSecondary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("BPM")
                    .font(ShuttlXFont.cardCaption.weight(.bold))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                if bpm > 0 {
                    Text(hrZoneLabel(bpm))
                        .font(ShuttlXFont.cardCaption.weight(.bold))
                        .foregroundStyle(ShuttlXColor.forHRZone(bpm))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .stroke(ShuttlXColor.forHRZone(bpm).opacity(0.5), lineWidth: 1))
                }
                // Recovering arrow during rest (green when HR safely back in Z1/Z2)
                if isRest && bpm > 0 {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(isHRSafe(bpm)
                                         ? ShuttlXColor.ctaPrimary.opacity(0.7)
                                         : ShuttlXColor.heartRate.opacity(0.7))
                }
            }

            // HRR milestone pills — only during rest
            if isRest {
                HStack(spacing: 12) {
                    milestoneBadge(label: "1:00",
                                   reached: controller.restElapsedTime >= 60,
                                   value: controller.latestHRR1)
                    milestoneBadge(label: "2:00",
                                   reached: controller.restElapsedTime >= 120,
                                   value: controller.latestHRR2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0
                            ? "Heart rate \(bpm) beats per minute, \(recoveryStateA11yLabel)"
                            : "Heart rate no data, \(recoveryStateA11yLabel)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var recoveryStatePill: some View {
        let (text, color): (String, Color) = {
            switch controller.recoveryState {
            case .idle:
                return ("READY", ShuttlXColor.textSecondary)
            case .work:
                return (
                    "STATION \(controller.recoverySetNumber) · \(FormattingUtils.formatTimer(controller.stationElapsedTime))",
                    ShuttlXColor.ctaPrimary
                )
            case .rest:
                return (
                    "REST · \(FormattingUtils.formatTimer(controller.restElapsedTime))",
                    ShuttlXColor.ctaWarning
                )
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(ShuttlXFont.cardTitle.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var recoveryStateA11yLabel: String {
        switch controller.recoveryState {
        case .idle: return "ready to start a station"
        case .work: return "on station \(controller.recoverySetNumber)"
        case .rest: return "resting between stations"
        }
    }

    // MARK: - Metrics section (mode-branched)

    @ViewBuilder
    private var metricsSection: some View {
        switch controller.mode {
        case .freeRun:
            freeRunMetricsGrid
        case .interval:
            intervalMetricsRows
        case .gymRecovery:
            EmptyView()
        }
    }

    private var freeRunMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            heartRateCard
            metricCard(label: "DIST",
                       value: FormattingUtils.formatDistance(controller.totalDistance),
                       color: ShuttlXColor.running)
            metricCard(label: "PACE",
                       value: controller.currentPace.map { FormattingUtils.formatPace($0) } ?? "—",
                       color: ShuttlXColor.pace)
            metricCard(label: "STEPS",
                       value: "\(controller.totalSteps)",
                       color: ShuttlXColor.steps)
            metricCard(label: "CAD",
                       value: controller.currentCadence > 0 ? "\(controller.currentCadence)" : "—",
                       color: ShuttlXColor.steps)
        }
    }

    private var intervalMetricsRows: some View {
        VStack(spacing: 10) {
            heartRateCard
            HStack(spacing: 10) {
                metricCard(label: "DIST",
                           value: FormattingUtils.formatDistance(controller.totalDistance),
                           color: ShuttlXColor.running,
                           compact: true)
                metricCard(label: "PACE",
                           value: controller.currentPace.map { FormattingUtils.formatPace($0) } ?? "—",
                           color: ShuttlXColor.pace,
                           compact: true)
            }
            HStack(spacing: 10) {
                metricCard(label: "TIME",
                           value: FormattingUtils.formatTimer(controller.elapsedTime),
                           color: ShuttlXColor.textPrimary,
                           compact: true)
                metricCard(label: "CAD",
                           value: controller.currentCadence > 0 ? "\(controller.currentCadence)" : "—",
                           color: ShuttlXColor.steps,
                           compact: true)
            }
        }
    }

    /// HR card with source-device name pill (Apple Watch / Powerbeats Pro 2 /
    /// AirPods Pro 3 / etc.). This is the surface the user sees confirming
    /// which device is feeding HR data to the workout.
    private var heartRateCard: some View {
        let monitor = controller.heartRateMonitor
        let bpm = monitor.current
        let noSource = monitor.noSourceDetected
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: noSource ? "heart.slash.fill" : "heart.fill")
                .foregroundStyle(noSource ? ShuttlXColor.textSecondary : ShuttlXColor.heartRate)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bpm > 0 ? "\(bpm)" : "—")
                        .font(ShuttlXFont.metricMedium)
                        .monospacedDigit()
                        .foregroundStyle(bpm > 0
                                         ? ShuttlXColor.forHRZone(bpm)
                                         : ShuttlXColor.textSecondary)
                    Text("BPM")
                        .font(ShuttlXFont.cardCaption.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                    if bpm > 0 {
                        Text(hrZoneLabel(bpm))
                            .font(ShuttlXFont.cardCaption.weight(.bold))
                            .foregroundStyle(ShuttlXColor.forHRZone(bpm))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(ShuttlXColor.forHRZone(bpm).opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                // Three source states:
                //   1. Got a sample → show device name (Apple Watch / Powerbeats Pro 2 / AirPods Pro 3 / strap)
                //   2. No sample yet, < 10s in → "Searching for HR source…"
                //   3. No sample after 10s → actionable: "No HR source detected — pair Apple Watch, AirPods Pro, or Powerbeats Pro 2"
                if let source = monitor.sourceName {
                    Text(source)
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .lineLimit(1)
                } else if noSource {
                    Text("No HR source detected")
                        .font(ShuttlXFont.cardCaption.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.ctaWarning)
                    Text("Pair Apple Watch, AirPods Pro, or Powerbeats Pro 2 to record heart rate.")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Searching for HR source…")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .themedCard(accent: noSource ? ShuttlXColor.textSecondary : ShuttlXColor.heartRate)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if bpm > 0 {
                return "Heart rate \(bpm) beats per minute\(monitor.sourceName.map { " from \($0)" } ?? "")"
            }
            if noSource {
                return "No heart rate source detected. Pair Apple Watch, AirPods Pro, or Powerbeats Pro 2 to record heart rate."
            }
            return "Searching for heart rate source"
        }())
    }

    private func metricCard(label: String, value: String, color: Color, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ShuttlXFont.cardCaption.weight(.bold))
                .foregroundStyle(ShuttlXColor.textSecondary)
            Text(value)
                .font(compact ? ShuttlXFont.metricSmall : ShuttlXFont.metricMedium)
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 14)
        .themedCard(accent: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Controls bar (sticky bottom)

    private var controlsBar: some View {
        VStack(spacing: 12) {
            // Gym Recovery only — two stacked station buttons (Start/End) above the
            // global Pause/Finish/Cancel row. Mutually exclusive: only one enabled
            // at a time based on the segmenter state.
            if controller.mode == .gymRecovery {
                let canStartStation = controller.recoveryState != .work
                let canEndStation = controller.recoveryState == .work

                Button {
                    controller.manualStartStation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Station")
                            .font(ShuttlXFont.cardTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(canStartStation ? ShuttlXColor.ctaPrimary : ShuttlXColor.surface))
                    .foregroundStyle(canStartStation ? .white : ShuttlXColor.textSecondary)
                    .overlay(canStartStation ? nil : Capsule().stroke(ShuttlXColor.surfaceBorder, lineWidth: 1))
                }
                .disabled(!canStartStation)
                .accessibilityLabel("Start Station")
                .accessibilityHint(controller.recoveryState == .rest
                                   ? "Begins the next station and records this rest period"
                                   : "Begins station 1 of your gym recovery workout")

                Button {
                    controller.manualEndStation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("End Station")
                            .font(ShuttlXFont.cardTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(canEndStation ? ShuttlXColor.ctaDestructive : ShuttlXColor.surface))
                    .foregroundStyle(canEndStation ? .white : ShuttlXColor.textSecondary)
                    .overlay(canEndStation ? nil : Capsule().stroke(ShuttlXColor.surfaceBorder, lineWidth: 1))
                }
                .disabled(!canEndStation)
                .accessibilityLabel("End Station")
                .accessibilityHint("Ends the current station and starts a rest period with HRR captures")
            }

            // Global controls — Cancel / Skip Step (interval only) / Pause / Finish
            HStack(spacing: 12) {
                Button {
                    showingCancelConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.bold))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(ShuttlXColor.surface))
                        .overlay(Circle().stroke(ShuttlXColor.surfaceBorder, lineWidth: 1))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                .accessibilityLabel("Cancel workout")
                .accessibilityHint("Ends without saving")

                if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                    Button {
                        controller.skipStep()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title3.weight(.bold))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(ShuttlXColor.surface))
                            .overlay(Circle().stroke(ShuttlXColor.surfaceBorder, lineWidth: 1))
                            .foregroundStyle(ShuttlXColor.textPrimary)
                    }
                    .accessibilityLabel("Skip step")
                }

                Button {
                    if controller.isPaused { controller.resume() } else { controller.pause() }
                } label: {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(ShuttlXColor.ctaPrimary))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

                Button {
                    showingFinishConfirmation = true
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(ShuttlXColor.ctaDestructive))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves and ends")
            }
        }
    }

    // MARK: - FM Tuner Layout

    private var fmTunerContent: some View {
        VStack(spacing: 0) {
            FMTunerHeader()

            HStack(alignment: .top, spacing: 8) {
                FMTunerVUColumn(value: vuLevel)
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    header
                    heroSection
                    fmTunerSubValues
                    metricsSection
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            FMTunerFooter(lines: fmFooterLines)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            controlsBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var fmTunerSubValues: some View {
        if controller.mode == .interval, let engine = controller.intervalEngine {
            HStack {
                Text("◄ STEP \(engine.currentStepIndex + 1)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                Spacer()
                Text("\(engine.totalStepsCount - engine.currentStepIndex - 1) LEFT ►")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        } else if controller.mode == .freeRun {
            HStack {
                Text("◄ \(FormattingUtils.formatDistance(controller.totalDistance))")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                Spacer()
                if let pace = controller.currentPace {
                    Text("\(FormattingUtils.formatPace(pace)) /KM ►")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var vuLevel: Double {
        let bpm = controller.heartRateMonitor.current
        guard bpm > 0 else { return 0 }
        return min(1.0, Double(bpm) / 200.0)
    }

    private var fmFooterLines: [String] {
        let elapsed = FormattingUtils.formatTimer(controller.elapsedTime)
        switch controller.mode {
        case .freeRun:
            return ["\(controller.workoutName.uppercased()) · \(elapsed) · LIVE"]
        case .interval:
            let stepInfo = controller.intervalEngine.flatMap { e in
                e.currentStep.map { s in
                    "\(self.displayName(for: s.type).uppercased()) \(e.currentStepIndex + 1)/\(e.totalStepsCount)"
                }
            } ?? "—"
            return ["\(controller.workoutName.uppercased()) · \(elapsed)", stepInfo]
        case .gymRecovery:
            let stateText: String
            switch controller.recoveryState {
            case .idle: stateText = "READY"
            case .work: stateText = "STATION \(controller.recoverySetNumber)"
            case .rest: stateText = "REST"
            }
            return ["\(controller.workoutName.uppercased()) · \(elapsed)", stateText]
        }
    }

    // MARK: - Helpers

    private var intervalStepColor: Color? {
        guard controller.mode == .interval,
              let step = controller.intervalEngine?.currentStep else { return nil }
        return stepColor(for: step.type)
    }

    /// Map a `ShuttlXShared.IntervalType` to the app's `IntervalType`, which is
    /// what `ShuttlXColor.forStepType(_:)` expects. Same raw values, so this is
    /// a guaranteed `?? .work` fallback.
    private func appType(for sharedType: ShuttlXShared.IntervalType) -> IntervalType {
        IntervalType(rawValue: sharedType.rawValue) ?? .work
    }

    private func stepColor(for sharedType: ShuttlXShared.IntervalType) -> Color {
        ShuttlXColor.forStepType(appType(for: sharedType))
    }

    private func displayName(for sharedType: ShuttlXShared.IntervalType) -> String {
        appType(for: sharedType).displayName
    }

    private func hrZoneLabel(_ bpm: Int) -> String {
        guard bpm > 0 else { return "" }
        let pct = Double(bpm) / 185.0
        switch pct {
        case ..<0.60: return "Z1"
        case 0.60..<0.70: return "Z2"
        case 0.70..<0.80: return "Z3"
        case 0.80..<0.90: return "Z4"
        default: return "Z5"
        }
    }

    private func isHRSafe(_ bpm: Int) -> Bool {
        guard bpm > 0 else { return false }
        return Double(bpm) / 185.0 < 0.70   // Z1/Z2
    }

    private func restColor(for restSecs: TimeInterval) -> Color {
        if restSecs >= 120 { return ShuttlXColor.ctaPrimary }
        if restSecs >= 60  { return ShuttlXColor.ctaWarning }
        return ShuttlXColor.textPrimary
    }

    private func milestoneBadge(label: String, reached: Bool, value: Int?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(ShuttlXFont.cardCaption.weight(.bold))
            if reached, let v = value {
                Text("-\(v)")
                    .font(ShuttlXFont.cardCaption.weight(.bold))
                    .foregroundStyle(ShuttlXColor.ctaPrimary)
            }
        }
        .foregroundStyle(reached ? ShuttlXColor.textPrimary : ShuttlXColor.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(reached ? ShuttlXColor.ctaPrimary.opacity(0.18) : ShuttlXColor.surface)
        )
        .overlay(
            Capsule()
                .stroke(reached ? ShuttlXColor.ctaPrimary.opacity(0.5) : ShuttlXColor.surfaceBorder, lineWidth: 1)
        )
        .accessibilityLabel(reached
                            ? (value != nil ? "\(label) mark: \(value!) BPM drop" : "\(label) reached")
                            : "\(label) mark not yet reached")
    }
}

#Preview {
    let controller = iPhoneWorkoutController()
    iPhoneWorkoutTimerView(controller: controller)
        .environment(ThemeManager.shared)
}
