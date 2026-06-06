import SwiftUI
import ShuttlXShared

/// VU Meter–themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the VU Meter theme during an
/// active iPhone workout. The composition follows the analog panel-mount
/// concept from `design/proposals/timer-theme-redesigns/vu-meter.md`:
///
///   - Large analog VU meter face (Canvas-drawn arc, dB scale -20…0…+3) whose
///     needle is driven by HR as a fraction of max HR (60–200 BPM). A
///     `TimelineView` at 30 fps gives the needle smooth spring-ballistic motion.
///   - Peak-hold LED that latches when HR enters Z4/Z5 (≥80% of 185 BPM).
///   - Recessed elapsed/countdown counter below the pivot.
///   - Three secondary mini-gauge strips: Pace | Distance | Steps.
///   - Vintage panel-mount aesthetic: amber backlight, brass screw decorations
///     at the four corners of the meter face.
///   - Controls styled as audio rack-mount buttons.
///   - Same `controller` method calls as `iPhoneWorkoutTimerView.controlsBar`.
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct VUMeterTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    /// Session peak HR for the peak-hold LED. Resets when elapsed time reaches 0
    /// (i.e. a new workout has started).
    @State private var peakHR: Int = 0
    @State private var lastElapsedForPeakReset: TimeInterval = 0

    /// Smoothed needle angle (degrees) — driven by a spring animation.
    @State private var needleAngleDeg: Double = -45   // starts at −45° (60 BPM end of scale)

    // VU Meter palette — hard-wired because this struct is only ever displayed
    // when `themeManager.current.id == "vumeter"`.
    private let panelDark       = Color(red: 0.08, green: 0.06, blue: 0.03)   // #140F08 panel
    private let panelMid        = Color(red: 0.13, green: 0.10, blue: 0.05)   // #211A0D mid panel
    private let meterFace       = Color(red: 0.97, green: 0.94, blue: 0.84)   // #F7EFD6 cream face
    private let meterFaceShadow = Color(red: 0.88, green: 0.84, blue: 0.72)   // shadow on face
    private let amberGlow       = Color(red: 1.00, green: 0.72, blue: 0.18)   // #FFB82E amber
    private let amberDim        = Color(red: 0.60, green: 0.40, blue: 0.08)   // dim amber
    private let needleBlack     = Color(red: 0.08, green: 0.06, blue: 0.04)   // needle
    private let scaleInk        = Color(red: 0.20, green: 0.14, blue: 0.06)   // scale print
    private let brassColor      = Color(red: 0.72, green: 0.58, blue: 0.28)   // #B8942F brass screw
    private let ledRed          = Color(red: 0.95, green: 0.18, blue: 0.12)   // #F22E1E peak LED
    private let ledOff          = Color(red: 0.28, green: 0.08, blue: 0.06)   // unlit LED
    private let rackSteel       = Color(red: 0.24, green: 0.22, blue: 0.18)   // rack panel
    private let rackBorder      = Color(red: 0.40, green: 0.36, blue: 0.28)   // rack border

    // MARK: - Body

    var body: some View {
        ZStack {
            // Ambient amber glow layer pulsing with HR
            amberAmbientLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Workout name header bar (rack-mount style)
                rackNameBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Large VU meter face card
                vuMeterCard
                    .padding(.horizontal, 16)

                // Three secondary mini-gauge strips
                secondaryMetricsStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                // Rack-mount controls bar
                rackControlsBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges: .top)
        // Update peakHR and smooth needle state whenever HR changes
        .onChange(of: controller.heartRateMonitor.current) { _, newBPM in
            updatePeakAndNeedle(bpm: newBPM)
        }
        // Reset peak if elapsed resets to 0 (new workout)
        .onChange(of: controller.elapsedTime) { _, newTime in
            if newTime < 1.0 && lastElapsedForPeakReset > 5.0 {
                peakHR = 0
            }
            lastElapsedForPeakReset = newTime
        }
        .onAppear {
            updatePeakAndNeedle(bpm: controller.heartRateMonitor.current)
        }
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

    // MARK: - Peak / needle state

    private func updatePeakAndNeedle(bpm: Int) {
        if bpm > peakHR { peakHR = bpm }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            needleAngleDeg = bpmToAngle(bpm)
        }
    }

    /// Maps BPM 60…200 → needle angle −45°…+45°.
    /// The scale runs from −45° (left/60 BPM) through 0° (center/"0 dB" zone
    /// midpoint) to +45° (right/200 BPM).
    private func bpmToAngle(_ bpm: Int) -> Double {
        guard bpm > 0 else { return -45 }
        let fraction = max(0.0, min(1.0, (Double(bpm) - 60.0) / 140.0))
        return -45.0 + fraction * 90.0   // −45° … +45°
    }

    /// True when HR is in Z4 or Z5 (≥80% of 185 BPM = ≥148 BPM).
    private var isRedZone: Bool {
        let bpm = controller.heartRateMonitor.current
        return bpm > 0 && Double(bpm) / 185.0 >= 0.80
    }

    // MARK: - Ambient amber glow

    @ViewBuilder
    private var amberAmbientLayer: some View {
        if reduceMotion {
            amberGlowCanvas(alpha: 0.06)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 8.0)) { tl in
                let alpha = beatAlpha(at: tl.date)
                amberGlowCanvas(alpha: alpha)
            }
        }
    }

    private func beatAlpha(at date: Date) -> Double {
        let bpm = controller.heartRateMonitor.current
        guard bpm > 0 else { return 0.05 }
        let interval = 60.0 / Double(bpm)
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: interval) / interval
        return 0.05 + sin(phase * .pi) * 0.07
    }

    private func amberGlowCanvas(alpha: Double) -> some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height * 0.42
            let r  = size.width * 0.65
            ctx.drawLayer { inner in
                inner.opacity = alpha
                inner.fill(
                    Path { p in
                        p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                    },
                    with: .radialGradient(
                        Gradient(colors: [amberGlow, amberGlow.opacity(0)]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }
    }

    // MARK: - Rack name bar

    private var rackNameBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(rackSteel)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(rackBorder.opacity(0.8), lineWidth: 1)
                )

            HStack(spacing: 8) {
                // Pilot lamp (amber = running, off = paused)
                Circle()
                    .fill(controller.isPaused ? amberDim.opacity(0.3) : amberGlow)
                    .frame(width: 8, height: 8)
                    .shadow(color: controller.isPaused ? .clear : amberGlow.opacity(0.7), radius: 4)

                Text(controller.workoutName.uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                    .foregroundStyle(controller.isPaused ? amberDim : amberGlow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .tracking(1.5)

                Spacer()

                if controller.isPaused {
                    Text("STANDBY")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(amberDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(amberDim.opacity(0.18))
                        )
                        .overlay(
                            Capsule().stroke(amberDim.opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Main VU meter card

    private var vuMeterCard: some View {
        ZStack {
            // Outer rack-panel bezel
            RoundedRectangle(cornerRadius: 10)
                .fill(panelDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rackBorder.opacity(0.6), lineWidth: 1.5)
                )

            VStack(spacing: 0) {
                // Step pill at the top
                if let pill = stepPillInfo {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(pill.color)
                            .frame(width: 6, height: 6)
                        Text(pill.label.uppercased())
                            .font(.system(.caption, design: .monospaced).weight(.heavy))
                            .foregroundStyle(pill.color)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(pill.color.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(pill.color.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .padding(.top, 8)
                }

                // Meter face (cream) with arc + needle
                GeometryReader { proxy in
                    ZStack {
                        // Cream meter face
                        RoundedRectangle(cornerRadius: 6)
                            .fill(meterFace)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), meterFaceShadow.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Scale arc + tick marks + needle (Canvas)
                        Canvas { ctx, size in
                            drawMeterArc(ctx: ctx, size: size)
                        }

                        // Animated needle overlay (separate so it can animate)
                        needleView(in: proxy.size)

                        // Peak-hold LED (top-right of face, above the scale)
                        peakLEDOverlay

                        // Brass screw decorations at four corners
                        screwDecorations
                    }
                }
                .frame(height: 190)
                .padding(10)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityLabel(meterA11yLabel)

                // Recessed counter below the pivot
                recessedCounter
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(height: 310)
    }

    // MARK: - Scale arc (Canvas)

    /// Draws the cream meter face decorations: arc, tick marks, dB labels.
    ///
    /// The arc spans from −135° to −45° in SwiftUI coordinates (a 90° sweep
    /// centered at the bottom of a semicircle) — this is the classic VU meter
    /// geometry where the pivot is at the bottom center of the arc.
    ///
    /// Scale: −20 dB … 0 dB … +3 dB, mapped to BPM 60…140…200.
    private func drawMeterArc(ctx: GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height * 0.82   // pivot point well below center

        // Arc radius fitted to the face size
        let arcR: CGFloat = min(size.width * 0.82, cy * 1.1)

        // Sweep: from startAngle to endAngle (both measured from 3 o'clock = 0°)
        // Arc goes from 210° (left, -20 dB) to 330° (right, +3 dB) — a 120° sweep
        let arcStart: Double = 210 * .pi / 180
        let arcEnd:   Double = 330 * .pi / 180

        // ── Arc track (thin line) ─────────────────────────────────────────
        var arcPath = Path()
        arcPath.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: arcR,
            startAngle: .degrees(210),
            endAngle: .degrees(330),
            clockwise: false
        )
        ctx.stroke(arcPath,
                   with: .color(scaleInk.opacity(0.25)),
                   lineWidth: 1)

        // ── dB scale ticks ────────────────────────────────────────────────
        // Scale points: -20, -10, -7, -5, -3, -2, -1, 0, +1, +2, +3 dB
        // Mapped to BPM positions for the needle, but labeled as dB values.
        let scalePoints: [(dbVal: String, fraction: Double)] = [
            ("-20", 0.00),
            ("-10", 0.20),
            ("-7",  0.35),
            ("-5",  0.46),
            ("-3",  0.57),
            ("-2",  0.65),
            ("-1",  0.73),
            ("0",   0.81),   // target zone midpoint — equivalent to ~145 BPM
            ("+1",  0.88),
            ("+2",  0.94),
            ("+3",  1.00)
        ]

        let sweepRad = arcEnd - arcStart

        for point in scalePoints {
            let angle = arcStart + point.fraction * sweepRad
            let isZero = point.dbVal == "0"
            let isPositive = point.dbVal.hasPrefix("+")
            let isMajor = point.dbVal == "-20" || point.dbVal == "-10" || isZero || isPositive
            let tickLen: CGFloat = isMajor ? 14 : 8

            let outerX = cx + CGFloat(cos(angle)) * arcR
            let outerY = cy + CGFloat(sin(angle)) * arcR
            let innerX = cx + CGFloat(cos(angle)) * (arcR - tickLen)
            let innerY = cy + CGFloat(sin(angle)) * (arcR - tickLen)

            var tick = Path()
            tick.move(to: CGPoint(x: outerX, y: outerY))
            tick.addLine(to: CGPoint(x: innerX, y: innerY))

            let tickColor: Color = isPositive ? ledRed.opacity(0.7) :
                                   isZero      ? scaleInk.opacity(0.9) :
                                                 scaleInk.opacity(0.55)
            ctx.stroke(tick, with: .color(tickColor),
                       lineWidth: isMajor ? 1.5 : 0.8)

            // Labels on major ticks
            if isMajor {
                let labelR = arcR - tickLen - 12
                let labelX = cx + CGFloat(cos(angle)) * labelR
                let labelY = cy + CGFloat(sin(angle)) * labelR

                let labelColor: Color = isPositive ? ledRed.opacity(0.85) :
                                        isZero      ? scaleInk :
                                                      scaleInk.opacity(0.65)
                let fontSize: CGFloat = isZero || isPositive ? 9 : 8

                ctx.draw(
                    Text(point.dbVal)
                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(labelColor),
                    at: CGPoint(x: labelX, y: labelY),
                    anchor: .center
                )
            }
        }

        // ── Red zone arc segment (0 dB to +3 dB) ─────────────────────────
        let redStart = arcStart + 0.81 * sweepRad
        var redArc = Path()
        redArc.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: arcR + 4,
            startAngle: .radians(redStart),
            endAngle: .radians(arcEnd),
            clockwise: false
        )
        ctx.stroke(redArc, with: .color(ledRed.opacity(0.55)), lineWidth: 3)

        // ── "VU" label at the center-top of the arc face ─────────────────
        ctx.draw(
            Text("VU")
                .font(.system(size: 14, weight: .black, design: .serif))
                .foregroundStyle(scaleInk.opacity(0.6)),
            at: CGPoint(x: cx, y: cy - arcR * 0.48),
            anchor: .center
        )

        // ── BPM sub-label below "VU" ──────────────────────────────────────
        let bpm = controller.heartRateMonitor.current
        let bpmText = bpm > 0 ? "\(bpm) BPM" : "— BPM"
        ctx.draw(
            Text(bpmText)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(scaleInk.opacity(0.75)),
            at: CGPoint(x: cx, y: cy - arcR * 0.30),
            anchor: .center
        )

        // ── Pivot circle ──────────────────────────────────────────────────
        let pivotR: CGFloat = 6
        ctx.fill(
            Path { p in
                p.addEllipse(in: CGRect(x: cx - pivotR, y: cy - pivotR,
                                        width: pivotR * 2, height: pivotR * 2))
            },
            with: .color(scaleInk.opacity(0.85))
        )
        ctx.fill(
            Path { p in
                let iR: CGFloat = pivotR * 0.5
                p.addEllipse(in: CGRect(x: cx - iR, y: cy - iR,
                                        width: iR * 2, height: iR * 2))
            },
            with: .color(meterFace)
        )
    }

    // MARK: - Animated needle

    /// Builds a separate SwiftUI layer for the needle so spring animation works.
    @ViewBuilder
    private func needleView(in size: CGSize) -> some View {
        let cx = size.width / 2
        let cy = size.height * 0.82
        let arcR: CGFloat = min(size.width * 0.82, cy * 1.1)
        let needleLen = arcR * 0.92

        // Convert needleAngleDeg (−45…+45) to the arc geometry.
        // Arc center is at 270° (12 o'clock from the pivot at the bottom), so
        // the 0° dB point maps to 270°. We offset by 270° then add our angle.
        let angleRad = (270.0 + needleAngleDeg) * .pi / 180.0

        let tipX  = cx + CGFloat(cos(angleRad)) * needleLen
        let tipY  = cy + CGFloat(sin(angleRad)) * needleLen
        // Small counterbalance tail
        let tailX = cx - CGFloat(cos(angleRad)) * needleLen * 0.10
        let tailY = cy - CGFloat(sin(angleRad)) * needleLen * 0.10

        Canvas { ctx, _ in
            // Needle shadow
            ctx.drawLayer { inner in
                inner.opacity = 0.30
                var shadow = Path()
                shadow.move(to: CGPoint(x: tailX + 2, y: tailY + 2))
                shadow.addLine(to: CGPoint(x: tipX + 2, y: tipY + 2))
                inner.stroke(shadow, with: .color(.black), lineWidth: 1.5)
            }
            // Needle body
            var needle = Path()
            needle.move(to: CGPoint(x: tailX, y: tailY))
            needle.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.stroke(needle, with: .color(needleBlack), lineWidth: 1.8)
            // Tip triangle (small arrowhead pointing toward the scale)
            let tipAngle = angleRad
            let sideAngle1 = tipAngle + .pi / 2
            let sideAngle2 = tipAngle - .pi / 2
            let arrowLen: CGFloat = 5
            var arrow = Path()
            arrow.move(to: CGPoint(x: tipX, y: tipY))
            arrow.addLine(to: CGPoint(x: tipX - CGFloat(cos(sideAngle1)) * arrowLen * 0.4,
                                      y: tipY - CGFloat(sin(sideAngle1)) * arrowLen * 0.4))
            arrow.addLine(to: CGPoint(x: tipX - CGFloat(cos(tipAngle)) * arrowLen,
                                      y: tipY - CGFloat(sin(tipAngle)) * arrowLen))
            arrow.addLine(to: CGPoint(x: tipX - CGFloat(cos(sideAngle2)) * arrowLen * 0.4,
                                      y: tipY - CGFloat(sin(sideAngle2)) * arrowLen * 0.4))
            arrow.closeSubpath()
            ctx.fill(arrow, with: .color(needleBlack))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Peak-hold LED

    private var peakLEDOverlay: some View {
        VStack {
            HStack {
                Spacer()
                // LED pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(isRedZone ? ledRed : ledOff)
                        .frame(width: 8, height: 8)
                        .shadow(color: isRedZone ? ledRed.opacity(0.8) : .clear, radius: 4)
                    Text(peakHR > 0 ? "PEAK \(peakHR)" : "PEAK")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isRedZone ? ledRed : scaleInk.opacity(0.4))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(panelDark.opacity(0.65))
                )
                .overlay(
                    Capsule().stroke(isRedZone ? ledRed.opacity(0.5) : scaleInk.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 6)
                .padding(.trailing, 8)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRedZone ? "Peak heart rate \(peakHR) beats per minute, red zone" : "Peak heart rate \(peakHR)")
    }

    // MARK: - Brass screw decorations

    private var screwDecorations: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let inset: CGFloat = 10
            let screwR: CGFloat = 5

            ForEach([
                CGPoint(x: inset, y: inset),
                CGPoint(x: w - inset, y: inset),
                CGPoint(x: inset, y: h - inset),
                CGPoint(x: w - inset, y: h - inset)
            ], id: \.x) { pt in
                Canvas { ctx, _ in
                    // Screw body
                    ctx.fill(
                        Path { p in
                            p.addEllipse(in: CGRect(
                                x: pt.x - screwR, y: pt.y - screwR,
                                width: screwR * 2, height: screwR * 2))
                        },
                        with: .color(brassColor.opacity(0.75))
                    )
                    // Phillips cross slot
                    let sl: CGFloat = screwR * 0.55
                    var slotH = Path()
                    slotH.move(to: CGPoint(x: pt.x - sl, y: pt.y))
                    slotH.addLine(to: CGPoint(x: pt.x + sl, y: pt.y))
                    ctx.stroke(slotH, with: .color(brassColor.opacity(0.35)), lineWidth: 1.2)
                    var slotV = Path()
                    slotV.move(to: CGPoint(x: pt.x, y: pt.y - sl))
                    slotV.addLine(to: CGPoint(x: pt.x, y: pt.y + sl))
                    ctx.stroke(slotV, with: .color(brassColor.opacity(0.35)), lineWidth: 1.2)
                }
                .frame(width: w, height: h)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Recessed counter (elapsed / countdown / BPM)

    private var recessedCounter: some View {
        ZStack {
            // Counter bezel — dark inset rectangle with inner shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.04, green: 0.03, blue: 0.01))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(amberDim.opacity(0.4), lineWidth: 1)
                )
                // Inner shadow via gradient overlay
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .mask(RoundedRectangle(cornerRadius: 6))
                )

            VStack(spacing: 2) {
                Text(counterTimeString)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(amberGlow)
                    .shadow(color: amberGlow.opacity(0.35), radius: 4)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(counterSubLabel)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(amberDim)
                    .tracking(2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .frame(height: 62)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(counterA11yLabel)
    }

    private var counterTimeString: String {
        switch controller.mode {
        case .freeRun:
            return FormattingUtils.formatTimer(controller.elapsedTime)
        case .interval:
            let remaining = max(0, controller.intervalEngine?.currentStepTimeRemaining ?? 0)
            return FormattingUtils.formatTimer(remaining)
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle: return FormattingUtils.formatTimer(controller.elapsedTime)
            case .work: return FormattingUtils.formatTimer(controller.stationElapsedTime)
            case .rest: return FormattingUtils.formatTimer(controller.restElapsedTime)
            }
        }
    }

    private var counterSubLabel: String {
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

    private var counterA11yLabel: String {
        switch controller.mode {
        case .freeRun:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        case .interval:
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            let stepName = controller.intervalEngine?.currentStep.map { appType(for: $0.type).displayName } ?? "step"
            return "Time remaining in \(stepName): \(FormattingUtils.formatTimeAccessible(remaining))"
        case .gymRecovery:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        }
    }

    // MARK: - Secondary metric strips (Pace | Distance | Steps)

    private var secondaryMetricsStrip: some View {
        HStack(spacing: 0) {
            paceMetric
                .frame(maxWidth: .infinity)
            panelDivider
            distanceMetric
                .frame(maxWidth: .infinity)
            panelDivider
            stepsMetric
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(panelMid)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rackBorder.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(rackBorder.opacity(0.4))
            .frame(width: 1, height: 40)
    }

    private var paceMetric: some View {
        let paceStr = controller.currentPace.map { FormattingUtils.formatPace($0) } ?? "—"
        return miniMetric(
            value: paceStr,
            unit: "/KM",
            label: "PACE",
            color: amberGlow
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace \(paceStr) per kilometer")
    }

    private var distanceMetric: some View {
        let distStr = FormattingUtils.formatDistance(controller.totalDistance)
        return miniMetric(
            value: distStr,
            unit: "KM",
            label: "DIST",
            color: amberGlow
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Distance \(distStr) kilometers")
    }

    private var stepsMetric: some View {
        miniMetric(
            value: "\(controller.totalSteps)",
            unit: "STP",
            label: "STEPS",
            color: amberDim.opacity(1.0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Steps \(controller.totalSteps)")
    }

    private func miniMetric(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(rackBorder)
                .tracking(1)
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(color.opacity(0.65))
                    .padding(.bottom, 1.5)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Rack-mount controls bar

    private var rackControlsBar: some View {
        HStack(spacing: 10) {
            // Cancel
            rackButton(
                symbol: "xmark",
                a11yLabel: "Cancel workout",
                a11yHint: "Ends without saving",
                color: rackBorder,
                background: panelDark
            ) {
                showingCancelConfirmation = true
            }

            // Skip step (interval only)
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                rackButton(
                    symbol: "forward.end.fill",
                    a11yLabel: "Skip step",
                    a11yHint: "Advances to the next step",
                    color: amberGlow,
                    background: panelDark
                ) {
                    controller.skipStep()
                }
            }

            // Pause / Resume — primary wide button
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2.weight(.heavy))
                    Text(controller.isPaused ? "RESUME" : "PAUSE")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .tracking(1.5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.isPaused ? amberGlow : rackSteel)
                        // Top sheen — panel button gloss
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.14), Color.clear],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.4)
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            controller.isPaused ? amberGlow.opacity(0.6) : rackBorder.opacity(0.8),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(controller.isPaused ? panelDark : amberGlow)
                .shadow(color: controller.isPaused ? amberGlow.opacity(0.3) : .clear, radius: 6)
            }
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

            // Finish (stop/save)
            rackButton(
                symbol: "stop.fill",
                a11yLabel: "Finish workout",
                a11yHint: "Saves and ends",
                color: ledRed,
                background: panelDark
            ) {
                showingFinishConfirmation = true
            }
        }
    }

    @ViewBuilder
    private func rackButton(
        symbol: String,
        a11yLabel: String,
        a11yHint: String,
        color: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(background)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.10), Color.clear],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.35)
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.45), lineWidth: 1)
                )
                .foregroundStyle(color)
        }
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    // MARK: - Accessibility helper

    private var meterA11yLabel: String {
        let bpm = controller.heartRateMonitor.current
        let zone = bpm > 0 ? " \(hrZoneLabel(bpm))" : ""
        let bpmDesc = bpm > 0 ? "\(bpm) beats per minute\(zone)" : "no heart rate data"
        let peakDesc = peakHR > 0 ? ", peak \(peakHR) beats per minute" : ""
        return "Heart rate \(bpmDesc)\(peakDesc)"
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
            let label = "\(displayName(for: step.type).uppercased()) · \(FormattingUtils.formatTimer(remaining)) · \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
            return StepPillInfo(label: label, color: sharedStepColor(step.type))
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepPillInfo(label: "READY", color: amberDim)
            case .work:
                let label = "STATION \(controller.recoverySetNumber) · \(FormattingUtils.formatTimer(controller.stationElapsedTime))"
                return StepPillInfo(label: label, color: amberGlow)
            case .rest:
                let label = "REST · \(FormattingUtils.formatTimer(controller.restElapsedTime))"
                return StepPillInfo(label: label, color: ShuttlXColor.ctaWarning)
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
        case ..<0.60:      return "Z1"
        case 0.60..<0.70:  return "Z2"
        case 0.70..<0.80:  return "Z3"
        case 0.80..<0.90:  return "Z4"
        default:           return "Z5"
        }
    }
}

#if DEBUG
#Preview("VU Meter Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    VUMeterTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
