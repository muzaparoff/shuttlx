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

    /// Gym-recovery hero — branches on the segmenter state. Mirrors the watch's
    /// `RecoveryWorkoutView` design with three sub-states.
    @ViewBuilder
    private var recoveryHero: some View {
        switch controller.recoveryState {
        case .idle:
            recoveryIdleHero
        case .work:
            recoveryWorkHero
        case .rest:
            recoveryRestHero
        }
    }

    private var recoveryIdleHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(ShuttlXColor.surfaceBorder, lineWidth: 4)
                    .frame(width: 200, height: 200)
                VStack(spacing: 4) {
                    Text(controller.heartRateMonitor.current > 0 ? "\(controller.heartRateMonitor.current)" : "—")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(
                            controller.heartRateMonitor.current > 0
                                ? ShuttlXColor.forHRZone(controller.heartRateMonitor.current)
                                : ShuttlXColor.textSecondary
                        )
                    Text("BPM")
                        .font(ShuttlXFont.cardCaption.weight(.bold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
            }
            Text("Sit on machine to begin")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recoveryWorkHero: some View {
        VStack(spacing: 6) {
            Text("Station \(controller.recoverySetNumber)")
                .font(ShuttlXFont.cardTitle)
                .foregroundStyle(ShuttlXColor.ctaPrimary)
            Text(controller.heartRateMonitor.current > 0 ? "\(controller.heartRateMonitor.current)" : "—")
                .font(.system(size: 104, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.forHRZone(controller.heartRateMonitor.current))
                .contentTransition(.numericText())
            Text("BPM")
                .font(ShuttlXFont.cardCaption.weight(.bold))
                .foregroundStyle(ShuttlXColor.textSecondary)
            Text("STATION  \(FormattingUtils.formatTimer(controller.stationElapsedTime))")
                .font(ShuttlXFont.cardCaption.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var recoveryRestHero: some View {
        let restSecs = controller.restElapsedTime
        let passed1min = restSecs >= 60
        let passed2min = restSecs >= 120
        return VStack(spacing: 10) {
            Text("REST")
                .font(ShuttlXFont.cardTitle)
                .foregroundStyle(ShuttlXColor.ctaWarning)
            Text(FormattingUtils.formatTimer(restSecs))
                .font(.system(size: 88, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(restColor(for: restSecs))
                .contentTransition(.numericText())
            HStack(spacing: 12) {
                milestoneBadge(label: "1:00", reached: passed1min, value: controller.latestHRR1)
                milestoneBadge(label: "2:00", reached: passed2min, value: controller.latestHRR2)
            }
            HStack(spacing: 6) {
                Text(controller.heartRateMonitor.current > 0 ? "\(controller.heartRateMonitor.current)" : "—")
                    .font(ShuttlXFont.metricMedium)
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.heartRate)
                Image(systemName: "arrow.down")
                    .foregroundStyle(
                        isHRSafe(controller.heartRateMonitor.current)
                            ? ShuttlXColor.ctaPrimary.opacity(0.7)
                            : ShuttlXColor.heartRate.opacity(0.7)
                    )
            }
        }
        .frame(maxWidth: .infinity)
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
            if controller.currentCadence > 0 {
                metricCard(label: "CAD",
                           value: "\(controller.currentCadence)",
                           color: ShuttlXColor.steps)
            }
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
                if controller.currentCadence > 0 {
                    metricCard(label: "CAD",
                               value: "\(controller.currentCadence)",
                               color: ShuttlXColor.steps,
                               compact: true)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
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
