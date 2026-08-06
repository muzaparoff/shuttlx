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
        let tertiarySize = max(16, h * 0.10)          // DIST / CAL / TIME — compact two-up
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

        // MARK: Free-run type scale (Apple Workout–style label-less metric column)
        //
        // The free-run screen no longer renders a `[LABEL][value]` two-column row.
        // The leading label ate ~labelWidth (0.20h ≈ 39pt on 40mm) of every row and
        // forced `fittedHRValueSize` down to ~29pt; the unit is now a small suffix
        // riding the number's baseline, exactly like Apple's Outdoor Run metrics
        // page, and every number is left-aligned on one column edge.
        //
        // Sizes are solved, not guessed. The measured vertical budget of the
        // free-run stack (screen height − top safe area − page-dot inset) is
        // ~164pt on 40mm and ~206pt on 46mm; a text line occupies ~1.2 × its point
        // size, so the sum of the four row point sizes must stay under
        // budget / 1.2 (minus ~21pt for the banner when it is showing). Exceeding
        // it does NOT overflow visibly — SwiftUI silently scale-to-fits every row,
        // which is what made the old layout render at 50–70% of its nominal sizes.
        let bannerShown = freeRunBannerShown
        // Bonus tier: the banner's ~21pt (25pt on 46mm) is real estate that is
        // otherwise wasted as slack, so every number steps up 13% while it is
        // hidden and steps back down when the safety banner claims the row.
        let tier: CGFloat = bannerShown ? 1.0 : 1.13
        let rowWidth = screenWidth - ShuttlXSpacing.xs * 2
        let unitSize = max(11, h * 0.062)             // "BPM" / "/KM" suffix
        let compactUnitSize = max(9, h * 0.052)       // "KM" / "CAL" suffix
        let zoneArcWidth = max(30, h * 0.145)
        let frHeroSize = h * 0.20 * tier
        let frHRSize = fittedMetricSize(glyphs: 3, unit: "BPM", unitSize: unitSize,
                                        accessoryWidth: zoneArcWidth,
                                        available: rowWidth, cap: h * 0.16 * tier)
        let frPaceSize = fittedMetricSize(glyphs: paceValueText.count, unit: "/KM",
                                          unitSize: unitSize, accessoryWidth: 0,
                                          available: rowWidth, cap: h * 0.15 * tier)
        // The two-up slot is solved for BOTH values and takes the smaller result so
        // DIST and CAL share one point size (mismatched sizes on a shared line read
        // as a bug). "12.84" is the wide case; it is why this row stays the small
        // tier even when the banner is hidden.
        let frSlotWidth = (rowWidth - 8) / 2
        let frCompactCap = h * 0.085 * tier
        let frCompactSize = min(
            fittedMetricSize(glyphs: compactDistanceValue.count, unit: compactDistanceUnit,
                             unitSize: compactUnitSize, accessoryWidth: 0,
                             available: frSlotWidth, cap: frCompactCap),
            workoutManager.calories > 0
                ? fittedMetricSize(glyphs: max(3, "\(workoutManager.calories)".count), unit: "CAL",
                                   unitSize: compactUnitSize, accessoryWidth: 0,
                                   available: frSlotWidth, cap: frCompactCap)
                : frCompactCap
        )

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
            // Free run runs at spacing 0 and lets `flexGap` do ALL the distribution.
            // A `Spacer(minLength: 0)` does not cost 0 inside a spaced VStack — the
            // stack still inserts its spacing on BOTH sides of it. With four
            // flexGaps that was 8 × rowSpacing ≈ 39pt of forced whitespace on a
            // 40mm screen (a quarter of the usable height), which is what pushed
            // the stack over budget and triggered the global scale-to-fit.
            // Interval mode keeps its fixed rhythm — it has no flexGaps.
            VStack(alignment: isInterval ? .center : .leading,
                   spacing: isInterval ? rowSpacing : 0) {
                // Workout-name header — INTERVAL ONLY.
                // (Mixtape renders its own J-card label strip in MixtapeWatchDeck.)
                //
                // In interval mode the name identifies the running program
                // ("5K INTERVAL") and is genuinely informative. In free run it is
                // the constant string "FREE RUN": it tells the user nothing they
                // did not already know when they started, yet it consumed a full
                // label row (~labelSize * 1.2 + rowSpacing ≈ 24pt on 40mm) at the
                // top of the tightest layout in the app. Removing it in free run
                // hands that height back to the flexGap distribution and lets the
                // hero clock grow (see freeRunHeroSize).
                //
                // Two things the header carried are preserved elsewhere in the
                // free-run branch: the paused pulse (now on the hero clock itself
                // in `timerRow`, at zero vertical cost) and the VoiceOver
                // announcement of the workout type (folded into the hero's
                // accessibility label).
                if isInterval {
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
                        // Step pill moved to the same line as the countdown hero
                        // below (intervalCountdownHero) — the workout name keeps
                        // the header to itself so the two decision-critical pieces
                        // (remaining time + phase) read together.
                    }
                }

                // Free run distributes leftover height evenly between the rows
                // instead of pooling it under the last row (the user-reported
                // dead zone). `minLength: 0` means the gaps collapse first when
                // the banner appears, so nothing is ever pushed off-screen.
                // Interval mode keeps its fixed rhythm — it has more rows and no
                // slack to distribute.
                flexGap(!isInterval)

                // Hero: interval countdown (interval) or elapsed time (free run).
                // (Mixtape renders its own cassette-deck hero in MixtapeWatchDeck.)
                timerRow(valueSize: valueSize, labelSize: labelSize, labelWidth: labelWidth,
                         heroSize: isInterval ? heroSize : frHeroSize)

                flexGap(!isInterval)

                // HR row — second tier.
                if isInterval {
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
                } else {
                    // Free run: label-less Apple-style line — big zone-tinted digits,
                    // small "BPM" on the same baseline, zone arc parked after the
                    // unit. The arc stays on BOTH sizes: solved against the row it
                    // costs `zoneArcWidth` (30pt on 40mm), which still leaves the
                    // digits ~91pt — more than the 0.16h cap needs — so it is free.
                    unitNumber(workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "\u{2014}",
                               "BPM",
                               ShuttlXColor.forHRZone(workoutManager.heartRate),
                               frHRSize, unitSize) {
                        HRZoneArc(zone: heartRateZoneNumber)
                            .frame(width: zoneArcWidth, height: zoneArcWidth / 2)
                            .padding(.leading, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(workoutManager.heartRate > 0 ? "Heart rate \(workoutManager.heartRate) beats per minute, Zone \(heartRateZoneNumber)" : "Heart rate no data")
                    .accessibilityAddTraits(.updatesFrequently)
                }

                if isHighIntensityWarning {
                    highIntensityWarningView(labelSize: labelSize)
                        // Free run runs at VStack spacing 0, so the banner supplies
                        // its own separation from the HR digits above it.
                        .padding(.vertical, isInterval ? 0 : 2)
                }

                if workoutManager.noHeartRateDetected {
                    noHeartRateBanner(labelSize: labelSize)
                        .padding(.vertical, isInterval ? 0 : 2)
                }

                flexGap(!isInterval)

                // Tertiary two-up rows. SPM (cadence) was removed from the live
                // timer — it carried little decision value mid-run and the
                // CMPedometer-derived value is warmup-laggy/unreliable (see
                // cadence-derivation notes).
                // Interval: DIST / PACE + elapsed TIME / CAL (the hero is the step
                // countdown, so elapsed time is demoted here).
                // Free run: DIST / CAL only — PACE was promoted to a full-width row
                // above and the elapsed clock is the hero.
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
                    // Free run: PACE owns a full-width row. It is the metric a
                    // runner actually steers by, and it now carries its unit as a
                    // "/KM" suffix instead of a "PACE" label column — the row width
                    // that column used to hold is what lets the digits reach
                    // 0.15h–0.17h instead of the old 0.155h-nominal that was then
                    // scale-to-fit down to ~21pt on 40mm.
                    //
                    // Width is solved from the ACTUAL glyph count of the value:
                    // "6'47\"" is 5 glyphs, a walking "12'34\"" is 6, and the
                    // no-data case is the single "—". Sizing per-value means the
                    // common case is never penalised by the widest one.
                    unitNumber(paceValueText, "/KM", ShuttlXColor.running,
                               frPaceSize, unitSize) { EmptyView() }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessiblePace)
                        .accessibilityAddTraits(.updatesFrequently)

                    flexGap(true)

                    HStack(spacing: 8) {
                        // Unit-less km VALUE + a small "KM"/"M" suffix — the
                        // half-width slot cannot hold "12.84 km" as one string on
                        // 40mm, but as value + suffix the suffix is small enough to
                        // pay for itself. VoiceOver keeps the full units.
                        unitNumber(compactDistanceValue, compactDistanceUnit,
                                   ShuttlXColor.textPrimary, frCompactSize, compactUnitSize) { EmptyView() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(kmSplitHighlight)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Distance \(accessibleDistance)")
                        if workoutManager.calories > 0 {
                            unitNumber("\(workoutManager.calories)", "CAL",
                                       ShuttlXColor.textPrimary, frCompactSize, compactUnitSize) { EmptyView() }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(workoutManager.calories) calories")
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            // HR haptic lives on the stack, not on the HR row: the row is now
            // branch-specific (label column in interval, label-less in free run)
            // and both branches need the high-intensity notification.
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
            // The banner inserting/removing a row reflows the stack anyway; the
            // size tier rides along with that same reflow.
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: bannerShown)
            // Pause-pulse driver lives on the stack, not on the header row: the
            // header is interval-only now, and free run needs the same pulse for
            // its hero clock.
            .onAppear { if workoutManager.isPaused && !reduceMotion { pausePulse = true } }
            .padding(.horizontal, ShuttlXSpacing.xs)
            .padding(.trailing, 0)
            .padding(.top, watchTimerTopPadding(themeManager.current.id))
            .padding(.bottom, watchTimerBottomPadding(themeManager.current.id))
            // Free run only: reserve the strip the TabView page dots live in.
            // Without it the flexible gaps push the DIST/CAL row down until it
            // sits under the dots. Measured dot band: y193–195.5 of 197 on 40mm,
            // y240–245.5 of 248 on 46mm, so the content must stop by ~190 / ~237.
            // 0.085h (16.7 / 21.1) was more clearance than that needs; 0.055h
            // (10.8 / 13.6) still clears both — plus the last line box carries
            // ~0.25em of descender space no digit uses — and hands the ~6pt it
            // frees to the type scale.
            .padding(.bottom, isInterval ? 0 : max(10, h * 0.055))
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

    // MARK: - Apple-style Metric Line (free run)

    /// One free-run metric line: a big monospaced number with a SMALL unit suffix
    /// riding the same baseline, plus an optional trailing accessory.
    ///
    /// This replaces the `[LABEL][spacer][value]` two-column `metricRow` on the
    /// free-run screen. The label column was pure overhead — it consumed
    /// `labelWidth` (0.20h ≈ 39pt on 40mm, 50pt on 46mm) of every row and forced
    /// the numbers down to fit what was left. Attaching the unit to the number
    /// instead (Apple Workout's Outdoor Run pattern) says the same thing in ~24pt
    /// and lets the digits claim the rest.
    ///
    /// `firstTextBaseline` alignment is what makes the suffix read as part of the
    /// number rather than as a second, smaller metric; it also means the suffix
    /// contributes no line height of its own.
    @ViewBuilder
    func unitNumber<Accessory: View>(_ value: String, _ unit: String, _ color: Color,
                                     _ valueSize: CGFloat, _ unitSize: CGFloat,
                                     @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: max(1, unitSize * 0.18)) {
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                // NO `minimumScaleFactor`, and `fixedSize` on BOTH axes. Measured
                // 2026-08-06: with `vertical: false` and a 0.6 floor, HR and PACE
                // rendered at exactly 0.67 × their solved size on both watches even
                // though the row had horizontal room to spare — the VStack proposes
                // each child a share of the height, and an unfixed-vertical Text
                // answers a tight proposal by scaling itself (and its width) down.
                // That is the same silent shrink that made the old layout render a
                // 49.7pt hero at 25pt. Sizes are solved by `fittedMetricSize`, so
                // the row must render them as asked or the solve is meaningless.
                .fixedSize()
                .layoutPriority(1)
            Text(unit)
                .font(.system(size: unitSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
            accessory()
        }
    }

    /// Largest point size at which `glyphs` monospaced characters, a fixed-size unit
    /// suffix and an optional accessory all fit `available` points of row width.
    ///
    /// Solving the size up front is the whole trick: SwiftUI does NOT report an
    /// overflowing metrics stack — it quietly scale-to-fits every row, which is how
    /// the previous layout ended up rendering its 49.7pt hero at 25pt and its 30.5pt
    /// PACE at 21pt on a 40mm screen while the source still said "0.26h" and
    /// "0.155h". Every free-run number is now sized, not scaled.
    ///
    /// `advance` is SF's monospaced per-glyph advance (0.6em) with ~3% safety margin.
    func fittedMetricSize(glyphs: Int, unit: String, unitSize: CGFloat,
                          accessoryWidth: CGFloat, available: CGFloat,
                          cap: CGFloat) -> CGFloat {
        guard glyphs > 0 else { return cap }
        let advance: CGFloat = 0.62
        let unitWidth = CGFloat(unit.count) * advance * unitSize
        let gaps = max(1, unitSize * 0.18) + (accessoryWidth > 0 ? 4 : 0) + 2
        let budget = available - unitWidth - accessoryWidth - gaps
        return max(10, min(cap, budget / (CGFloat(glyphs) * advance)))
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

    // MARK: - Metric Row
    //
    // The `[LABEL][spacer][value]` two-column row is GONE. Its only remaining
    // caller was the free-run PACE line, which now uses `unitNumber` — the label
    // column cost `labelWidth` (0.20h) of row width for a word the unit suffix says
    // in a third of the space. Interval mode never used it (it composes its rows
    // inline and via `compactMetric`). Do not reintroduce it on the free-run stack.

    // MARK: - Timer Line

    @ViewBuilder
    func timerRow(valueSize: CGFloat, labelSize: CGFloat, labelWidth: CGFloat, heroSize: CGFloat) -> some View {
        if workoutManager.workoutMode == .interval, let engine = workoutManager.intervalEngine {
            intervalCountdownHero(engine: engine, heroSize: heroSize, labelSize: labelSize)
        } else {
            // Free-run: the elapsed clock is the sole hero and gets the ENTIRE row
            // width — no "TIME" label column.
            //
            // The label was the binding constraint on digit size, not the vertical
            // budget: `ElapsedTimerText` solves its point size from the width it is
            // given, and the ~40pt label column pushed the 1h+ form (7 glyphs) down
            // to ~25pt on 40mm — smaller than the HR digits sitting right below it.
            // Reclaiming that column buys ~35% more digit height at every duration.
            // Nothing is lost: this is the only clock on screen, and VoiceOver
            // announces the workout type + elapsed time from the label below.
            //
            // The clock also carries the PAUSED signal now that the free-run header
            // (which used to blink amber) is gone: amber tint + the same 0.8s
            // pulse, at zero vertical cost. A frozen clock alone is too slow to
            // read — a runner glancing down needs the state in one look.
            ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                             elapsed: workoutManager.elapsedTime,
                             baseSize: heroSize,
                             availableWidth: screenWidth - (ShuttlXSpacing.xs * 2),
                             color: workoutManager.isPaused
                                 ? ShuttlXColor.ctaWarning
                                 : ShuttlXColor.textPrimary)
                // Left-aligned, like every number below it: Apple's metrics page
                // shares one column edge so the eye drops straight down the stack
                // instead of re-acquiring a new centre for each row.
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity((!reduceMotion && workoutManager.isPaused && pausePulse) ? 0.35 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: pausePulse
                )
                .accessibilityElement(children: .combine)
                // Replaces the VoiceOver announcement the removed "FREE RUN"
                // header used to provide — the workout type is spoken with the
                // clock instead of as a separate, silent-to-sighted-users row.
                .accessibilityLabel("\(workoutManager.workoutName)\(workoutManager.isPaused ? ", paused" : ""), elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// Flexible, fully collapsible gap used to spread the free-run stack over the
    /// whole screen height. Emitted only for the modes that have slack to give.
    @ViewBuilder
    func flexGap(_ active: Bool) -> some View {
        if active { Spacer(minLength: 0) }
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

    /// True when a safety banner is claiming a row in the free-run stack.
    ///
    /// Drives the two-tier type scale: with no banner the ~21pt (25pt on 46mm) it
    /// would occupy is spare height that used to drain into the `flexGap` spacers,
    /// so every number steps up 13% instead. The banner always wins when it
    /// appears — it is cardiac-safety UI and must be fully visible.
    var freeRunBannerShown: Bool {
        isHighIntensityWarning || workoutManager.noHeartRateDetected
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

    /// Full "12.84 km" form. No longer used by the live timer (both modes now show
    /// distance in the compact slot, see `compactDistanceText`) — kept as the
    /// unit-bearing formatting entry point for any full-width distance surface.
    var distanceText: String {
        FormattingUtils.formatDistance(workoutManager.totalDistance)
    }

    /// Distance for the compact two-up slot, which is roughly half the width of a
    /// full-width row. "12.84 km" cannot fit there on 40mm — even at
    /// the 0.4 scale floor it elided to "3.42…". The unit is dropped in the km form
    /// exactly as `paceText` drops "/KM" for the same reason; the "DIST" label and
    /// the VoiceOver string (which keeps full units) carry the meaning. The sub-km
    /// form keeps its "m" because "450" alone would be ambiguous.
    var compactDistanceText: String {
        let km = workoutManager.totalDistance
        if km < 1.0 { return "\(Int(km * 1000))m" }
        return String(format: "%.2f", km)
    }

    /// Free-run distance split into number and unit so the unit can be rendered as a
    /// small baseline suffix (see `unitNumber`). Sub-km keeps metres because "0.45"
    /// reads worse than "450 M" at a glance.
    var compactDistanceValue: String {
        let km = workoutManager.totalDistance
        if km < 1.0 { return "\(Int(km * 1000))" }
        return String(format: "%.2f", km)
    }

    var compactDistanceUnit: String {
        workoutManager.totalDistance < 1.0 ? "M" : "KM"
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

    /// Free-run PACE value without its unit — "/KM" is rendered as a small baseline
    /// suffix by `unitNumber`. Identical to `paceText`; named separately because the
    /// free-run row sizes itself from `.count` and the intent (a bare value) matters.
    var paceValueText: String { paceText }

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
        // MEASURED 2026-08-06 (SE 3 40mm + Series 11 46mm, watchOS 26.5): a
        // `minimumScaleFactor` on the RUNNING branch does not act as a safety net
        // here — it fires unconditionally and pins the clock to the floor. Snapshot
        // measurements of the digits: 25.7pt rendered against a 49.7pt `fittedSize`
        // on 40mm, 33.0pt against 64.5pt on 46mm, and 17.7pt against 35.5pt at
        // 1h27m — 0.49–0.51× in every single case, i.e. exactly the old 0.5 floor.
        // `Text(timerInterval:)` is advanced by the render server, so SwiftUI sizes
        // it from an internal worst-case template rather than the string on screen,
        // decides that template overflows, and scales all the way down. The result
        // was a hero clock rendering at HALF the size the code asked for.
        //
        // `fittedSize` already solves the point size against `availableWidth`, so
        // no scale-to-fit is wanted on EITHER branch. The paused/static branch has
        // the same failure in a different guise: `fixedSize(vertical: false)` let
        // the VStack's height proposal shrink it, and the paused clock rendered at
        // ~22pt next to a 35.6pt BPM row. `fixedSize()` on both axes is what makes
        // the solved size the rendered size. Both `Text(timerInterval:)` and
        // `FormattingUtils.formatTimer` produce the same glyph counts `glyphCount`
        // solves for (5 for mm:ss, 7 for h:mm:ss), so the two branches stay in sync.
        .fixedSize()
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
