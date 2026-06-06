import SwiftUI
import ShuttlXShared

/// Synthwave-themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Synthwave theme during an
/// active iPhone workout. The composition follows the Outrun dashboard concept
/// from `design/proposals/timer-theme-redesigns/synthwave.md`:
///
///   - Perspective grid + neon sun horizon animated by `TimelineView`
///   - Central chevroned trapezoid frame housing the timer/countdown/BPM hero
///   - Progress bar (interval mode) inside the trapezoid
///   - Three bottom gauges: HR (left), Pace (center), Distance (right)
///   - Step/interval destination-sign pill on the top edge of the trapezoid
///   - Sticky controls bar (mirrors `iPhoneWorkoutTimerView.controlsBar`)
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct SynthwaveTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    // Synthwave palette — hard-wired to the theme because this struct is only
    // ever displayed when `themeManager.current.id == "synthwave"`.
    private let neonCyan    = Color(red: 0.0,  green: 0.96, blue: 1.0)    // #00F5FF
    private let neonMagenta = Color(red: 1.0,  green: 0.18, blue: 0.58)   // #FF2D95
    private let neonAmber   = Color(red: 1.0,  green: 0.72, blue: 0.0)    // #FFB800
    private let neonGreen   = Color(red: 0.22, green: 1.0,  blue: 0.08)   // #39FF14
    private let deepNavy    = Color(red: 0.04, green: 0.04, blue: 0.10)   // #0A0A1A
    private let surfaceBlue = Color(red: 0.08, green: 0.08, blue: 0.16)   // #141428

    var body: some View {
        ZStack {
            // ── Background (animated grid + sun) ──────────────────────────
            if reduceMotion {
                staticHorizonBackground
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    animatedHorizonBackground(date: timeline.date)
                }
            }

            // ── Foreground composition ─────────────────────────────────────
            VStack(spacing: 0) {
                // Workout name header
                workoutHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Spacer(minLength: 0)

                // Trapezoid hero frame
                trapezoidHeroSection
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                // Bottom three-column gauge strip
                gaugeStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Controls
                synthwaveControlsBar
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

    // MARK: - Animated horizon background

    /// Grid scroll speed: base 20pt/s + pace contribution (faster run = faster grid).
    private func gridSpeed(at date: Date) -> Double {
        let base: Double = 20
        // currentPace is seconds/km — lower = faster. Scale to a bonus 0–30 pts/s.
        let paceBonus: Double = {
            guard let pace = controller.currentPace, pace > 0 else { return 0 }
            let inverted = max(0, 600.0 - pace)    // 600 s/km ~ walking threshold
            return min(30, inverted * 0.05)
        }()
        return base + paceBonus
    }

    @ViewBuilder
    private func animatedHorizonBackground(date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        Canvas { ctx, size in
            var mutableCtx = ctx
            drawHorizon(ctx: &mutableCtx, size: size, t: t, speed: gridSpeed(at: date))
        }
        .ignoresSafeArea()
    }

    private var staticHorizonBackground: some View {
        Canvas { ctx, size in
            var mutableCtx = ctx
            drawHorizon(ctx: &mutableCtx, size: size, t: 0, speed: 0)
        }
        .ignoresSafeArea()
    }

    private func drawHorizon(ctx: inout GraphicsContext, size: CGSize, t: TimeInterval, speed: Double) {
        let w = size.width
        let h = size.height
        let horizon = h * 0.42  // horizon line height

        // ── Sky gradient ─────────────────────────────────────────────────
        let skyGrad = Gradient(colors: [
            Color(red: 0.04, green: 0.04, blue: 0.10),
            Color(red: 0.08, green: 0.02, blue: 0.18),
            Color(red: 0.22, green: 0.04, blue: 0.20)
        ])
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: horizon)),
            with: .linearGradient(skyGrad,
                                  startPoint: CGPoint(x: w / 2, y: 0),
                                  endPoint: CGPoint(x: w / 2, y: horizon))
        )

        // ── Ground gradient ───────────────────────────────────────────────
        let groundGrad = Gradient(colors: [
            Color(red: 0.12, green: 0.02, blue: 0.16),
            Color(red: 0.04, green: 0.04, blue: 0.10)
        ])
        ctx.fill(
            Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
            with: .linearGradient(groundGrad,
                                  startPoint: CGPoint(x: w / 2, y: horizon),
                                  endPoint: CGPoint(x: w / 2, y: h))
        )

        // ── Sun glow ──────────────────────────────────────────────────────
        let cx = w / 2
        let sunY = horizon - 10.0
        let beatPulse: Double = {
            let bpm = controller.heartRateMonitor.current
            guard bpm > 0 else { return 0 }
            let interval = 60.0 / Double(bpm)
            let phase = t.truncatingRemainder(dividingBy: interval) / interval
            // Smooth sinusoidal pulse: 0 at rest, peak at heartbeat
            return sin(phase * .pi) * 0.15
        }()
        let sunRadius = 52.0 + beatPulse * 20

        // Outer magenta haze
        ctx.drawLayer { inner in
            inner.opacity = 0.25 + beatPulse
            inner.fill(
                Path { p in p.addEllipse(in: CGRect(x: cx - sunRadius * 2.2,
                                                    y: sunY - sunRadius * 2.2,
                                                    width: sunRadius * 4.4,
                                                    height: sunRadius * 4.4)) },
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.18, blue: 0.58).opacity(0.5),
                        Color(red: 1.0, green: 0.18, blue: 0.58).opacity(0)
                    ]),
                    center: CGPoint(x: cx, y: sunY),
                    startRadius: 0,
                    endRadius: sunRadius * 2.2
                )
            )
        }

        // Sun body + stripes — drawn in an isolated layer clipped to the sky half
        let sunRect = CGRect(x: cx - sunRadius, y: sunY - sunRadius,
                             width: sunRadius * 2, height: sunRadius * 2)
        ctx.drawLayer { sunCtx in
            // Clip to sky half so the bottom semicircle is hidden by the horizon
            sunCtx.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: horizon)))

            // Sun gradient fill
            sunCtx.fill(
                Path { p in p.addEllipse(in: sunRect) },
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.72, blue: 0.0),
                        Color(red: 1.0, green: 0.18, blue: 0.58)
                    ]),
                    startPoint: CGPoint(x: cx, y: sunY - sunRadius),
                    endPoint: CGPoint(x: cx, y: sunY + sunRadius)
                )
            )

            // Horizontal Outrun stripes clipped to sun disc
            sunCtx.drawLayer { stripeCtx in
                stripeCtx.clip(to: Path { p in p.addEllipse(in: sunRect) })
                let stripeCount = 7
                for i in 0..<stripeCount {
                    let frac = Double(i) / Double(stripeCount - 1)
                    let sy = sunY - sunRadius + frac * sunRadius * 2
                    stripeCtx.fill(
                        Path(CGRect(x: cx - sunRadius, y: sy, width: sunRadius * 2, height: 2)),
                        with: .color(deepNavy.opacity(0.55))
                    )
                }
            }
        }

        // ── Perspective grid ──────────────────────────────────────────────
        // Vertical lines converging to vanishing point at horizon center
        let vp = CGPoint(x: cx, y: horizon)
        let gridLineCount = 11
        let spreadHalf = w * 1.2
        for i in 0...gridLineCount {
            let t_x = Double(i) / Double(gridLineCount)
            let bx = cx - spreadHalf + t_x * spreadHalf * 2
            var p = Path()
            p.move(to: vp)
            p.addLine(to: CGPoint(x: bx, y: h))
            ctx.stroke(p, with: .color(neonMagenta.opacity(0.35)), lineWidth: 1)
        }

        // Horizontal lines — scrolling downward at `speed` pts/s
        let lineSpacingAtBottom: Double = 36
        let scrollOffset = speed > 0 ? (t * speed).truncatingRemainder(dividingBy: lineSpacingAtBottom) : 0
        var lineY = horizon + scrollOffset
        while lineY < h {
            // Perspective scale: lines near horizon are thin and faint; near
            // the bottom they are wide and bright.
            let frac = (lineY - horizon) / (h - horizon)  // 0 at horizon, 1 at bottom
            let alpha = 0.15 + frac * 0.55
            let lw = 0.5 + frac * 1.5
            var p = Path()
            // Clip horizontal lines between the two outermost vertical lines
            let leftX  = cx + (cx - spreadHalf - cx) * frac
            let rightX = cx + (cx + spreadHalf - cx) * frac
            p.move(to: CGPoint(x: leftX,  y: lineY))
            p.addLine(to: CGPoint(x: rightX, y: lineY))
            ctx.stroke(p, with: .color(neonCyan.opacity(alpha)), lineWidth: lw)
            // Next line spacing grows by perspective
            lineY += lineSpacingAtBottom * max(0.08, frac)
        }

        // Horizon glow line
        var horizPath = Path()
        horizPath.move(to: CGPoint(x: 0, y: horizon))
        horizPath.addLine(to: CGPoint(x: w, y: horizon))
        ctx.stroke(horizPath, with: .color(neonMagenta.opacity(0.7)), lineWidth: 1.5)
    }

    // MARK: - Workout name header

    private var workoutHeader: some View {
        HStack(spacing: 8) {
            Text(controller.workoutName.uppercased())
                .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                .foregroundStyle(controller.isPaused ? neonAmber : neonCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: neonCyan.opacity(0.6), radius: 4)
            Spacer()
            if controller.isPaused {
                Text("PAUSED")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(neonAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(neonAmber.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(neonAmber.opacity(0.5), lineWidth: 1))
            }
        }
    }

    // MARK: - Trapezoid hero section

    @ViewBuilder
    private var trapezoidHeroSection: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                // Trapezoid canvas frame
                Canvas { ctx, size in
                    drawTrapezoid(ctx: ctx, size: size)
                }

                // Step destination-sign pill — floats on the top edge
                if let pill = stepPillInfo {
                    VStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pill.color)
                                .frame(width: 6, height: 6)
                            Text(pill.label.uppercased())
                                .font(.system(.caption, design: .monospaced).weight(.heavy))
                                .foregroundStyle(pill.color)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(pill.color.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(pill.color.opacity(0.6), lineWidth: 1)
                                )
                        )
                        .shadow(color: pill.color.opacity(0.5), radius: 4)
                        Spacer()
                    }
                    .padding(.top, 10)
                }

                // Hero readout centred in the trapezoid
                VStack(spacing: 6) {
                    heroReadout
                        .frame(maxWidth: w - 60)

                    // Interval progress bar across the trapezoid width
                    if controller.mode == .interval {
                        intervalProgressBar
                            .frame(maxWidth: w - 80)
                    }
                }
                .padding(.top, 16)
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Canvas draws a neon chevron-edged trapezoid outline.
    private func drawTrapezoid(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let inset: CGFloat = 20  // narrower at top
        var path = Path()
        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: w - inset, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        // Fill
        ctx.fill(path, with: .color(Color(red: 0.0, green: 0.0, blue: 0.08).opacity(0.75)))

        // Cyan outer stroke
        ctx.stroke(path, with: .color(neonCyan.opacity(0.7)), lineWidth: 1.5)

        // Magenta inner glow stroke (slightly inset)
        var innerPath = Path()
        let ii: CGFloat = 5
        innerPath.move(to: CGPoint(x: inset + ii, y: ii))
        innerPath.addLine(to: CGPoint(x: w - inset - ii, y: ii))
        innerPath.addLine(to: CGPoint(x: w - ii, y: h - ii))
        innerPath.addLine(to: CGPoint(x: ii, y: h - ii))
        innerPath.closeSubpath()
        ctx.stroke(innerPath, with: .color(neonMagenta.opacity(0.35)), lineWidth: 0.8)

        // Chevron tick marks on top edge (▼ symbols as triangles)
        let tickCount = 5
        for i in 0..<tickCount {
            let frac = CGFloat(i + 1) / CGFloat(tickCount + 1)
            let tx = inset + frac * (w - inset * 2)
            var tick = Path()
            tick.move(to: CGPoint(x: tx - 5, y: 0))
            tick.addLine(to: CGPoint(x: tx + 5, y: 0))
            tick.addLine(to: CGPoint(x: tx, y: 7))
            tick.closeSubpath()
            ctx.fill(tick, with: .color(neonCyan.opacity(0.55)))
        }
    }

    // MARK: - Hero readout (timer / countdown / BPM)

    @ViewBuilder
    private var heroReadout: some View {
        switch controller.mode {
        case .freeRun:
            elapsedHero
        case .interval:
            countdownHero
        case .gymRecovery:
            gymBpmHero
        }
    }

    private var elapsedHero: some View {
        VStack(spacing: 2) {
            neonTimerText(
                FormattingUtils.formatTimer(controller.elapsedTime),
                color: neonCyan,
                size: 76
            )
            Text("ELAPSED")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(neonCyan.opacity(0.6))
        }
        .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))")
    }

    private var countdownHero: some View {
        let engine = controller.intervalEngine
        let stepColor: Color = engine?.currentStep.map { sharedStepColor($0.type) } ?? neonCyan
        let remaining = engine?.currentStepTimeRemaining ?? 0
        return VStack(spacing: 2) {
            neonTimerText(
                FormattingUtils.formatTimer(max(0, remaining)),
                color: stepColor,
                size: 76
            )
            Text("REMAINING")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(stepColor.opacity(0.6))
        }
        .accessibilityLabel("Time remaining \(FormattingUtils.formatTimeAccessible(remaining))")
    }

    private var gymBpmHero: some View {
        let bpm = controller.heartRateMonitor.current
        let zoneColor = bpm > 0 ? ShuttlXColor.forHRZone(bpm) : neonCyan
        return VStack(spacing: 2) {
            neonTimerText(
                bpm > 0 ? "\(bpm)" : "—",
                color: zoneColor,
                size: 80
            )
            Text("BPM")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(zoneColor.opacity(0.6))
        }
        .accessibilityLabel(bpm > 0 ? "Heart rate \(bpm) beats per minute" : "Heart rate no data")
    }

    /// Dual-layer neon bloom text: base + blurred overlay for the CRT bloom effect.
    @ViewBuilder
    private func neonTimerText(_ text: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            // Bloom layer
            Text(text)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .blur(radius: 8)
                .blendMode(.plusLighter)
            // Crisp layer on top
            Text(text)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .shadow(color: color.opacity(0.8), radius: 6)
    }

    // MARK: - Interval progress bar

    private var intervalProgressBar: some View {
        let engine = controller.intervalEngine
        let stepColor: Color = engine?.currentStep.map { sharedStepColor($0.type) } ?? neonCyan
        let progress: Double = {
            guard let step = engine?.currentStep, step.duration > 0,
                  let remaining = engine?.currentStepTimeRemaining else { return 0 }
            return 1.0 - (remaining / step.duration)
        }()

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(stepColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(stepColor.opacity(0.3), lineWidth: 0.5)
                    )
                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(stepColor)
                    .frame(width: max(0, proxy.size.width * progress))
                    .shadow(color: stepColor.opacity(0.6), radius: 4)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Three-column gauge strip (HR | PACE | DIST)

    private var gaugeStrip: some View {
        HStack(spacing: 0) {
            // Left: HR gauge
            hrGauge
                .frame(maxWidth: .infinity)

            // Divider lines
            neonDivider

            // Center: Pace
            paceGauge
                .frame(maxWidth: .infinity)

            neonDivider

            // Right: Distance
            distGauge
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(surfaceBlue.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(neonCyan.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: neonCyan.opacity(0.12), radius: 8)
        )
    }

    private var neonDivider: some View {
        Rectangle()
            .fill(neonMagenta.opacity(0.3))
            .frame(width: 1, height: 36)
    }

    private var hrGauge: some View {
        let bpm = controller.heartRateMonitor.current
        let zoneColor: Color = bpm > 0 ? ShuttlXColor.forHRZone(bpm) : neonMagenta
        let barFrac = bpm > 0 ? min(1.0, Double(bpm) / 200.0) : 0.0
        let zoneLabel = bpm > 0 ? hrZoneLabel(bpm) : ""

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                Text(bpm > 0 ? "\(bpm)" : "—")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(zoneColor)
                    .shadow(color: zoneColor.opacity(0.6), radius: 4)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(zoneColor.opacity(0.7))
                    .padding(.bottom, 2)
            }
            if !zoneLabel.isEmpty {
                Text(zoneLabel)
                    .font(.system(size: 9, design: .monospaced).weight(.heavy))
                    .foregroundStyle(zoneColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(zoneColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(zoneColor.opacity(0.4), lineWidth: 0.5))
            }
            // Vertical neon bar (zone indicator)
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(zoneColor.opacity(0.12))
                        .frame(width: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(zoneColor)
                        .frame(width: 8, height: proxy.size.height * barFrac)
                        .shadow(color: zoneColor.opacity(0.7), radius: 3)
                        .animation(.spring(duration: 1.2), value: barFrac)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 20)
            Text("HR")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0 ? "Heart rate \(bpm) beats per minute \(zoneLabel)" : "No heart rate data")
    }

    private var paceGauge: some View {
        let paceStr = controller.currentPace.map { FormattingUtils.formatPace($0) } ?? "—"
        // Chevron arrows animate left-to-right when faster than 5:00/km (300 s/km)
        let isFast = controller.currentPace.map { $0 < 300 } ?? false

        return VStack(spacing: 4) {
            Text(paceStr)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.pace)
                .shadow(color: ShuttlXColor.pace.opacity(0.5), radius: 4)
                .contentTransition(.numericText())
            Text("/KM")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(ShuttlXColor.pace.opacity(0.7))
            // Chevron animation
            if isFast && !reduceMotion {
                TimelineView(.animation(minimumInterval: 0.35)) { tl in
                    chevronArrows(date: tl.date)
                }
            } else {
                chevronArrows(date: .distantPast)
                    .opacity(0.25)
            }
            Text("PACE")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace \(paceStr) per kilometer")
    }

    @ViewBuilder
    private func chevronArrows(date: Date) -> some View {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.05)
        let positions: [CGFloat] = [0.0, 0.35, 0.70]
        HStack(spacing: 2) {
            ForEach(Array(positions.enumerated()), id: \.offset) { idx, offset in
                let progress = (phase - offset)
                    .truncatingRemainder(dividingBy: 1.05)
                let alpha = progress < 0 ? 0.15 : min(1.0, progress / 0.35)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(ShuttlXColor.pace.opacity(alpha))
            }
        }
    }

    private var distGauge: some View {
        let distStr = FormattingUtils.formatDistance(controller.totalDistance)
        return VStack(spacing: 4) {
            Text(distStr)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.running)
                .shadow(color: ShuttlXColor.running.opacity(0.5), radius: 4)
                .contentTransition(.numericText())
            Text("KM")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(ShuttlXColor.running.opacity(0.7))
            // STEPS as secondary in compact badge
            Text("\(controller.totalSteps)")
                .font(.system(size: 11, design: .monospaced).weight(.semibold))
                .foregroundStyle(ShuttlXColor.steps)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("DIST")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance \(distStr), steps \(controller.totalSteps)")
    }

    // MARK: - Controls bar (same actions as iPhoneWorkoutTimerView.controlsBar)

    private var synthwaveControlsBar: some View {
        HStack(spacing: 12) {
            // Cancel (xmark)
            Button {
                showingCancelConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(surfaceBlue))
                    .overlay(Circle().stroke(neonMagenta.opacity(0.4), lineWidth: 1))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .shadow(color: neonMagenta.opacity(0.2), radius: 4)
            }
            .accessibilityLabel("Cancel workout")
            .accessibilityHint("Ends without saving")

            // Skip step (interval only)
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                Button {
                    controller.skipStep()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3.weight(.bold))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(surfaceBlue))
                        .overlay(Circle().stroke(neonCyan.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(neonCyan)
                        .shadow(color: neonCyan.opacity(0.3), radius: 4)
                }
                .accessibilityLabel("Skip step")
            }

            // Pause / Resume
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(neonCyan.opacity(0.9))
                            .shadow(color: neonCyan.opacity(0.5), radius: 8)
                    )
                    .foregroundStyle(deepNavy)
            }
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

            // Finish (checkmark)
            Button {
                showingFinishConfirmation = true
            } label: {
                Image(systemName: "checkmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(neonMagenta.opacity(0.9)))
                    .overlay(Circle().stroke(neonMagenta, lineWidth: 1))
                    .foregroundStyle(.white)
                    .shadow(color: neonMagenta.opacity(0.5), radius: 6)
            }
            .accessibilityLabel("Finish workout")
            .accessibilityHint("Saves and ends")
        }
    }

    // MARK: - Step pill helper

    private struct StepPillInfo {
        let label: String
        let color: Color
    }

    private var stepPillInfo: StepPillInfo? {
        switch controller.mode {
        case .interval:
            guard let engine = controller.intervalEngine,
                  let step = engine.currentStep else { return nil }
            let remaining = engine.currentStepTimeRemaining
            let label = "\(displayName(for: step.type).uppercased()) · \(FormattingUtils.formatTimer(remaining))"
            return StepPillInfo(label: label, color: sharedStepColor(step.type))
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepPillInfo(label: "READY", color: ShuttlXColor.textSecondary)
            case .work:
                let label = "STATION \(controller.recoverySetNumber) · \(FormattingUtils.formatTimer(controller.stationElapsedTime))"
                return StepPillInfo(label: label, color: ShuttlXColor.ctaPrimary)
            case .rest:
                let label = "REST · \(FormattingUtils.formatTimer(controller.restElapsedTime))"
                return StepPillInfo(label: label, color: neonAmber)
            }
        case .freeRun:
            return nil
        }
    }

    // MARK: - Helpers (mirrors iPhoneWorkoutTimerView helpers)

    private func appType(for sharedType: ShuttlXShared.IntervalType) -> IntervalType {
        IntervalType(rawValue: sharedType.rawValue) ?? .work
    }

    private func sharedStepColor(_ sharedType: ShuttlXShared.IntervalType) -> Color {
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
}

#if DEBUG
#Preview("Synthwave Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    SynthwaveTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
