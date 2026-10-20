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

    // MARK: - Interval Workout Display
    //
    // Interval mode only. Free run renders `runningPage` + `freeRunMetricsPage`
    // (TrainingView+Running.swift) — the one-word layout from the timeline mockup.

    var fullWorkoutDisplayTab: some View {
        // Every size is mockup px via `WatchScale.pt`, then SOLVED against the row
        // width — never scale-to-fit (see .claude/rules/watchos.md). Measured
        // 2026-10-20 on 40mm: the old 0.08h header ran into the system clock and the
        // TIME row sat on the page dots.
        let rowWidth = screenWidth - 16                 // .padding(.horizontal, 8)
        let labelSize = WatchScale.pt(11)
        let bannerShown = isHighIntensityWarning || workoutManager.noHeartRateDetected

        return ZStack {
            // Step-type wash, hosted in its own view that observes the engine
            // so it does not re-evaluate on every manager publish.
            if let engine = workoutManager.intervalEngine {
                IntervalStepWash(engine: engine)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Program name ("5K INTERVAL") shares its line with the system clock
                // (top right, ~0.31w on 40mm), so it is capped to the left 60%.
                Text(workoutManager.workoutName.uppercased())
                    .font(.system(size: labelSize, weight: .bold))
                    .tracking(labelSize * 0.08)
                    .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.ctaPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: screenWidth * 0.6, alignment: .leading)
                    .opacity((!reduceMotion && workoutManager.isPaused && pausePulse) ? 0.3 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pausePulse
                    )

                if let engine = workoutManager.intervalEngine {
                    intervalCountdownHero(engine: engine, rowWidth: rowWidth, labelSize: labelSize,
                                          showNext: !bannerShown)
                        .padding(.top, WatchScale.pt(4))
                } else {
                    ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                                     elapsed: workoutManager.elapsedTime,
                                     baseSize: WatchScale.pt(44),
                                     availableWidth: rowWidth)
                        .padding(.top, WatchScale.pt(4))
                }

                intervalHeartRateRow(labelSize: labelSize)
                    .padding(.top, WatchScale.pt(5))

                if isHighIntensityWarning {
                    highIntensityWarningView(labelSize: labelSize).padding(.top, 3)
                }
                if workoutManager.noHeartRateDetected {
                    noHeartRateBanner(labelSize: labelSize).padding(.top, 3)
                }

                Spacer(minLength: 0)

                // DIST / PACE + elapsed TIME / CAL (the hero is the step countdown,
                // so elapsed time is demoted here). One solved size per row.
                let dist = compactDistanceText, pace = paceText
                let time = FormattingUtils.formatTimer(workoutManager.elapsedTime)
                let cal = workoutManager.calories > 0 ? "\(workoutManager.calories)" : "\u{2014}"
                let topSize = twoUpValueSize(dist, pace, rowWidth: rowWidth, labelSize: labelSize)
                let bottomSize = twoUpValueSize(time, cal, rowWidth: rowWidth, labelSize: labelSize)
                HStack(spacing: 8) {
                    compactMetric("DIST", dist, topSize, labelSize, a11y: "Distance \(accessibleDistance)")
                        .background(kmSplitHighlight)
                    compactMetric("PACE", pace, topSize, labelSize, a11y: accessiblePace)
                }
                HStack(spacing: 8) {
                    compactMetric("TIME", time, bottomSize, labelSize,
                                  a11y: "Elapsed \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))")
                    compactMetric("CAL", cal, bottomSize, labelSize,
                                  a11y: workoutManager.calories > 0 ? "\(workoutManager.calories) calories" : "Calories no data")
                }
                .padding(.top, WatchScale.pt(3))
            }
            .onAppear { if workoutManager.isPaused && !reduceMotion { pausePulse = true } }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 8)
            // Keep the last line clear of the TabView page dots.
            .padding(.bottom, max(10, screenHeight * 0.055))
        }
        .overlay(alignment: .top) {
            if let engine = workoutManager.intervalEngine {
                OverallProgressStrip(engine: engine)
                    .allowsHitTesting(false)
            }
        }
    }

    /// `[digits][BPM] ... [zone arc]` — digits solved for 3 glyphs, never scaled.
    private func intervalHeartRateRow(labelSize: CGFloat) -> some View {
        let hr = workoutManager.heartRate
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(hr > 0 ? "\(hr)" : "\u{2014}")
                .font(.system(size: WatchScale.pt(26), weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.forHRZone(hr))
                .fixedSize()
            Text("BPM")
                .font(.system(size: labelSize, weight: .bold))
                .foregroundColor(ShuttlXColor.textSecondary)
                .fixedSize()
            Spacer(minLength: 4)
            HRZoneArc(zone: heartRateZoneNumber)
                .frame(width: 34, height: 17)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hr > 0 ? "\(hr) beats per minute, Zone \(heartRateZoneNumber)" : "Heart rate no data")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Shared value size for one two-up row: both `[LABEL value]` halves fit at
    /// the size of the longer value (min 4 glyphs so a row doesn't jump while
    /// values grow). Cap pt(20).
    private func twoUpValueSize(_ a: String, _ b: String, rowWidth: CGFloat, labelSize: CGFloat) -> CGFloat {
        let advance: CGFloat = 0.62
        let half = (rowWidth - 8) / 2
        let labelWidth = 4 * advance * labelSize + 4
        let glyphs = CGFloat(max(4, a.count, b.count))
        return max(8, min(WatchScale.pt(20), (half - labelWidth - 2) / (glyphs * advance)))
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

    /// `[LABEL value]` half of an interval two-up row. `valueSize` comes from
    /// `twoUpValueSize`, so both Texts render as asked (`fixedSize`, no scale factor).
    func compactMetric(_ label: String, _ value: String,
                       _ valueSize: CGFloat, _ labelSize: CGFloat,
                       a11y: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundColor(ShuttlXColor.textSecondary)
                .fixedSize()
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(ShuttlXColor.textPrimary)
                .fixedSize()
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

    // MARK: - Interval Countdown Hero (replaces the old 56pt progress ring)
    //
    // The countdown to the next interval transition is the most decision-critical
    // number on the screen during interval work. It must be the largest element so
    // a sweaty mid-treadmill glance reads it immediately. A thin capsule progress
    // bar beneath conveys remaining time pre-attentively without the battery cost
    // of a continuously redrawn radial ring.
    ///
    /// The phase column ("COOL / DOWN / 3/8") stacks one word per line so its
    /// width is set by a 4-5 glyph word, and the countdown is solved against
    /// what is left of the row. `showNext: false` drops the NEXT preview to pay
    /// for a safety banner on 40mm.
    func intervalCountdownHero(engine: IntervalEngine, rowWidth: CGFloat, labelSize: CGFloat,
                               showNext: Bool) -> some View {
        let stepColor = engine.currentStep.map { ShuttlXColor.forStepType($0.type) } ?? ShuttlXColor.textPrimary
        let stepProgress: Double = {
            guard let step = engine.currentStep, step.duration > 0 else { return 0 }
            return 1.0 - (engine.currentStepTimeRemaining / step.duration)
        }()
        let advance: CGFloat = 0.62
        let phaseSize = WatchScale.pt(13)
        let countdown = FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining))
        let phaseWords = engine.currentStep.map { $0.type.displayName.uppercased().split(separator: " ").map(String.init) } ?? []
        let counter = "\(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
        let phaseGlyphs = max(4, counter.count, phaseWords.map(\.count).max() ?? 0)
        let phaseWidth = CGFloat(phaseGlyphs) * advance * phaseSize
        let heroSize = max(16, min(WatchScale.pt(44),
                                   (rowWidth - phaseWidth - 6) / (CGFloat(countdown.count) * advance)))

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Text(countdown)
                    .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(stepColor)
                    .contentTransition(.numericText())
                    .fixedSize()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(phaseWords, id: \.self) { word in
                        Text(word)
                            .font(.system(size: phaseSize, weight: .bold, design: .monospaced))
                            .foregroundColor(stepColor)
                            .fixedSize()
                    }
                    Text(counter)
                        .font(.system(size: phaseSize, weight: .regular, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                        .monospacedDigit()
                        .fixedSize()
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
            .padding(.top, WatchScale.pt(3))

            // Next-step preview — only when there is a next step
            if showNext, let next = engine.nextStep {
                HStack(spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.6))
                    Image(systemName: "chevron.right")
                        .font(.system(size: labelSize * 0.8, weight: .semibold))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.5))
                    Text(next.type.displayName.uppercased())
                        .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.forStepType(next.type).opacity(0.75))
                    Text(formatStepDuration(next.duration))
                        .font(.system(size: labelSize, weight: .regular, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary.opacity(0.6))
                        .monospacedDigit()
                }
                .fixedSize()
                .padding(.top, WatchScale.pt(4))
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: engine.currentStepIndex)
                .accessibilityLabel("Next: \(next.type.displayName), \(formatStepDuration(next.duration))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        isHighHR(workoutManager.heartRate)
    }

    /// Heart-limit mode: with a synced limit (own or estimated, resolved on the phone)
    /// the banner fires above THAT limit — the same number the heart alerts use — so
    /// the screen and the alert never disagree. No limit: 90% of the estimated
    /// max HR — the exact HARD cut-off of `heartZoneWord`, so the banner never
    /// shows next to STEADY.
    func isHighHR(_ hr: Int) -> Bool {
        guard hr > 0 else { return false }
        if let limit = WatchSyncCoordinator.shared.heartSafety.upperLimit {
            return hr > limit
        }
        let maxHR = Int(hrCalculator.estimatedMaxHR.rounded())
        return HeartSafetySettings(upperLimit: maxHR).zoneWord(hr: hr) == "HARD"
    }

    /// HR the zone word is measured against: the synced heart limit, else the
    /// max-HR calculator. nil in effort-only mode (no word, no bar).
    var zoneReferenceHR: Double? {
        let safety = WatchSyncCoordinator.shared.heartSafety
        guard !safety.effortOnly else { return nil }
        return safety.upperLimit.map(Double.init) ?? hrCalculator.estimatedMaxHR
    }

    /// EASY < 70% / STEADY < 90% / HARD of `zoneReferenceHR` — the same split
    /// as `HeartSafetySettings.zoneWord`. nil without HR.
    var heartZoneWord: String? {
        let hr = workoutManager.heartRate
        guard hr > 0, let ref = zoneReferenceHR, ref > 0 else { return nil }
        return HeartSafetySettings(upperLimit: Int(ref.rounded())).zoneWord(hr: hr)
    }

    func zoneWordColor(_ word: String) -> Color {
        switch word {
        case "EASY": return ShuttlXColor.running.mix(with: .white, by: 0.45)
        case "STEADY": return ShuttlXColor.running
        default: return ShuttlXColor.ctaWarning
        }
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
                // Amber, not red: an instruction, not an alarm (timeline mockup).
                .foregroundColor(ShuttlXColor.ctaWarning)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ShuttlXColor.ctaWarning.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.4), value: isHighIntensityWarning)
        .accessibilityLabel(WatchSyncCoordinator.shared.heartSafety.upperLimit.map { "Heart rate high — ease off. Heart rate above your limit of \($0)." } ?? "Heart rate high — ease off. Heart rate above 90 percent of maximum.")
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
