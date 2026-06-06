import SwiftUI
import ShuttlXShared

/// Mixtape-themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Mixtape theme during an
/// active iPhone workout. The composition follows the Sony Walkman cassette-deck
/// concept from `design/proposals/timer-theme-redesigns/mixtape.md`:
///
///   - Blue Walkman body shell via existing `mixtapeBackground`
///   - Translucent cassette window with twin spinning Canvas reels
///   - Green LCD-style tape counter showing elapsed / step-remaining time
///   - Cassette label sticker showing workout name + side-A distance + steps
///   - Step pill on REST steps: "WORK · TRACK N/M"
///   - VU strip row: HR bar-graph (10 segments, green → amber → red by zone)
///   - "TAPE SPEED" pace strip: needle deflects left/right of 5:00/km target
///   - Transport-button controls: REW / PLAY-PAUSE / STOP / FFWD
///   - Same controller method calls as `iPhoneWorkoutTimerView.controlsBar`
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct MixtapeTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    // Accumulated reel rotation angles — persisted in @State so a wrist-down
    // resume or pause/unpause doesn't snap the reels back to zero.
    @State private var leftReelAngle: Double = 0
    @State private var rightReelAngle: Double = 0
    @State private var lastTickDate: Date? = nil

    // Mixtape palette — hard-wired because this struct is only ever displayed
    // when `themeManager.current.id == "mixtape"`.
    private let walkyBodyBlue   = Color(red: 0.05, green: 0.08, blue: 0.13)   // #0E1420 shell
    private let panelBlue       = Color(red: 0.10, green: 0.19, blue: 0.38)   // #1A3060 panel
    private let borderBlue      = Color(red: 0.29, green: 0.42, blue: 0.60)   // #4A6A9A border
    private let lcdGreen        = Color(red: 0.22, green: 1.0,  blue: 0.08)   // #39FF14 LCD green
    private let lcdGreenDim     = Color(red: 0.11, green: 0.50, blue: 0.04)   // dimmed LCD pixel
    private let accentBlue      = Color(red: 0.29, green: 0.54, blue: 0.79)   // #4A8ACA
    private let ledRed          = Color(red: 1.0,  green: 0.20, blue: 0.20)   // #FF3333
    private let amberPause      = Color(red: 0.95, green: 0.65, blue: 0.10)   // #F2A61A cassette-amber
    private let textPrimary     = Color(red: 0.70, green: 0.82, blue: 0.93)   // #B3D1ED
    private let textSecondary   = Color(red: 0.55, green: 0.68, blue: 0.80)   // #8CADCC
    private let reelDarkRing    = Color(red: 0.06, green: 0.06, blue: 0.08)   // reel hub

    var body: some View {
        ZStack {
            // ── Walkman body background ───────────────────────────────────
            walkyBodyBlue.ignoresSafeArea()

            // Horizontal texture lines (subtle — matches mixtapeBackground)
            Canvas { ctx, size in
                drawTextureLines(ctx: ctx, size: size)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Foreground composition ─────────────────────────────────────
            VStack(spacing: 0) {
                labelStickerHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                cassetteWindow
                    .padding(.horizontal, 16)

                vuAndPaceStrips
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                transportControls
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

    // MARK: - Texture background

    private func drawTextureLines(ctx: GraphicsContext, size: CGSize) {
        let lineSpacing: CGFloat = 8
        var y: CGFloat = 0
        while y < size.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(Color.white.opacity(0.025)), lineWidth: 1)
            y += lineSpacing
        }
    }

    // MARK: - Label sticker (header)

    private var labelStickerHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.90, green: 0.85, blue: 0.68).opacity(0.12)) // cream sticker tint
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderBlue.opacity(0.5), lineWidth: 1)
                )

            HStack(spacing: 8) {
                // Red REC dot
                Circle()
                    .fill(ledRed)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(ledRed.opacity(0.4), lineWidth: 2).scaleEffect(1.6))

                Text(controller.workoutName.uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                    .foregroundStyle(controller.isPaused ? amberPause : textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer()

                // SIDE A corner with distance + step count
                VStack(alignment: .trailing, spacing: 0) {
                    Text("SIDE A · \(FormattingUtils.formatDistance(controller.totalDistance)) KM")
                        .font(.system(size: 9, design: .monospaced).weight(.heavy))
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                    Text("\(controller.totalSteps) STEPS")
                        .font(.system(size: 9, design: .monospaced).weight(.semibold))
                        .foregroundStyle(textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Cassette window

    private var cassetteWindow: some View {
        ZStack {
            // Window bezel
            RoundedRectangle(cornerRadius: 10)
                .fill(panelBlue)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderBlue, lineWidth: 1.5)
                )

            VStack(spacing: 6) {
                // Step pill (interval / gym-recovery modes)
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
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(pill.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(pill.color.opacity(0.5), lineWidth: 1)
                            )
                    )
                }

                // Reel + LCD counter row
                HStack(spacing: 0) {
                    // Left (supply) reel — shrinks as time elapses
                    reelView(isSupply: true)
                        .frame(maxWidth: .infinity)

                    // Central LCD tape counter
                    lcdCounter
                        .frame(width: 100)

                    // Right (take-up) reel — grows as time elapses
                    reelView(isSupply: false)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 130)

                // Tape-progress track beneath the reels
                tapeProgressBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            .padding(.top, 10)
        }
        .frame(height: 220)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(cassetteA11yLabel)
    }

    // MARK: - Spinning reels

    @ViewBuilder
    private func reelView(isSupply: Bool) -> some View {
        if reduceMotion {
            staticReel(isSupply: isSupply)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { tl in
                animatedReel(date: tl.date, isSupply: isSupply)
            }
        }
    }

    private func animatedReel(date: Date, isSupply: Bool) -> some View {
        let angle = reelAngle(date: date, isSupply: isSupply)
        return Canvas { ctx, size in
            drawReel(ctx: ctx, size: size, isSupply: isSupply)
        }
        .rotationEffect(.degrees(angle))
    }

    private func staticReel(isSupply: Bool) -> some View {
        Canvas { ctx, size in
            drawReel(ctx: ctx, size: size, isSupply: isSupply)
        }
    }

    /// Compute the accumulated rotation angle for a reel.
    /// The reel spins faster when the workout is active; REST steps run in reverse.
    private func reelAngle(date: Date, isSupply: Bool) -> Double {
        // Angular velocity: base 45 deg/s capped at ~120 deg/s for sprinting.
        // Supply reel rotates clockwise; take-up reel also rotates clockwise (like real tape).
        let isPausedOrRest: Bool = {
            if controller.isPaused { return true }
            if controller.mode == .interval {
                if let step = controller.intervalEngine?.currentStep {
                    let appT = appType(for: step.type)
                    return appT == .rest || appT == .cooldown
                }
            }
            return false
        }()

        let baseSpeed: Double = isPausedOrRest ? 0 : 45.0
        let paceBonus: Double = {
            guard !isPausedOrRest, let pace = controller.currentPace, pace > 0 else { return 0 }
            // pace is s/km; 180 s/km (~3:00/km sprint) → max 75 deg/s bonus
            let inverted = max(0, 600.0 - pace)
            return min(75.0, inverted * 0.125)
        }()
        let angularVelocity = baseSpeed + paceBonus

        // Supply reel spins opposite the take-up reel — matches real cassette
        // mechanics (tape unspools from supply, winds onto take-up).
        let direction: Double = isSupply ? -1.0 : 1.0

        // Accumulate angle using delta-time from the last frame
        let now = date.timeIntervalSinceReferenceDate
        return (now * angularVelocity * direction).truncatingRemainder(dividingBy: 360)
    }

    private func drawReel(ctx: GraphicsContext, size: CGSize, isSupply: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2

        // Reel visual radius shrinks (supply) or grows (take-up) based on elapsed fraction.
        // Use step progress in interval mode; for free-run use elapsed vs. nominal 60 min.
        let fraction: Double = {
            if let engine = controller.intervalEngine, let step = engine.currentStep, step.duration > 0 {
                let remaining = engine.currentStepTimeRemaining
                return 1.0 - min(1.0, remaining / step.duration)
            }
            let nominal: TimeInterval = 3600.0
            return min(1.0, controller.elapsedTime / nominal)
        }()

        let maxOuter: CGFloat = min(size.width, size.height) * 0.46
        let minOuter: CGFloat = maxOuter * 0.42

        let outerRadius: CGFloat = {
            if isSupply {
                // Supply: starts large, shrinks to min
                return maxOuter - CGFloat(fraction) * (maxOuter - minOuter)
            } else {
                // Take-up: starts small, grows to max
                return minOuter + CGFloat(fraction) * (maxOuter - minOuter)
            }
        }()

        let hubRadius  = maxOuter * 0.22
        let tapeRadius = outerRadius * 0.75   // inner tape ring

        // ── Outer tape ring ───────────────────────────────────────────────
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: cx - outerRadius, y: cy - outerRadius,
                                                 width: outerRadius * 2, height: outerRadius * 2)) },
            with: .color(Color(red: 0.20, green: 0.14, blue: 0.06).opacity(0.95)) // dark brown tape
        )
        ctx.stroke(
            Path { p in p.addEllipse(in: CGRect(x: cx - outerRadius, y: cy - outerRadius,
                                                 width: outerRadius * 2, height: outerRadius * 2)) },
            with: .color(borderBlue.opacity(0.5)), lineWidth: 1.2
        )

        // ── Transparent window ring ───────────────────────────────────────
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: cx - tapeRadius, y: cy - tapeRadius,
                                                 width: tapeRadius * 2, height: tapeRadius * 2)) },
            with: .color(panelBlue.opacity(0.90))
        )

        // ── 6 radial spokes ───────────────────────────────────────────────
        let spokeCount = 6
        for i in 0..<spokeCount {
            let angle = Double(i) * (360.0 / Double(spokeCount)) * .pi / 180.0
            let innerR = hubRadius
            let outerR = tapeRadius * 0.88
            let sx = cx + CGFloat(cos(angle)) * innerR
            let sy = cy + CGFloat(sin(angle)) * innerR
            let ex = cx + CGFloat(cos(angle)) * outerR
            let ey = cy + CGFloat(sin(angle)) * outerR
            var spoke = Path()
            spoke.move(to: CGPoint(x: sx, y: sy))
            spoke.addLine(to: CGPoint(x: ex, y: ey))
            ctx.stroke(spoke, with: .color(borderBlue.opacity(0.7)), lineWidth: 2.5)
        }

        // ── Hub circle ────────────────────────────────────────────────────
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: cx - hubRadius, y: cy - hubRadius,
                                                 width: hubRadius * 2, height: hubRadius * 2)) },
            with: .color(reelDarkRing)
        )
        ctx.stroke(
            Path { p in p.addEllipse(in: CGRect(x: cx - hubRadius, y: cy - hubRadius,
                                                 width: hubRadius * 2, height: hubRadius * 2)) },
            with: .color(borderBlue.opacity(0.8)), lineWidth: 1.5
        )

        // ── Center spindle dot ────────────────────────────────────────────
        let spindleR: CGFloat = hubRadius * 0.30
        ctx.fill(
            Path { p in p.addEllipse(in: CGRect(x: cx - spindleR, y: cy - spindleR,
                                                 width: spindleR * 2, height: spindleR * 2)) },
            with: .color(borderBlue)
        )
    }

    // MARK: - LCD tape counter

    private var lcdCounter: some View {
        VStack(spacing: 4) {
            // Four-character LCD-style counter (MMSS no colon, Walkman-style)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.02, green: 0.08, blue: 0.02)) // dark LCD bezel
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(lcdGreenDim.opacity(0.4), lineWidth: 1)
                    )

                VStack(spacing: 1) {
                    Text(lcdCounterText)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(lcdGreen)
                        .shadow(color: lcdGreen.opacity(0.5), radius: 4)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(lcdCounterSubLabel)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(lcdGreenDim)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }

            // "COUNTER" engraved label
            Text("COUNTER")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary.opacity(0.6))
                .tracking(1.5)
        }
        .accessibilityLabel(cassetteCounterA11yLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// MMSS-formatted 4-digit counter, no separator (classic Walkman style).
    private var lcdCounterText: String {
        let seconds: TimeInterval = {
            switch controller.mode {
            case .freeRun:
                return controller.elapsedTime
            case .interval:
                return max(0, controller.intervalEngine?.currentStepTimeRemaining ?? controller.elapsedTime)
            case .gymRecovery:
                switch controller.recoveryState {
                case .idle:   return controller.elapsedTime
                case .work:   return controller.stationElapsedTime
                case .rest:   return controller.restElapsedTime
                }
            }
        }()
        let total = Int(seconds)
        let mm = min(total / 60, 99)
        let ss = total % 60
        return String(format: "%02d%02d", mm, ss)
    }

    private var lcdCounterSubLabel: String {
        switch controller.mode {
        case .freeRun:
            return "ELAPSED"
        case .interval:
            if let engine = controller.intervalEngine {
                return "STEP \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
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

    private var cassetteCounterA11yLabel: String {
        switch controller.mode {
        case .freeRun:
            return "Elapsed time \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        case .interval:
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            return "Time remaining \(FormattingUtils.formatTimeAccessible(remaining))"
        case .gymRecovery:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        }
    }

    private var cassetteA11yLabel: String {
        "\(controller.workoutName). \(cassetteCounterA11yLabel)"
    }

    // MARK: - Tape progress bar (thin strip below reels)

    private var tapeProgressBar: some View {
        let progress: Double = {
            if let engine = controller.intervalEngine,
               let step = engine.currentStep, step.duration > 0 {
                let remaining = engine.currentStepTimeRemaining
                return 1.0 - (remaining / step.duration)
            }
            // Free-run / gym: use elapsed vs. a nominal 60 min
            let nominal: TimeInterval = 3600
            return min(1.0, controller.elapsedTime / nominal)
        }()

        let barColor = controller.mode == .interval
            ? (controller.intervalEngine?.currentStep.map { sharedStepColor($0.type) } ?? lcdGreen)
            : lcdGreen

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(lcdGreenDim.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(borderBlue.opacity(0.3), lineWidth: 0.5)
                    )
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, proxy.size.width * progress))
                    .shadow(color: barColor.opacity(0.5), radius: 3)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 5)
    }

    // MARK: - VU strip + pace strip

    private var vuAndPaceStrips: some View {
        VStack(spacing: 8) {
            hrVUStrip
            paceSpeedStrip
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(panelBlue.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderBlue.opacity(0.5), lineWidth: 1)
                )
        )
    }

    /// HR VU strip — 10 segment bar-graph + numeric BPM.
    private var hrVUStrip: some View {
        let bpm = controller.heartRateMonitor.current
        let activeCells = bpm > 0 ? max(0, min(10, Int(Double(bpm) / 200.0 * 10.0))) : 0
        let zoneColor: Color = bpm > 0 ? ShuttlXColor.forHRZone(bpm) : accentBlue

        return HStack(spacing: 6) {
            Text("HR")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 20, alignment: .leading)

            // 10 VU segments
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { idx in
                    let lit = idx < activeCells
                    let segColor: Color = {
                        if idx < 6 { return lcdGreen }
                        if idx < 8 { return amberPause }
                        return ledRed
                    }()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lit ? segColor : segColor.opacity(0.12))
                        .frame(height: 16)
                        .shadow(color: lit ? segColor.opacity(0.5) : .clear, radius: lit ? 2 : 0)
                        .animation(.easeInOut(duration: 0.2), value: lit)
                }
            }
            .frame(maxWidth: .infinity)

            // Numeric BPM
            HStack(alignment: .bottom, spacing: 2) {
                Text(bpm > 0 ? "\(bpm)" : "—")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(zoneColor)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(textSecondary)
                    .padding(.bottom, 1)
            }
            .frame(width: 54, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0
            ? "Heart rate \(bpm) beats per minute, zone \(hrZoneLabel(bpm))"
            : "Heart rate no data")
    }

    /// "TAPE SPEED" pace strip — needle deflects left (slow) / right (fast) of a
    /// 5:00/km (300 s/km) target center.
    private var paceSpeedStrip: some View {
        let pace = controller.currentPace
        let paceStr = pace.map { FormattingUtils.formatPace($0) } ?? "—"
        // Needle position: 0.5 = on target (300 s/km). Range 0...1 mapped from 150–600 s/km.
        let needle: Double = {
            guard let p = pace, p > 0 else { return 0.5 }
            let clamped = max(150.0, min(600.0, p))
            // Higher pace (s/km) = slower = needle left (0); lower = faster = right (1)
            return 1.0 - ((clamped - 150.0) / 450.0)
        }()

        return HStack(spacing: 6) {
            Text("SPD")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 20, alignment: .leading)

            // Needle track
            GeometryReader { proxy in
                let trackW = proxy.size.width
                let centerX = trackW * 0.5
                let needleX = trackW * needle
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(lcdGreenDim.opacity(0.25))
                        .frame(height: 6)
                        .padding(.vertical, 5)

                    // Center target tick
                    Rectangle()
                        .fill(textSecondary.opacity(0.5))
                        .frame(width: 1.5, height: 16)
                        .offset(x: centerX - 0.75)

                    // Needle
                    Rectangle()
                        .fill(accentBlue)
                        .frame(width: 3, height: 16)
                        .shadow(color: accentBlue.opacity(0.6), radius: 3)
                        .offset(x: needleX - 1.5)
                        .animation(.spring(duration: 0.8), value: needle)
                }
                .frame(height: 16)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            .frame(maxWidth: .infinity)

            // Pace value
            HStack(alignment: .bottom, spacing: 2) {
                Text(paceStr)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(accentBlue)
                    .contentTransition(.numericText())
                Text("/km")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(textSecondary)
                    .padding(.bottom, 1)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace \(paceStr) per kilometer")
    }

    // MARK: - Transport controls (REW | PLAY-PAUSE | STOP | FFWD)

    private var transportControls: some View {
        HStack(spacing: 10) {
            // REW → Cancel
            transportButton(
                symbol: "backward.end.fill",
                label: "Cancel",
                a11yHint: "Ends without saving",
                color: textSecondary,
                background: panelBlue
            ) {
                showingCancelConfirmation = true
            }

            // Skip step (interval only) — maps to FFWD
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                transportButton(
                    symbol: "forward.end.fill",
                    label: "Skip",
                    a11yHint: "Skips the current step",
                    color: accentBlue,
                    background: panelBlue
                ) {
                    controller.skipStep()
                }
            }

            // PLAY / PAUSE — wide primary
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2.weight(.heavy))
                    Text(controller.isPaused ? "PLAY" : "PAUSE")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(controller.isPaused ? amberPause : accentBlue)
                        .shadow(color: (controller.isPaused ? amberPause : accentBlue).opacity(0.5),
                                radius: 6)
                )
                .foregroundStyle(walkyBodyBlue)
            }
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")

            // STOP → Finish
            transportButton(
                symbol: "stop.fill",
                label: "Stop",
                a11yHint: "Saves and ends",
                color: .white,
                background: ledRed
            ) {
                showingFinishConfirmation = true
            }
        }
    }

    @ViewBuilder
    private func transportButton(
        symbol: String,
        label: String,
        a11yHint: String,
        color: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderBlue.opacity(0.6), lineWidth: 1)
                    )
            )
            .foregroundStyle(color)
        }
        .accessibilityLabel(label)
        .accessibilityHint(a11yHint)
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
            let label = "\(displayName(for: step.type).uppercased()) · TRACK \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
            return StepPillInfo(label: label, color: sharedStepColor(step.type))
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepPillInfo(label: "READY", color: textSecondary)
            case .work:
                return StepPillInfo(
                    label: "STATION \(controller.recoverySetNumber)",
                    color: accentBlue
                )
            case .rest:
                return StepPillInfo(label: "REST", color: amberPause)
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
#Preview("Mixtape Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    MixtapeTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
