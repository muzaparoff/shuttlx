import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Always-On Display (Reduced Luminance)

    var aodMinimalView: some View {
        VStack(spacing: 12) {
            Spacer()
            // AOD: full screen width minus a small margin. At 1h+ the h:mm:ss form
            // is 7 glyphs — on a 40mm screen that overflows 36pt, so the component
            // shrinks it to fit rather than truncating.
            ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                             elapsed: workoutManager.elapsedTime,
                             baseSize: 36,
                             availableWidth: screenWidth - 16,
                             color: ShuttlXColor.textPrimary.opacity(0.7))
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
        // HR digits are the only element in their row that yields. The unit and the
        // 34pt zone arc keep their size; the number is solved against whatever
        // horizontal space is left. Without this the 40pt floor on `valueSize`
        // overflowed a 40mm row and SwiftUI truncated the BPM value to "1…".
        let hrValueSize = fittedHRValueSize(valueSize: valueSize,
                                            labelSize: labelSize,
                                            labelWidth: labelWidth)

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
                            .font(.system(size: hrValueSize, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(ShuttlXColor.forHRZone(workoutManager.heartRate))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .layoutPriority(1)   // digits claim their (already fitted) width first
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
                        compactMetric("DIST", compactDistanceText, tertiarySize, labelSize,
                                      a11y: "Distance \(accessibleDistance)")
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
                    // Free-run: DIST on its own full-width row so "10.00 km"
                    // never overflows; PACE + CAL share the compact row below.
                    metricRow("DIST", distanceText, ShuttlXColor.running,
                              secondarySize, labelSize, labelWidth,
                              accessibilityText: accessibleDistance)
                        .background(kmSplitHighlight)

                    HStack(spacing: 8) {
                        compactMetric("PACE", paceText, tertiarySize, labelSize)
                        if workoutManager.calories > 0 {
                            compactMetric("CAL", "\(workoutManager.calories)", tertiarySize, labelSize)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Pace \(accessiblePace)\(workoutManager.calories > 0 ? ", calories \(workoutManager.calories)" : "")")
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
    // MARK: - HR Value Sizing

    /// Point size for the BPM number, solved so three digits always render in full.
    ///
    /// The HR row is `[HR label][spacer][digits][BPM unit][zone arc]`. Everything
    /// except the digits is fixed, so the digits get whatever is left. On a 40mm
    /// screen the previous fixed `valueSize` (floor 40pt) needed ~72pt for "138"
    /// while the row could only offer ~36pt; `minimumScaleFactor(0.6)` bottomed out
    /// above that and SwiftUI truncated to "1…". Sizing up front removes the
    /// dependency on scale-to-fit entirely.
    ///
    /// `glyphAdvanceRatio` was measured from a rendered 46mm frame ("138" at 47pt
    /// spans ~66pt ⇒ 0.47em) and rounded up for margin.
    func fittedHRValueSize(valueSize: CGFloat, labelSize: CGFloat, labelWidth: CGFloat) -> CGFloat {
        let glyphAdvanceRatio: CGFloat = 0.52
        let unitWidth = 3 * glyphAdvanceRatio * labelSize      // "BPM"
        let arcWidth: CGFloat = 34                             // HRZoneArc, fixed
        let gaps: CGFloat = 4 * 2 + 2                          // inner HStack spacing + slack
        let available = screenWidth
            - (ShuttlXSpacing.xs * 2)
            - labelWidth
            - unitWidth
            - arcWidth
            - gaps
        let cap = available / (3 * glyphAdvanceRatio)          // always size for 3 digits
        return max(16, min(valueSize, cap))
    }

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
                               _ valueSize: CGFloat, _ labelSize: CGFloat,
                               a11y: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // fixedSize + layoutPriority(0): the label is granted exactly its
                // ideal width and never compressed. This is what makes the value's
                // layoutPriority(1) safe — an earlier attempt at priority alone
                // starved the label to "‥" because the label was still compressible.
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(0)
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textPrimary)
                .lineLimit(1)
                // 0.4 floor: "2.15 km" needs ~0.48 to fit the half-width slot on
                // 46mm; at the old 0.5 floor it clipped the " km" unit to "2.15…".
                // On 40mm interval mode the slot is narrower still and the value was
                // clipping to "3.42…" — the priority below lets it claim the space
                // left by the (now incompressible) label and scale into it instead.
                .minimumScaleFactor(0.4)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11y ?? "\(label) \(value)")
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
            // Inlined rather than routed through metricRow() because the value is a
            // system-rendered ticking Text, not a String. Same layout/modifiers.
            HStack(spacing: 4) {
                Text("TIME")
                    .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                    .foregroundColor(ShuttlXColor.textSecondary)
                    .frame(width: labelWidth, alignment: .leading)
                    .layoutPriority(0)   // the label yields; the digits never do
                Spacer(minLength: 0)
                // Width budget: screen minus the label column, the row's own
                // horizontal padding (ShuttlXSpacing.xs on each side) and the 4pt
                // gap. Feeding this to the component is what stops the 1h+ form
                // ("1:27:23", 7 glyphs) from truncating to "1:27…".
                ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                                 elapsed: workoutManager.elapsedTime,
                                 baseSize: heroSize,
                                 availableWidth: screenWidth - labelWidth - (ShuttlXSpacing.xs * 2) - 4)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
            .accessibilityAddTraits(.updatesFrequently)
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

    /// Safety-relevant warning — it must be fully readable, never elided.
    ///
    /// It used to sit in `HStack { Spacer(); Text }`, which handed the text only the
    /// leftover width, and the tight vertical budget of the metrics stack meant
    /// SwiftUI proposed a single line's height and truncated to "Heart rate high…"
    /// on BOTH 40mm and 46mm. Now the banner spans the full row width, is allowed
    /// two lines, and `fixedSize(vertical:)` guarantees it is granted the height
    /// those lines need instead of being compressed into an ellipsis.
    @ViewBuilder
    func highIntensityWarningView(labelSize: CGFloat) -> some View {
        HStack {
            // Copy is deliberately tight, and the banner is pinned to ONE line.
            //
            // Two measured constraints drove this. (1) The original sentence
            // ("Heart rate high — ease off") truncated to "Heart rate high…" on both
            // 40mm and 46mm because the row's vertical budget only ever offered a
            // single line's height. (2) Letting it wrap to two lines fixed the
            // banner but pushed the bottom metric row off-screen in interval mode on
            // 40mm — one truncation traded for another. So: shorter copy, one line,
            // and scale-to-fit (which DOES work here — unlike Text(timerInterval:),
            // this is ordinary static text) as the fallback instead of wrapping.
            // At the 0.6 floor this fits with ~50% headroom on the narrowest screen,
            // so it cannot elide. Action first, since that is what matters
            // mid-effort; the full sentence lives in the accessibility label below.
            Text("Ease off — HR high")
                .font(.system(size: max(9, labelSize * 0.85), weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.ctaDestructive)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
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

    /// Distance for the compact two-up slot in interval mode, which is roughly half
    /// the width of the free-run row. "12.84 km" cannot fit there on 40mm — even at
    /// the 0.4 scale floor it elided to "3.42…". The unit is dropped in the km form
    /// exactly as `paceText` drops "/KM" for the same reason; the "DIST" label and
    /// the VoiceOver string (which keeps full units) carry the meaning. The sub-km
    /// form keeps its "m" because "450" alone would be ambiguous.
    var compactDistanceText: String {
        let km = workoutManager.totalDistance
        if km < 1.0 { return "\(Int(km * 1000))m" }
        return String(format: "%.2f", km)
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

// MARK: - Elapsed Timer Text

/// Elapsed-workout clock that ticks WITHOUT a SwiftUI invalidation.
///
/// While the workout is running we hand SwiftUI a wall-clock anchor and let the
/// render server advance the digits (`Text(timerInterval:)`). That decouples the
/// on-screen seconds from `WatchWorkoutManager.elapsedTime`, which is published
/// from the 1 Hz main-actor tick and therefore stalls whenever the main actor is
/// backlogged (cold-launch WatchConnectivity storm). It is also the Always-On-safe
/// form: the system keeps a timerInterval text updating in reduced-luminance state.
///
/// When `referenceDate` is nil (paused / stopped) it falls back to static text so a
/// paused clock does not keep counting.
///
/// Format note: `Text(timerInterval:)` renders `m:ss` / `h:mm:ss` — no leading zero
/// on the minutes field, unlike `FormattingUtils.formatTimer`'s `mm:ss`.
///
/// SIZING — verified on Apple Watch Series 11 46mm, watchOS 26.5:
/// `Text(timerInterval:)` does **not** honour `minimumScaleFactor`. Its content is
/// advanced by the render server, so SwiftUI never measures a candidate string to
/// scale against; at 1h27m the row rendered "1:27…" at full point size instead of
/// shrinking. The view therefore picks its own point size from the glyph count the
/// current elapsed magnitude implies (5 for `mm:ss`, 7 for `h:mm:ss`, 8 past 10h)
/// and the horizontal budget the call site passes in. `minimumScaleFactor` is still
/// applied for the static (paused) branch, where it does work.
struct ElapsedTimerText: View {
    let referenceDate: Date?
    let elapsed: TimeInterval
    /// Point size used when the value fits `mm:ss`. Never exceeded.
    let baseSize: CGFloat
    /// Horizontal space the digits may occupy, in points.
    let availableWidth: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = ShuttlXColor.textPrimary

    /// Per-glyph advance of SF's monospaced design as a fraction of point size
    /// (~0.6em) plus a small safety margin.
    private static let advanceRatio: CGFloat = 0.62

    /// Prefer the wall clock over the published `elapsed`: the whole point of this
    /// view is to keep rendering when `elapsed` publishes late, so the size decision
    /// must not lag either. Switches a hair BEFORE the hour boundary (3590s) so the
    /// wider form is already sized for when the render server rolls over to it.
    private var effectiveElapsed: TimeInterval {
        guard let referenceDate else { return max(0, elapsed) }
        return max(max(0, elapsed), Date().timeIntervalSince(referenceDate))
    }

    private var glyphCount: Int {
        let s = effectiveElapsed
        if s >= 35_990 { return 8 }   // 10:00:00
        if s >= 3_590 { return 7 }    // 1:00:00
        return 5                      // 59:59
    }

    private var fittedSize: CGFloat {
        let widthCap = availableWidth / (CGFloat(glyphCount) * Self.advanceRatio)
        return max(12, min(baseSize, widthCap))
    }

    var body: some View {
        Group {
            if let referenceDate {
                Text(timerInterval: referenceDate...Date.distantFuture, countsDown: false)
            } else {
                Text(FormattingUtils.formatTimer(elapsed))
            }
        }
        .font(.system(size: fittedSize, weight: weight, design: .monospaced))
        .monospacedDigit()
        .foregroundColor(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: true, vertical: false)
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
