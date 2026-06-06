import SwiftUI
import ShuttlXShared

/// Classic Radio–themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Classic Radio theme during
/// an active iPhone workout. The composition follows the 1960s wood-cabinet
/// tube-radio concept from
/// `design/proposals/timer-theme-redesigns/classic-radio.md`:
///
///   - Horizontal tuning dial with tick marks (styled as minute timestamps
///     0–30) drawn entirely with `Canvas`; a red needle sweeps left-to-right
///     as progress 0–100%. Interval mode: each step's type is printed as a
///     "station name" band on the dial and the needle parks at the current one.
///   - Warm amber backlit readout strip showing the elapsed/countdown time.
///   - Valve-glow radial gradient behind the readout that pulses with the HR
///     beat (at most 12% opacity — never crushes contrast against the warm
///     brown grain background).
///   - Brand plate at the top: "SHUTTLX · BAND: <mode>" in engraved serif caps.
///   - Three bakelite knob columns at the bottom:
///       TONE  = Heart Rate (knob pointer sweeps by zone)
///       VOLUME = Pace    (needle maps pace vs 5:00/km target)
///       BAND  = Distance (segmented band-selector; one notch per 0.5 km)
///   - Vintage push-button controls bar: CANCEL / SKIP / PLAY-PAUSE / STOP.
///   - Same `controller` method calls as `iPhoneWorkoutTimerView.controlsBar`.
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct ClassicRadioTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    // Classic Radio palette — hard-wired because this struct is only ever
    // displayed when `themeManager.current.id == "classicradio"`.
    private let cabinetBrown    = Color(red: 0.18, green: 0.11, blue: 0.06)   // #2E1C0F dark cabinet
    private let panelWarm       = Color(red: 0.22, green: 0.15, blue: 0.09)   // #382616 panel
    private let bezelCream      = Color(red: 0.92, green: 0.87, blue: 0.74)   // #EBDEbD celluloid scale
    private let dialCream       = Color(red: 0.96, green: 0.92, blue: 0.80)   // #F5EBB0 dial face
    private let needleRed       = Color(red: 0.85, green: 0.12, blue: 0.08)   // #D91F14 needle
    private let amberGlow       = Color(red: 1.00, green: 0.70, blue: 0.28)   // #FFB347 valve amber
    private let amberDim        = Color(red: 0.65, green: 0.42, blue: 0.10)   // dim amber label
    private let inkBrown        = Color(red: 0.28, green: 0.18, blue: 0.06)   // #47300F tick ink
    private let bakeliteDark    = Color(red: 0.14, green: 0.09, blue: 0.04)   // #241706 knob body
    private let bakeliteRim     = Color(red: 0.38, green: 0.26, blue: 0.12)   // #61421F knob rim
    private let pilotAmber      = Color(red: 1.00, green: 0.76, blue: 0.20)   // #FFC235 pilot lamp
    private let textCream       = Color(red: 0.90, green: 0.85, blue: 0.70)   // label text
    private let textDimCream    = Color(red: 0.65, green: 0.60, blue: 0.48)   // secondary label

    // MARK: - Body

    var body: some View {
        ZStack {
            // Warm brown cabinet background — let the existing
            // classicRadioBackground modifier render through the screen;
            // we only add the valve-glow pulse layer on top.
            valveGlowLayer

            // Foreground composition
            VStack(spacing: 0) {
                brandPlate
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                tuningDialSection
                    .padding(.horizontal, 16)

                amberReadoutStrip
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 4)

                knobRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                vintagePushButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges: .top)
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

    // MARK: - Valve glow background layer

    /// Radial amber pulse centred behind the readout — max 12% opacity so it
    /// never crushes contrast. Pulses once per detected heartbeat via a
    /// `TimelineView` that computes the beat phase from BPM.
    @ViewBuilder
    private var valveGlowLayer: some View {
        if reduceMotion {
            amberGlowCanvas(glowAlpha: 0.06)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 8.0)) { tl in
                let alpha = beatGlowAlpha(at: tl.date)
                amberGlowCanvas(glowAlpha: alpha)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func beatGlowAlpha(at date: Date) -> Double {
        let bpm = controller.heartRateMonitor.current
        guard bpm > 0 else { return 0.04 }
        let interval = 60.0 / Double(bpm)
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: interval) / interval
        // Sinusoidal: peaks at phase 0.0, fades through the beat interval
        let pulse = sin(phase * .pi)            // 0→1→0 over one beat
        return 0.04 + pulse * 0.08              // range: 0.04…0.12
    }

    private func amberGlowCanvas(glowAlpha: Double) -> some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            // Glow centred slightly below mid-screen (behind the readout strip)
            let cy = size.height * 0.56
            let radius = size.width * 0.75
            ctx.drawLayer { inner in
                inner.opacity = glowAlpha
                inner.fill(
                    Path { p in
                        p.addEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                                width: radius * 2, height: radius * 2))
                    },
                    with: .radialGradient(
                        Gradient(colors: [
                            amberGlow,
                            amberGlow.opacity(0)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }

    // MARK: - Brand plate

    private var brandPlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(bakeliteDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(bakeliteRim.opacity(0.6), lineWidth: 1)
                )

            HStack(spacing: 10) {
                // Maker circle — like a vintage brand medallion
                Circle()
                    .fill(amberGlow.opacity(0.15))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(amberDim.opacity(0.6), lineWidth: 1)
                    )
                    .overlay(
                        Text("S")
                            .font(.system(size: 11, weight: .black, design: .serif))
                            .foregroundStyle(amberGlow)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text("SHUTTLX")
                        .font(.system(size: 13, weight: .black, design: .serif))
                        .foregroundStyle(textCream)
                        .tracking(3)
                    Text("BAND: \(bandLabel)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(amberDim)
                        .tracking(2)
                }

                Spacer()

                if controller.isPaused {
                    Text("STANDBY")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(amberGlow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(amberGlow.opacity(0.15))
                        )
                        .overlay(
                            Capsule().stroke(amberGlow.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(controller.workoutName), band \(bandLabel)\(controller.isPaused ? ", standby" : "")")
    }

    private var bandLabel: String {
        switch controller.mode {
        case .freeRun:    return "FREE RUN"
        case .interval:   return "INTERVAL"
        case .gymRecovery: return "GYM RECOVERY"
        }
    }

    // MARK: - Horizontal tuning dial

    private var tuningDialSection: some View {
        ZStack {
            // Wooden bezel frame
            Canvas { ctx, size in
                drawDialBezel(ctx: ctx, size: size)
            }

            // Dial face + needle in a separate Canvas so it can be driven by
            // TimelineView without redrawing the bezel.
            Canvas { ctx, size in
                drawDialFace(ctx: ctx, size: size, progress: dialProgress)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .frame(height: 100)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(dialA11yLabel)
    }

    /// Progress fraction 0–1 driving the needle position.
    private var dialProgress: Double {
        switch controller.mode {
        case .freeRun:
            // Free run: needle sweeps over a nominal 30 minutes (1800 s)
            return min(1.0, controller.elapsedTime / 1800.0)
        case .interval:
            // Approximate total = elapsed so far + remaining time in current step.
            // This gives a "progress within the entire workout so far" estimate
            // without requiring access to all steps' durations.
            let engine = controller.intervalEngine
            let remaining = engine?.currentStepTimeRemaining ?? 0
            let approximateTotal = controller.elapsedTime + remaining
            guard approximateTotal > 0 else { return 0 }
            return min(1.0, controller.elapsedTime / approximateTotal)
        case .gymRecovery:
            return min(1.0, controller.elapsedTime / 1800.0)
        }
    }

    private var dialA11yLabel: String {
        let pct = Int(dialProgress * 100)
        return "Workout progress \(pct) percent"
    }

    /// Draws the outer wooden bezel (rounded dark-brown rectangle with a light
    /// inset frame line — like a real celluloid-faced dial housing).
    private func drawDialBezel(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let r: CGFloat = 10

        // Outer cabinet wood fill
        ctx.fill(
            Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: r),
            with: .color(panelWarm)
        )

        // Engraved rim — two strokes: outer dark, inner light
        ctx.stroke(
            Path(roundedRect: CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1), cornerRadius: r),
            with: .color(bakeliteRim.opacity(0.4)),
            lineWidth: 1
        )
        ctx.stroke(
            Path(roundedRect: CGRect(x: 2, y: 2, width: w - 4, height: h - 4), cornerRadius: r - 1),
            with: .color(textCream.opacity(0.1)),
            lineWidth: 0.5
        )
    }

    /// Draws the celluloid dial face: cream background, tick marks with minute
    /// labels, optional station-name bands (interval mode), and the red needle.
    private func drawDialFace(ctx: GraphicsContext, size: CGSize, progress: Double) {
        let w = size.width
        let h = size.height

        // Cream celluloid background
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .color(dialCream)
        )

        // Thin top edge ridge (glass cover highlight)
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: 2)),
            with: .color(Color.white.opacity(0.4))
        )

        // Subtle inner shadow at bottom (dial depth)
        ctx.fill(
            Path(CGRect(x: 0, y: h - 3, width: w, height: 3)),
            with: .color(inkBrown.opacity(0.18))
        )

        // ── Station-name bands (interval mode) ──────────────────────────
        drawStationBands(ctx: ctx, size: size)

        // ── Tick marks + minute labels ───────────────────────────────────
        let tickCount = 30   // one per minute mark 0..30
        let labelMinutes: Set<Int> = [0, 5, 10, 15, 20, 25, 30]
        let tickY: CGFloat = h - 14

        for i in 0...tickCount {
            let frac = CGFloat(i) / CGFloat(tickCount)
            let x = frac * w
            let isMajor = labelMinutes.contains(i)
            let tickH: CGFloat = isMajor ? 14 : (i % 5 == 0 ? 9 : 5)
            let alpha: Double = isMajor ? 0.85 : 0.5

            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: tickY - tickH))
            tickPath.addLine(to: CGPoint(x: x, y: tickY))
            ctx.stroke(tickPath,
                       with: .color(inkBrown.opacity(alpha)),
                       lineWidth: isMajor ? 1.5 : 0.8)

            // Label for major ticks
            if isMajor {
                // We resolve the label as a resolved text via ctx
                ctx.draw(
                    Text("\(i)")
                        .font(.system(size: 8, weight: .bold, design: .serif))
                        .foregroundStyle(inkBrown.opacity(0.8)),
                    at: CGPoint(x: x, y: tickY - tickH - 8),
                    anchor: .center
                )
            }
        }

        // ── Needle ────────────────────────────────────────────────────────
        let needleX = CGFloat(progress) * w
        let needleTopY: CGFloat = 2
        let needleBottomY: CGFloat = h - 2

        // Needle shadow
        ctx.drawLayer { inner in
            inner.opacity = 0.35
            var shadow = Path()
            shadow.move(to: CGPoint(x: needleX + 1.5, y: needleTopY))
            shadow.addLine(to: CGPoint(x: needleX + 1.5, y: needleBottomY))
            inner.stroke(shadow, with: .color(Color.black), lineWidth: 1.5)
        }

        // Needle body
        var needlePath = Path()
        needlePath.move(to: CGPoint(x: needleX, y: needleTopY))
        needlePath.addLine(to: CGPoint(x: needleX, y: needleBottomY))
        ctx.stroke(needlePath, with: .color(needleRed), lineWidth: 2.0)

        // Needle tip triangle (points upward)
        var tipPath = Path()
        tipPath.move(to: CGPoint(x: needleX - 5, y: needleTopY + 10))
        tipPath.addLine(to: CGPoint(x: needleX + 5, y: needleTopY + 10))
        tipPath.addLine(to: CGPoint(x: needleX, y: needleTopY))
        tipPath.closeSubpath()
        ctx.fill(tipPath, with: .color(needleRed))
    }

    /// Draws horizontal station-name bands for interval mode.
    ///
    /// Uses only the public `IntervalEngine` API: `totalStepsCount`,
    /// `currentStepIndex`, and `currentStep.type`. Individual step durations
    /// are not exposed, so bands are drawn equal-width.
    private func drawStationBands(ctx: GraphicsContext, size: CGSize) {
        guard controller.mode == .interval,
              let engine = controller.intervalEngine else { return }

        let total = engine.totalStepsCount
        guard total > 0 else { return }

        let w = size.width
        let bandH: CGFloat = size.height - 14   // leave room for ticks at bottom
        let stepW = w / CGFloat(total)
        let currentIdx = engine.currentStepIndex
        let currentType = engine.currentStep.map { appType(for: $0.type) }

        for idx in 0..<total {
            let xCursor = CGFloat(idx) * stepW
            let isActive = idx == currentIdx
            let isPast = idx < currentIdx

            let fillColor: Color = {
                if isActive { return amberGlow.opacity(0.18) }
                if isPast   { return inkBrown.opacity(0.10) }
                return Color.clear
            }()

            if fillColor != Color.clear {
                ctx.fill(
                    Path(CGRect(x: xCursor, y: 0, width: stepW, height: bandH)),
                    with: .color(fillColor)
                )
            }

            // Divider line between steps
            if idx < total - 1 {
                var divPath = Path()
                divPath.move(to: CGPoint(x: xCursor + stepW, y: 0))
                divPath.addLine(to: CGPoint(x: xCursor + stepW, y: bandH))
                ctx.stroke(divPath, with: .color(inkBrown.opacity(0.25)), lineWidth: 0.5)
            }

            // Station label — only for the active step (we know its type)
            // and only if the band is wide enough.
            if isActive, let type = currentType, stepW > 24 {
                let label = type.displayName.uppercased()
                let labelX = xCursor + stepW / 2
                let labelY: CGFloat = bandH / 2 - 6
                ctx.draw(
                    Text(label)
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(inkBrown.opacity(0.85)),
                    at: CGPoint(x: labelX, y: labelY),
                    anchor: .center
                )
            }
        }
    }

    // MARK: - Amber readout strip

    /// The warm amber backlit readout showing the key time value (elapsed /
    /// countdown / BPM depending on mode). This is the "numeric readout" in
    /// the dial frame mentioned in the spec.
    private var amberReadoutStrip: some View {
        ZStack {
            // Dark amber-lit bezel
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.08, green: 0.05, blue: 0.01))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(amberDim.opacity(0.5), lineWidth: 1)
                )

            HStack(spacing: 0) {
                // Main time value
                VStack(spacing: 2) {
                    Text(readoutTimeString)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(amberGlow)
                        .shadow(color: amberGlow.opacity(0.4), radius: 6)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(readoutSubLabel)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(amberDim)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityLabel(readoutA11yLabel)

                // Divider
                Rectangle()
                    .fill(amberDim.opacity(0.3))
                    .frame(width: 1, height: 44)

                // Step / interval context on the right
                VStack(alignment: .trailing, spacing: 3) {
                    if let pill = stepContext {
                        Text(pill.label)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(amberGlow.opacity(0.9))
                            .monospacedDigit()
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                        Text(pill.sub)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(amberDim)
                    } else {
                        Text(controller.workoutName.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(amberDim)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .frame(width: 90)
                .padding(.trailing, 10)
            }
            .padding(.vertical, 10)
            .padding(.leading, 16)
        }
        .frame(height: 88)
    }

    private var readoutTimeString: String {
        switch controller.mode {
        case .freeRun:
            return FormattingUtils.formatTimer(controller.elapsedTime)
        case .interval:
            let remaining = max(0, controller.intervalEngine?.currentStepTimeRemaining ?? 0)
            return FormattingUtils.formatTimer(remaining)
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return FormattingUtils.formatTimer(controller.elapsedTime)
            case .work:
                return FormattingUtils.formatTimer(controller.stationElapsedTime)
            case .rest:
                return FormattingUtils.formatTimer(controller.restElapsedTime)
            }
        }
    }

    private var readoutSubLabel: String {
        switch controller.mode {
        case .freeRun:   return "ELAPSED"
        case .interval:
            if let engine = controller.intervalEngine, let step = engine.currentStep {
                return "\(appType(for: step.type).displayName.uppercased()) REMAINING"
            }
            return "REMAINING"
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle: return "READY"
            case .work: return "STATION \(controller.recoverySetNumber)"
            case .rest: return "REST"
            }
        }
    }

    private var readoutA11yLabel: String {
        switch controller.mode {
        case .freeRun:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        case .interval:
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            let stepName = controller.intervalEngine?.currentStep.map { appType(for: $0.type).displayName } ?? "step"
            return "Time remaining in \(stepName), \(FormattingUtils.formatTimeAccessible(remaining))"
        case .gymRecovery:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        }
    }

    private struct StepContext { let label: String; let sub: String }

    private var stepContext: StepContext? {
        switch controller.mode {
        case .interval:
            guard let engine = controller.intervalEngine,
                  let step = engine.currentStep else { return nil }
            let name = appType(for: step.type).displayName.uppercased()
            return StepContext(
                label: "\(name) \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)",
                sub: FormattingUtils.formatTimer(engine.currentStepTimeRemaining)
            )
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepContext(label: "READY", sub: "")
            case .work:
                return StepContext(
                    label: "STATION \(controller.recoverySetNumber)",
                    sub: FormattingUtils.formatTimer(controller.stationElapsedTime)
                )
            case .rest:
                return StepContext(
                    label: "REST",
                    sub: FormattingUtils.formatTimer(controller.restElapsedTime)
                )
            }
        case .freeRun:
            return nil
        }
    }

    // MARK: - Three bakelite knobs

    private var knobRow: some View {
        HStack(spacing: 0) {
            knobColumn(
                label: "TONE",
                subValue: hrKnobValue,
                readout: hrReadoutString,
                readoutSub: hrReadoutSub,
                rotationFraction: hrRotationFraction,
                pilotColor: hrPilotColor
            )

            knobDivider

            knobColumn(
                label: "VOLUME",
                subValue: "PACE",
                readout: paceReadoutString,
                readoutSub: "/KM",
                rotationFraction: paceRotationFraction,
                pilotColor: amberGlow.opacity(0.6)
            )

            knobDivider

            knobColumn(
                label: "BAND",
                subValue: "DIST",
                readout: FormattingUtils.formatDistance(controller.totalDistance),
                readoutSub: "KM",
                rotationFraction: distRotationFraction,
                pilotColor: amberDim
            )
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(panelWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(bakeliteRim.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var knobDivider: some View {
        Rectangle()
            .fill(bakeliteRim.opacity(0.25))
            .frame(width: 1, height: 70)
    }

    /// A single knob column: engraved label at top, Canvas-drawn dial in the
    /// middle, numeric readout at the bottom.
    private func knobColumn(
        label: String,
        subValue: String,
        readout: String,
        readoutSub: String,
        rotationFraction: Double,
        pilotColor: Color
    ) -> some View {
        VStack(spacing: 5) {
            // Label
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(textDimCream)

            // Knob dial
            Canvas { ctx, size in
                drawKnob(ctx: ctx, size: size,
                         rotationFraction: rotationFraction,
                         pilotColor: pilotColor)
            }
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)

            // Sub-value label
            Text(subValue)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(textDimCream.opacity(0.6))

            // Readout value
            HStack(alignment: .bottom, spacing: 2) {
                Text(readout)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(amberGlow)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(readoutSub)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(amberDim)
                    .padding(.bottom, 1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(readout) \(readoutSub)")
    }

    /// Canvas-drawn bakelite knob. The knob is a dark circle with a ring of
    /// 12 thin tick marks (like a clock face, 7 o'clock through 5 o'clock arc),
    /// and a white pointer line rotating inside the tick arc.
    ///
    /// `rotationFraction` 0.0 = 7 o'clock (min), 1.0 = 5 o'clock (max).
    /// The usable arc runs from 225° (7 o'clock) to 315° + 90° = going clockwise
    /// to ~135° — a 270° sweep.
    private func drawKnob(ctx: GraphicsContext, size: CGSize,
                           rotationFraction: Double, pilotColor: Color) {
        let cx = size.width / 2
        let cy = size.height / 2
        let outerR = min(cx, cy) - 2

        // ── Outer tick ring (12 ticks over 270° arc, 7→5 o'clock) ────────
        let startDeg: Double = 225    // 7 o'clock
        let sweepDeg: Double = 270    // to 5 o'clock
        let tickCount = 11            // 0..10 = 11 divisions → 12 positions
        for i in 0...tickCount {
            let frac = Double(i) / Double(tickCount)
            let angleDeg = startDeg + frac * sweepDeg
            let angleRad = angleDeg * .pi / 180.0
            let isMajor = (i == 0 || i == tickCount || i == tickCount / 2)
            let innerR = outerR - (isMajor ? 8 : 5)

            let px1 = cx + CGFloat(cos(angleRad)) * (outerR - 1)
            let py1 = cy + CGFloat(sin(angleRad)) * (outerR - 1)
            let px2 = cx + CGFloat(cos(angleRad)) * innerR
            let py2 = cy + CGFloat(sin(angleRad)) * innerR

            var tickPath = Path()
            tickPath.move(to: CGPoint(x: px1, y: py1))
            tickPath.addLine(to: CGPoint(x: px2, y: py2))
            ctx.stroke(tickPath,
                       with: .color(textDimCream.opacity(isMajor ? 0.7 : 0.4)),
                       lineWidth: isMajor ? 1.5 : 0.8)
        }

        // ── Knob body ─────────────────────────────────────────────────────
        let knobR = outerR - 10

        // Base dark circle
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: cx - knobR, y: cy - knobR,
                                                 width: knobR * 2, height: knobR * 2)) },
            with: .color(bakeliteDark)
        )

        // Rim gradient (top-left lighter = worn gloss)
        ctx.drawLayer { inner in
            inner.opacity = 0.25
            inner.fill(
                Path { p in p.addEllipse(in: CGRect(x: cx - knobR, y: cy - knobR,
                                                     width: knobR * 2, height: knobR * 2)) },
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.5),
                        Color.white.opacity(0.0)
                    ]),
                    center: CGPoint(x: cx - knobR * 0.3, y: cy - knobR * 0.3),
                    startRadius: 0,
                    endRadius: knobR
                )
            )
        }

        // Outer ring stroke
        ctx.stroke(
            Path { p in p.addEllipse(in: CGRect(x: cx - knobR, y: cy - knobR,
                                                 width: knobR * 2, height: knobR * 2)) },
            with: .color(bakeliteRim.opacity(0.7)),
            lineWidth: 1.5
        )

        // ── Pointer line ──────────────────────────────────────────────────
        let pointerAngleDeg = startDeg + rotationFraction * sweepDeg
        let pointerAngleRad = pointerAngleDeg * .pi / 180.0
        let pointerInnerR = knobR * 0.25
        let pointerOuterR = knobR * 0.78

        let ppx1 = cx + CGFloat(cos(pointerAngleRad)) * pointerInnerR
        let ppy1 = cy + CGFloat(sin(pointerAngleRad)) * pointerInnerR
        let ppx2 = cx + CGFloat(cos(pointerAngleRad)) * pointerOuterR
        let ppy2 = cy + CGFloat(sin(pointerAngleRad)) * pointerOuterR

        var pointerPath = Path()
        pointerPath.move(to: CGPoint(x: ppx1, y: ppy1))
        pointerPath.addLine(to: CGPoint(x: ppx2, y: ppy2))
        ctx.stroke(pointerPath, with: .color(textCream.opacity(0.9)), lineWidth: 2.5)

        // Pointer tip dot
        let dotR: CGFloat = 2.5
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: ppx2 - dotR, y: ppy2 - dotR,
                                                 width: dotR * 2, height: dotR * 2)) },
            with: .color(textCream)
        )

        // ── Pilot light dot (top-right of knob face, inside the body) ────
        let pilotAngle: Double = 315 * .pi / 180  // top-right
        let pilotR = knobR * 0.5
        let px = cx + CGFloat(cos(pilotAngle)) * pilotR
        let py = cy + CGFloat(sin(pilotAngle)) * pilotR
        let plR: CGFloat = 3
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: px - plR, y: py - plR,
                                                 width: plR * 2, height: plR * 2)) },
            with: .color(pilotColor)
        )
    }

    // MARK: - Knob data helpers

    private var hrKnobValue: String {
        let bpm = controller.heartRateMonitor.current
        return bpm > 0 ? hrZoneLabel(bpm) : "—"
    }

    private var hrReadoutString: String {
        let bpm = controller.heartRateMonitor.current
        return bpm > 0 ? "\(bpm)" : "—"
    }

    private var hrReadoutSub: String { "BPM" }

    /// TONE knob: Z1=0.0 (7 o'clock), Z5=1.0 (5 o'clock).
    private var hrRotationFraction: Double {
        let bpm = controller.heartRateMonitor.current
        guard bpm > 0 else { return 0 }
        // Map 60–200 BPM → 0…1
        return max(0, min(1.0, (Double(bpm) - 60.0) / 140.0))
    }

    private var hrPilotColor: Color {
        let bpm = controller.heartRateMonitor.current
        guard bpm > 0 else { return amberDim.opacity(0.3) }
        return ShuttlXColor.forHRZone(bpm).opacity(0.8)
    }

    private var paceReadoutString: String {
        guard let pace = controller.currentPace else { return "—" }
        return FormattingUtils.formatPace(pace)
    }

    /// VOLUME knob: needle maps pace vs 5:00/km (300 s/km) target.
    /// Faster (lower s/km) = more clockwise.
    private var paceRotationFraction: Double {
        guard let pace = controller.currentPace, pace > 0 else { return 0.5 }
        // Range 150–600 s/km → 0…1 (inverted: lower s/km = higher fraction)
        let clamped = max(150.0, min(600.0, pace))
        return 1.0 - ((clamped - 150.0) / 450.0)
    }

    /// BAND knob: distance clicks one notch per 0.5 km.
    private var distRotationFraction: Double {
        // Assume a typical workout is up to 20 km → full rotation
        return min(1.0, controller.totalDistance / 20000.0)
    }

    // MARK: - Vintage push-button controls

    private var vintagePushButtons: some View {
        HStack(spacing: 10) {
            // Cancel
            vintageButton(
                symbol: "xmark",
                a11yLabel: "Cancel workout",
                a11yHint: "Ends without saving",
                accent: textDimCream.opacity(0.7)
            ) {
                showingCancelConfirmation = true
            }

            // Skip step (interval only)
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                vintageButton(
                    symbol: "forward.end.fill",
                    a11yLabel: "Skip step",
                    a11yHint: "Advances to the next step",
                    accent: amberGlow.opacity(0.8)
                ) {
                    controller.skipStep()
                }
            }

            // Play / Pause — wide primary button
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2.weight(.black))
                    Text(controller.isPaused ? "PLAY" : "PAUSE")
                        .font(.system(.subheadline, design: .monospaced).weight(.black))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.isPaused ? amberGlow : bakeliteRim)
                        // Top highlight line — vintage pressed-Bakelite sheen
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.3)
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(controller.isPaused ? amberGlow.opacity(0.6) : bakeliteRim.opacity(0.8),
                                lineWidth: 1)
                )
                .foregroundStyle(controller.isPaused ? cabinetBrown : textCream)
                .shadow(color: (controller.isPaused ? amberGlow : bakeliteRim).opacity(0.3),
                        radius: 4)
            }
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

            // Finish
            vintageButton(
                symbol: "stop.fill",
                a11yLabel: "Finish workout",
                a11yHint: "Saves and ends",
                accent: Color(red: 0.70, green: 0.20, blue: 0.10)
            ) {
                showingFinishConfirmation = true
            }
        }
    }

    @ViewBuilder
    private func vintageButton(
        symbol: String,
        a11yLabel: String,
        a11yHint: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bakeliteDark)
                        // Sheen line
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.clear],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.4)
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accent.opacity(0.5), lineWidth: 1)
                )
                .foregroundStyle(accent)
        }
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    // MARK: - Helpers (mirrors iPhoneWorkoutTimerView helpers)

    private func appType(for sharedType: ShuttlXShared.IntervalType) -> IntervalType {
        IntervalType(rawValue: sharedType.rawValue) ?? .work
    }

    private func hrZoneLabel(_ bpm: Int) -> String {
        guard bpm > 0 else { return "" }
        let pct = Double(bpm) / 185.0
        switch pct {
        case ..<0.60:      return "Z1"
        case 0.60..<0.70:  return "Z2"
        case 0.70..<0.80:  return "Z3"
        case 0.80..<0.90:  return "Z4"
        default:           return "Z5"
        }
    }
}

#if DEBUG
#Preview("Classic Radio Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    ClassicRadioTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
