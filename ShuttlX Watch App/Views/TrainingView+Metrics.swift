import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Always-On Display (Reduced Luminance)

    var aodMinimalView: some View {
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

    var fullWorkoutDisplayTab: some View {
        let h = screenHeight
        let heroSize = max(44, h * 0.26)              // countdown hero — only used in interval mode
        let valueSize = max(40, h * 0.19)             // HR (still large, second-tier)
        let tertiarySize = max(16, h * 0.10)          // DIST / PACE / TIME — interval compact two-up
        let secondarySize = max(24, h * 0.14)         // DIST / PACE — free-run full-width rows
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

            // Mixtape — full cassette-deck face (twin spinning reels flanking an
            // LCD tape-window hero). Replaces the standard stacked metrics for
            // this theme; gym-recovery still routes to RecoveryWorkoutView above.
            if themeManager.current.id == "mixtape" {
                MixtapeWatchDeck(workoutManager: workoutManager,
                                 isInterval: isInterval,
                                 screenH: h)
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
            }

            if themeManager.current.id != "mixtape" {
            VStack(spacing: rowSpacing) {
                // Workout name + step pill (interval only).
                // (Mixtape renders its own J-card label strip in MixtapeWatchDeck.)
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

                // Hero: interval countdown (interval) or elapsed time (free run).
                // (Mixtape renders its own cassette-deck hero in MixtapeWatchDeck.)
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
                        // Number big, "BPM" as a small trailing unit. Rendering the
                        // whole "132 BPM" string at valueSize (~42pt) overflowed the
                        // HR row once the Z2 zone badge claimed its slot and clipped
                        // to "132 B…"; splitting the unit off keeps the wide element
                        // to just the digits, which always fit.
                        Text(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "\u{2014}")
                            .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("BPM")
                            .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                            .foregroundColor(ShuttlXColor.textSecondary)
                        HRZoneArc(zone: heartRateZoneNumber)
                            .frame(width: 34, height: 17)
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

                if workoutManager.noHeartRateDetected {
                    noHeartRateBanner(labelSize: labelSize)
                }

                // Tertiary two-up rows. SPM (cadence) was removed from the live
                // timer — it carried little decision value mid-run and the
                // CMPedometer-derived value is warmup-laggy/unreliable (see
                // cadence-derivation notes); PACE is the metric runners actually
                // steer by, so the tertiary area is DIST / PACE (+ elapsed TIME
                // in interval mode, where the hero is the step countdown).
                if isInterval {
                    HStack(spacing: 8) {
                        compactMetric("DIST", distanceText, tertiarySize, labelSize)
                            .background(kmSplitHighlight)
                        compactMetric("PACE", paceText, tertiarySize, labelSize)
                    }
                    HStack(spacing: 8) {
                        compactMetric("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                                      tertiarySize, labelSize)
                        // CAL fills the slot freed by removing SPM
                        if workoutManager.calories > 0 {
                            compactMetric("CAL", "\(workoutManager.calories)", tertiarySize, labelSize)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // Free-run: collapse DIST / PACE / CAL to a single compact
                    // strip. The timer hero (now at heroSize) and HR row dominate;
                    // these three are context metrics, not command metrics.
                    HStack(spacing: 0) {
                        compactMetric("DIST", distanceText, secondarySize, labelSize)
                            .background(kmSplitHighlight)
                        compactMetric("PACE", paceText, secondarySize, labelSize)
                        if workoutManager.calories > 0 {
                            compactMetric("CAL", "\(workoutManager.calories)", secondarySize, labelSize)
                        }
                    }
                    .padding(.top, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Distance \(distanceText), pace \(paceText)\(workoutManager.calories > 0 ? ", calories \(workoutManager.calories)" : "")")
                    .accessibilityAddTraits(.updatesFrequently)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, ShuttlXSpacing.xs)
            .padding(.trailing, 0)
            .padding(.top, watchTimerTopPadding(themeManager.current.id))
            .padding(.bottom, watchTimerBottomPadding(themeManager.current.id))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }   // end: standard stacked-metrics layout (non-mixtape themes)

            // Mixtape chrome — the spinning reel now rides inline on the J-card
            // header line (MixtapeReelBadge in the header HStack above) so it no
            // longer needs a full-screen overlay or a leading inset. The shell
            // frame + corner screws come from mixtapeBackground(); the J-card
            // name strip carries the rest of the cassette identity.
        }
        .overlay(alignment: .top) {
            if isInterval, let engine = workoutManager.intervalEngine {
                OverallProgressStrip(engine: engine)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: workoutManager.lastCompletedKm) { _, _ in
            guard !reduceMotion else { return }
            kmSplitFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                kmSplitFlash = false
            }
        }
    }

    /// Yellow-green highlight capsule shown briefly when a km split fires.
    var kmSplitHighlight: some View {
        Capsule()
            .fill(ShuttlXColor.running.opacity(kmSplitFlash ? 0.25 : 0))
            .animation(
                kmSplitFlash
                    ? .easeIn(duration: 0.08)
                    : .easeOut(duration: 0.55),
                value: kmSplitFlash
            )
    }

    // Compact two-up metric (used in interval mode's tertiary rows).
    // MARK: - Theme Padding Helpers

    /// Top padding for the metrics VStack in `fullWorkoutDisplayTab`, keyed by theme id.
    func watchTimerTopPadding(_ themeID: String) -> CGFloat {
        return 0
    }

    /// Bottom padding for the metrics VStack in `fullWorkoutDisplayTab`, keyed by theme id.
    func watchTimerBottomPadding(_ themeID: String) -> CGFloat {
        return 0
    }

    func compactMetric(_ label: String, _ value: String,
                               _ valueSize: CGFloat, _ labelSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textPrimary)
                .lineLimit(1)
                // 0.4 floor: "2.15 km" needs ~0.48 to fit the half-width slot on
                // 46mm; at the old 0.5 floor it clipped the " km" unit to "2.15…".
                // (No layoutPriority — that starved the label to "‥".)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Metric Row (unified for all metrics including timer)

    func metricRow(_ label: String, _ value: String, _ color: Color,
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
    func timerRow(valueSize: CGFloat, labelSize: CGFloat, labelWidth: CGFloat, heroSize: CGFloat) -> some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            intervalCountdownHero(engine: engine, heroSize: heroSize, labelSize: labelSize)
        } else {
            // Free-run: timer is the sole hero — use heroSize so it dominates
            // over the HR row below (which uses valueSize).
            metricRow("TIME", FormattingUtils.formatTimer(workoutManager.elapsedTime),
                      ShuttlXColor.textPrimary, heroSize, labelSize, labelWidth,
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
    func intervalCountdownHero(engine: IntervalEngine, heroSize: CGFloat, labelSize: CGFloat) -> some View {
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
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .layoutPriority(1)   // the countdown is the hero — it claims its
                                         // width first so the phase column yields,
                                         // never the digits (was clipping to "01…").
                if let step = engine.currentStep {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.type.displayName.uppercased())
                            .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                            .foregroundColor(stepColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)")
                            .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                            .foregroundColor(ShuttlXColor.textSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
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

            // Next-step preview — only when there is a next step
            if let next = engine.nextStep {
                HStack(spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: labelSize * 0.85, weight: .bold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.6))
                    Image(systemName: "chevron.right")
                        .font(.system(size: labelSize * 0.7, weight: .semibold))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.5))
                    Text(next.type.displayName.uppercased())
                        .font(.system(size: labelSize * 0.85, weight: .semibold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.forStepType(next.type).opacity(0.75))
                    Text(formatStepDuration(next.duration))
                        .font(.system(size: labelSize * 0.85, weight: .regular, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.6))
                        .monospacedDigit()
                }
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: engine.currentStepIndex)
                .accessibilityLabel("Next: \(next.type.displayName), \(formatStepDuration(next.duration))")
            }
        }
        .frame(maxWidth: .infinity)
        .id(engine.currentStepIndex)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: engine.currentStepIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time remaining in \(engine.currentStep?.type.displayName ?? "step"), \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), step \(engine.currentStepIndex + 1) of \(engine.totalStepsCount)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Compact duration label for the next-step preview: "45s" under 60s, "1:30" otherwise.
    private func formatStepDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    // MARK: - Computed Properties

    var heartRateText: String {
        guard workoutManager.heartRate > 0 else { return "\u{2014} BPM" }
        return "\(workoutManager.heartRate) BPM"
    }

    var heartRateZoneName: String {
        let hr = workoutManager.heartRate
        guard hr > 0 else { return "" }
        return hrCalculator.zoneName(for: Double(hr))
    }

    var heartRateZoneNumber: Int {
        hrCalculator.zone(for: Double(workoutManager.heartRate))
    }

    var isHighIntensityWarning: Bool {
        hrCalculator.isHighIntensityWarning(heartRate: Double(workoutManager.heartRate))
    }

    @ViewBuilder
    func highIntensityWarningView(labelSize: CGFloat) -> some View {
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

    /// Non-blocking banner shown when no HR sample has arrived after the grace
    /// period. HealthKit never reports read-permission denial, so a missing HR
    /// reading is otherwise invisible to the user. We can't deep-link straight to
    /// the per-app Health permissions on watchOS, so the copy tells the user
    /// where to check (wrist fit + iPhone Health → ShuttlX).
    func noHeartRateBanner(labelSize: CGFloat) -> some View {
        HStack {
            Spacer()
            Text("No heart rate — check wrist & Health access")
                .font(.system(size: max(9, labelSize * 0.8), weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.ctaWarning)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ShuttlXColor.ctaWarning, lineWidth: 1)
                )
            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.4), value: workoutManager.noHeartRateDetected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No heart rate detected. Check that the watch is snug on your wrist and that ShuttlX has heart rate access in the Health app.")
    }

    var distanceText: String {
        FormattingUtils.formatDistance(workoutManager.totalDistance)
    }

    var accessibleDistance: String {
        let dist = workoutManager.totalDistance
        if dist < 1.0 {
            return "\(Int(dist * 1000)) meters"
        }
        return String(format: "%.2f kilometers", dist)
    }

    var paceText: String {
        // Compact tertiary metric — the "PACE" label + the accessibility string
        // ("…per kilometer") carry the unit, so we drop the "/KM" suffix here to
        // keep the value legible in the two-up row (it overflowed the half-width
        // slot on 41–46mm and clipped to "PACE --…").
        guard let pace = workoutManager.currentPace else { return "—" }
        return FormattingUtils.formatPace(pace)
    }

    var accessiblePace: String {
        guard let pace = workoutManager.currentPace else { return "Average pace no data" }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return "Average pace \(minutes) minutes \(seconds) seconds per kilometer"
    }
}

// MARK: - HR Zone Arc

/// Gauge-style arc showing the current HR zone (1–5).
/// Segments fill from left to right — segments at or below the current zone
/// are colored with the zone's palette color; segments above are dimmed.
///
/// Geometry: 5 segments of 24° each, 5° gap between them, totalling 140° sweep.
/// Arc center sits at the bottom edge of the view so it reads as an upward gauge.
struct HRZoneArc: View {
    let zone: Int   // 0 = no data, 1–5 = zone

    private static let zoneColors: [Color] = [
        ShuttlXColor.hrZone1,
        ShuttlXColor.hrZone2,
        ShuttlXColor.hrZone3,
        ShuttlXColor.hrZone4,
        ShuttlXColor.hrZone5,
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height + 1   // center just below the view bottom
            let radius = size.height - 1
            let lineWidth: CGFloat = 3.5

            // 5 segments: each 24°, with 5° gaps — total 5×24+4×5 = 140°
            // Centred symmetrically: startAngle = 180 + (360-140)/2 = 180+110 = 290 … wait
            // We want it centred at 270° (top of circle). So:
            //   midAngle = 270°, halfSweep = 70°
            //   start = 270 - 70 = 200°, end = 270 + 70 = 340°
            let startDeg = 200.0
            let segDeg = 24.0
            let gapDeg = 5.0

            for i in 0..<5 {
                let segStart = startDeg + Double(i) * (segDeg + gapDeg)
                let segEnd = segStart + segDeg
                let isFilled = zone > 0 && (i + 1) <= zone

                var path = Path()
                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: radius,
                    startAngle: .degrees(segStart),
                    endAngle: .degrees(segEnd),
                    clockwise: false
                )

                ctx.stroke(
                    path,
                    with: .color(isFilled
                        ? HRZoneArc.zoneColors[i]
                        : Color.white.opacity(0.12)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .accessibilityLabel(zone > 0 ? "Zone \(zone)" : "Heart rate zone unknown")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Overall Interval Progress Strip

/// Thin bar at the top of the watch timer showing overall workout progress.
/// Advances smoothly through all steps from 0% to 100%.
///
/// Isolated into its own @ObservedObject view so it only re-evaluates on
/// engine publishes — same decoupling approach as IntervalStepWash.
struct OverallProgressStrip: View {
    @ObservedObject var engine: IntervalEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard engine.totalStepsCount > 0 else { return 0 }
        let stepFraction: Double = {
            guard let step = engine.currentStep, step.duration > 0 else { return 0 }
            return 1.0 - (engine.currentStepTimeRemaining / step.duration)
        }()
        return min(1.0, (Double(engine.currentStepIndex) + stepFraction) / Double(engine.totalStepsCount))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(ShuttlXColor.ctaPrimary.opacity(0.75))
                    .frame(width: max(0, proxy.size.width * progress))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 1),
                        value: progress
                    )
            }
        }
        .frame(height: 3)
        .ignoresSafeArea()
        .accessibilityLabel("Workout progress \(Int(progress * 100)) percent")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
