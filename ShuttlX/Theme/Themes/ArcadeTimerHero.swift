import SwiftUI
import ShuttlXShared

/// Arcade-themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Arcade theme during an
/// active iPhone workout. The composition follows the 1983 cabinet score-readout
/// concept from `design/proposals/timer-theme-redesigns/arcade.md`:
///
///   - Phosphor-green 7-segment digit hero drawn entirely with `Canvas` (no
///     font asset — each digit is built from 7 filled rectangles, lit/dim per
///     segment map). A faint static scanline grid overlays the digit box.
///   - Pixel-art 2-px border around the hero box and the score strip at the
///     bottom (outer black, inner phosphor green).
///   - `★ HI-SCORE ★` banner above the digit block; paused state replaces it
///     with a blinking `INSERT COIN` taunting message driven by `TimelineView`.
///   - 1UP / HI slots at the top corners (HR zone + BPM left; elapsed right).
///   - `STAGE N-M / ●●●○○` interval dot row showing step progress.
///   - Score-style metric readouts for HR / DIST / PACE / STEPS in pixel-border
///     boxes at the bottom.
///   - Chunky pixel-bordered controls bar (same actions as
///     `iPhoneWorkoutTimerView.controlsBar`).
///
/// **Read-only on workout state.** All data flows through `controller`; no
/// logic is modified here.
struct ArcadeTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false

    // Arcade palette — hard-wired because this struct is only ever displayed
    // when `themeManager.current.id == "arcade"`.
    private let phosphorGreen  = Color(red: 0.20, green: 1.00, blue: 0.08)  // #33FF14
    private let phosphorDim    = Color(red: 0.04, green: 0.20, blue: 0.01)  // unlit segment
    private let cabinetBlack   = Color(red: 0.04, green: 0.04, blue: 0.04)  // #0A0A0A
    private let cabinetPanel   = Color(red: 0.08, green: 0.08, blue: 0.08)  // #141414
    private let pixelBorder    = Color(red: 0.20, green: 1.00, blue: 0.08)  // border accent
    private let playerRed      = Color(red: 1.00, green: 0.20, blue: 0.20)  // 2P / danger
    private let coinYellow     = Color(red: 1.00, green: 0.85, blue: 0.00)  // INSERT COIN / steps
    private let cyanScore      = Color(red: 0.00, green: 0.85, blue: 1.00)  // hi-score value
    private let magentaAccent  = Color(red: 1.00, green: 0.20, blue: 0.80)  // pause/special

    // Handheld (GBC-era) skin palette — generic shapes + colour only, no trademark.
    private let bodyTop   = Color(red: 0.525, green: 0.459, blue: 0.812)  // #8675cf
    private let bodyMid   = Color(red: 0.341, green: 0.290, blue: 0.612)  // #574a9c
    private let bodyBot   = Color(red: 0.239, green: 0.196, blue: 0.459)  // #3d3275
    private let bodyEdge  = Color(red: 0.169, green: 0.137, blue: 0.337)  // #2b2356 (embossed dark)
    private let bodyHi    = Color(red: 0.702, green: 0.651, blue: 0.910)  // #b3a6e8 (embossed light)
    private let bezelGrey = Color(red: 0.137, green: 0.137, blue: 0.157)  // #23232b
    private let lcdNavy   = Color(red: 0.024, green: 0.071, blue: 0.106)  // #06121b
    private let lcdNavyLt = Color(red: 0.047, green: 0.133, blue: 0.188)  // #0c2230
    private let btnMag1   = Color(red: 1.00,  green: 0.302, blue: 0.553)  // #ff4d8d
    private let btnMag2   = Color(red: 0.757, green: 0.114, blue: 0.369)  // #c11d5e
    private let dpadLt    = Color(red: 0.263, green: 0.263, blue: 0.310)  // #43434f
    private let dpadDk    = Color(red: 0.063, green: 0.063, blue: 0.082)  // #101015

    private var bodyGradient: LinearGradient {
        LinearGradient(colors: [bodyTop, bodyMid, bodyBot],
                       startPoint: .init(x: 0.15, y: 0), endPoint: .init(x: 0.7, y: 1))
    }
    private var lcdGradient: RadialGradient {
        RadialGradient(colors: [lcdNavyLt, lcdNavy], center: .init(x: 0.32, y: 0.2),
                       startRadius: 0, endRadius: 420)
    }
    private var bezelGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.165, green: 0.165, blue: 0.196), bezelGrey,
                                Color(red: 0.086, green: 0.086, blue: 0.110)],
                       startPoint: .top, endPoint: .bottom)
    }
    private var magentaButtonGradient: RadialGradient {
        RadialGradient(colors: [btnMag1, btnMag2, Color(red: 0.478, green: 0.059, blue: 0.227)],
                       center: .init(x: 0.36, y: 0.3), startRadius: 0, endRadius: 30)
    }
    private var dpadGradient: LinearGradient {
        LinearGradient(colors: [dpadLt, Color(red: 0.149, green: 0.149, blue: 0.180), dpadDk],
                       startPoint: .top, endPoint: .bottom)
    }
    private var pillGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.227, green: 0.200, blue: 0.345),
                                Color(red: 0.141, green: 0.122, blue: 0.235)],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Translucent grape-purple handheld body (generic GBC-era shell)
            handheldBodyLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Recessed LCD "game screen" carrying all live workout data
                lcdScreenPanel
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Embossed generic wordmark under the screen (our brand, no trademark)
                wordmark
                    .padding(.top, 12)

                Spacer(minLength: 10)

                // Molded control deck — D-pad + round A/B buttons + cancel pill
                controlDeck
                    .padding(.horizontal, 18)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)
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

    // MARK: - Global scanline background

    private func drawGlobalScanlines(ctx: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 4
        var y: CGFloat = 0
        while y < size.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(Color.black.opacity(0.25)), lineWidth: 1)
            y += spacing
        }
    }

    // MARK: - Score board header (1UP | title | HI)

    private var scoreBoardHeader: some View {
        HStack(spacing: 0) {
            // 1UP corner — shows HR zone score
            upCorner

            Spacer(minLength: 0)

            // Centre workout name
            Text(controller.workoutName.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(phosphorGreen.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .tracking(2)

            Spacer(minLength: 0)

            // HI corner — shows elapsed time
            hiCorner
        }
    }

    private var upCorner: some View {
        let bpm = controller.heartRateMonitor.current
        let zoneColor: Color = bpm > 0 ? ShuttlXColor.forHRZone(bpm) : phosphorGreen
        return VStack(alignment: .leading, spacing: 0) {
            Text("1UP")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(phosphorGreen)
            Text(bpm > 0 ? "\(bpm)" : "---")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(zoneColor)
                .contentTransition(.numericText())
            Text(bpm > 0 ? hrZoneLabel(bpm) : "")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(zoneColor.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0 ? "Heart rate \(bpm) beats per minute, \(hrZoneLabel(bpm))" : "No heart rate data")
    }

    private var hiCorner: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("HI")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(phosphorGreen)
            Text(String(format: "%05d", controller.totalSteps))
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(phosphorGreen)
                .contentTransition(.numericText())
            Text("STEPS")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(phosphorGreen.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(controller.totalSteps) steps")
    }

    // MARK: - Banner row (HI-SCORE ★ or INSERT COIN blink)

    @ViewBuilder
    private var bannerRow: some View {
        if controller.isPaused {
            // INSERT COIN blink at 0.5 Hz
            if reduceMotion {
                insertCoinText(visible: true)
            } else {
                TimelineView(.animation(minimumInterval: 1.0)) { tl in
                    let visible = Int(tl.date.timeIntervalSinceReferenceDate) % 2 == 0
                    insertCoinText(visible: visible)
                }
            }
        } else {
            hiScoreBanner
        }
    }

    private func insertCoinText(visible: Bool) -> some View {
        Text("★ INSERT COIN ★")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .tracking(3)
            .foregroundStyle(coinYellow)
            .opacity(visible ? 1.0 : 0.0)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Paused — insert coin to continue")
    }

    private var hiScoreBanner: some View {
        Text("★ HI-SCORE ★")
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(3)
            .foregroundStyle(coinYellow)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - 7-segment digit hero box

    private var digitHeroBox: some View {
        let heroString = heroTimeString
        let heroColor = heroDisplayColor

        return ZStack {
            // Outer pixel-art border + box fill
            Canvas { ctx, size in
                drawPixelBox(ctx: ctx, size: size, borderColor: heroColor)
            }

            VStack(spacing: 6) {
                // Step pill inside the box (interval only)
                if let pill = stepPillInfo {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(pill.color)
                            .frame(width: 5, height: 5)
                        Text(pill.label)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(pill.color)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pill.color.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(pill.color.opacity(0.5), lineWidth: 1)
                            )
                    )
                }

                // 7-segment canvas digits
                Canvas { ctx, size in
                    drawSevenSegmentString(
                        ctx: ctx,
                        size: size,
                        text: heroString,
                        litColor: heroColor,
                        dimColor: phosphorDim
                    )
                }
                .frame(height: 88)
                .accessibilityHidden(true)

                // Hero sub-label
                Text(heroSubLabel)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(heroColor.opacity(0.6))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .frame(height: 180)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(heroA11yLabel)
    }

    // MARK: - Interval dot row (STAGE N-M  ●●●○○)

    @ViewBuilder
    private var intervalDotsRow: some View {
        if let engine = controller.intervalEngine {
            let total = engine.totalStepsCount
            let current = engine.currentStepIndex

            HStack(spacing: 8) {
                // STAGE label
                Text("STAGE \(current + 1)-\(total)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(phosphorGreen.opacity(0.75))
                    .tracking(1)

                // Dot row — up to 12 dots visible; overflow gracefully truncated
                let visible = min(total, 12)
                HStack(spacing: 4) {
                    ForEach(0..<visible, id: \.self) { idx in
                        dotCircle(index: idx, currentIndex: current)
                    }
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Stage \(current + 1) of \(total) interval steps")
        }
    }

    @ViewBuilder
    private func dotCircle(index: Int, currentIndex: Int) -> some View {
        if index < currentIndex {
            // Completed: solid phosphor
            Circle()
                .fill(phosphorGreen.opacity(0.7))
                .frame(width: 8, height: 8)
        } else if index == currentIndex {
            // Active: blinking via TimelineView
            if reduceMotion {
                Circle()
                    .fill(phosphorGreen)
                    .frame(width: 10, height: 10)
                    .shadow(color: phosphorGreen.opacity(0.8), radius: 3)
            } else {
                TimelineView(.animation(minimumInterval: 0.5)) { tl in
                    let bright = Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                    Circle()
                        .fill(phosphorGreen.opacity(bright ? 1.0 : 0.3))
                        .frame(width: 10, height: 10)
                        .shadow(color: phosphorGreen.opacity(bright ? 0.9 : 0.0), radius: 3)
                }
            }
        } else {
            // Future: dim outline
            Circle()
                .strokeBorder(phosphorDim.opacity(0.8), lineWidth: 1)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Score metric strip (HR | DIST | PACE | STEPS)

    private var scoreMetricStrip: some View {
        HStack(spacing: 8) {
            scoreBox(label: "HR", value: hrScoreValue, color: hrScoreColor)
            scoreBox(label: "DIST", value: FormattingUtils.formatDistance(controller.totalDistance), color: phosphorGreen)
            scoreBox(label: "PACE", value: paceScoreValue, color: cyanScore)
            scoreBox(label: "SPM", value: controller.currentCadence > 0 ? "\(controller.currentCadence)" : "---", color: magentaAccent)
        }
    }

    private func scoreBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(color.opacity(0.65))
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            ZStack {
                cabinetPanel
                Canvas { ctx, size in
                    drawPixelBox(ctx: ctx, size: size, borderColor: color)
                }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Handheld body layer

    /// Translucent grape-purple shell that fills the screen behind the LCD and
    /// control deck. Gradient + a soft edge vignette read as molded plastic.
    private var handheldBodyLayer: some View {
        ZStack {
            bodyGradient
            // diagonal sheen on the upper-left
            LinearGradient(colors: [Color.white.opacity(0.14), .clear],
                           startPoint: .topLeading, endPoint: .init(x: 0.35, y: 0.4))
            // edge darkening
            RadialGradient(colors: [.clear, Color.black.opacity(0.45)],
                           center: .center, startRadius: 200, endRadius: 520)
        }
    }

    // MARK: - LCD screen panel

    /// The recessed "game screen": a grey bezel frame around navy LCD glass that
    /// carries every live metric. The existing scoreboard / 7-segment / metric
    /// views render unchanged inside it — only the surround is new.
    private var lcdScreenPanel: some View {
        VStack(spacing: 8) {
            scoreBoardHeader
            bannerRow
            digitHeroBox
            if controller.mode == .interval {
                intervalDotsRow
            }
            scoreMetricStrip
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                lcdGradient
                Canvas { ctx, size in drawGlobalScanlines(ctx: ctx, size: size) }
                    .opacity(0.7)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(cyanScore.opacity(0.25), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(8) // bezel thickness
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(bezelGradient)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.55), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 7, x: 0, y: 3)
    }

    // MARK: - Embossed wordmark

    private var wordmark: some View {
        VStack(spacing: 1) {
            Text("SHUTTLX")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(bodyEdge.opacity(0.9))
                .shadow(color: bodyHi.opacity(0.5), radius: 0, x: 0.5, y: -0.5)
            Text("INTERVAL SYSTEM")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(bodyEdge.opacity(0.7))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Control deck

    /// D-pad (left, skip) · cancel pill + speaker (center) · A/B round buttons
    /// (right: pause/resume + finish). All four real transport actions remain
    /// present and individually accessible — only the styling is the handheld
    /// deck. Functional buttons, not decoration.
    private var controlDeck: some View {
        HStack(alignment: .center, spacing: 0) {
            dPadControl
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                cancelPill
                speakerGrille
            }
            Spacer(minLength: 0)
            abButtons
        }
        .frame(height: 150)
    }

    private var dPadControl: some View {
        let skippable = controller.mode == .interval && controller.intervalEngine?.isComplete == false
        return Button {
            if skippable { controller.skipStep() }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.black.opacity(0.12)).frame(width: 116, height: 116)
                    RoundedRectangle(cornerRadius: 8).fill(dpadGradient).frame(width: 30, height: 100)
                    RoundedRectangle(cornerRadius: 8).fill(dpadGradient).frame(width: 100, height: 30)
                    Circle().fill(dpadDk)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(dpadLt.opacity(0.6), lineWidth: 1))
                }
                .frame(width: 116, height: 116)
                Text("SKIP STEP")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(bodyEdge.opacity(skippable ? 0.85 : 0.35))
            }
        }
        .buttonStyle(.plain)
        .disabled(!skippable)
        .accessibilityLabel("Skip step")
        .accessibilityHint("Advances to the next interval step")
    }

    private var abButtons: some View {
        ZStack {
            // B (lower-left) — FINISH
            roundDeckButton(
                symbol: "checkmark",
                caption: "FINISH",
                a11yLabel: "Finish workout",
                a11yHint: "Saves and ends the workout"
            ) { showingFinishConfirmation = true }
                .offset(x: -30, y: 26)

            // A (upper-right) — PAUSE / RESUME
            roundDeckButton(
                symbol: controller.isPaused ? "play.fill" : "pause.fill",
                caption: controller.isPaused ? "RESUME" : "PAUSE",
                a11yLabel: controller.isPaused ? "Resume workout" : "Pause workout",
                a11yHint: ""
            ) {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            }
                .offset(x: 22, y: -18)
        }
        .frame(width: 150, height: 140)
    }

    @ViewBuilder
    private func roundDeckButton(
        symbol: String,
        caption: String,
        a11yLabel: String,
        a11yHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle().fill(Color(red: 0.102, green: 0.078, blue: 0.188)) // socket
                        .frame(width: 56, height: 56)
                    Circle().fill(magentaButtonGradient)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Ellipse().fill(Color.white.opacity(0.35))
                                .frame(width: 18, height: 11)
                                .offset(x: -7, y: -10)
                        )
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(red: 0.227, green: 0.039, blue: 0.118))
                }
                Text(caption)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(bodyEdge.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(a11yHint)
    }

    private var cancelPill: some View {
        Button { showingCancelConfirmation = true } label: {
            Text("CANCEL")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(bodyHi.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(pillGradient)
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.4), lineWidth: 1)))
                .rotationEffect(.degrees(-12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel workout")
        .accessibilityHint("Ends the workout without saving")
    }

    /// Decorative speaker grille — diagonal molded slots, no interaction.
    private var speakerGrille: some View {
        VStack(spacing: 5) {
            ForEach(0..<4, id: \.self) { _ in
                Capsule()
                    .fill(bodyEdge.opacity(0.55))
                    .frame(width: 54, height: 4)
            }
        }
        .rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
    }

    // MARK: - Canvas: pixel-art border box

    /// Draws a 2-pixel pixel-art border: outer 1px black, inner 1px `borderColor`.
    private func drawPixelBox(ctx: GraphicsContext, size: CGSize, borderColor: Color) {
        let w = size.width
        let h = size.height

        // Fill
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .color(cabinetPanel.opacity(0.95))
        )

        // Outer black border (1px)
        ctx.stroke(
            Path(CGRect(x: 0.5, y: 0.5, width: w - 1, height: h - 1)),
            with: .color(Color.black),
            lineWidth: 1
        )

        // Inner phosphor-colour border (1px inset by 1)
        ctx.stroke(
            Path(CGRect(x: 1.5, y: 1.5, width: w - 3, height: h - 3)),
            with: .color(borderColor.opacity(0.65)),
            lineWidth: 1
        )
    }

    // MARK: - Canvas: 7-segment digit renderer

    /// Segment definitions per digit 0-9, colon, and dash.
    ///
    /// Each digit is described as a 7-bit mask over segments [a,b,c,d,e,f,g]:
    ///   a = top horizontal
    ///   b = top-right vertical
    ///   c = bottom-right vertical
    ///   d = bottom horizontal
    ///   e = bottom-left vertical
    ///   f = top-left vertical
    ///   g = middle horizontal
    private static let segmentMasks: [Character: UInt8] = [
        "0": 0b1111110,  // a b c d e f   (no g)
        "1": 0b0110000,  // b c
        "2": 0b1101101,  // a b d e g
        "3": 0b1111001,  // a b c d g
        "4": 0b0110011,  // b c f g
        "5": 0b1011011,  // a c d f g
        "6": 0b1011111,  // a c d e f g
        "7": 0b1110000,  // a b c
        "8": 0b1111111,  // a b c d e f g
        "9": 0b1111011,  // a b c d f g
        "-": 0b0000001,  // g (middle only)
        " ": 0b0000000,
    ]

    /// Draw the full `text` string as 7-segment characters inside `size`.
    private func drawSevenSegmentString(
        ctx: GraphicsContext,
        size: CGSize,
        text: String,
        litColor: Color,
        dimColor: Color
    ) {
        // Count renderable chars + colons to plan layout
        let chars = Array(text)
        let digitCount = chars.count

        guard digitCount > 0 else { return }

        // Digit geometry
        let colonWidth: CGFloat = 10
        let charGap: CGFloat = 4
        let segThick: CGFloat = 6
        let cornerCut: CGFloat = 1.5   // small bevel on segment ends

        // Compute total width for centering
        var totalWidth: CGFloat = 0
        for ch in chars {
            if ch == ":" {
                totalWidth += colonWidth + charGap
            } else {
                totalWidth += segThick * 1.4 + charGap
            }
        }
        // Single char width approximation for height-based scaling
        let singleW = segThick * 1.4
        let singleH = (singleW * 2.0) + segThick   // ~2:1 aspect

        // Scale to fit available height
        let scale = min(1.0, size.height / singleH)
        let dW = singleW * scale
        let dH = singleH * scale
        let sT = segThick * scale

        // Recompute total width with scale
        var scaledTotalWidth: CGFloat = 0
        for ch in chars {
            if ch == ":" {
                scaledTotalWidth += colonWidth * scale + charGap * scale
            } else {
                scaledTotalWidth += dW + charGap * scale
            }
        }

        var xCursor = max(0, (size.width - scaledTotalWidth) / 2)
        let yOrigin = (size.height - dH) / 2

        let cC = cornerCut * scale

        for ch in chars {
            if ch == ":" {
                // Colon: two small squares
                let cW = colonWidth * scale
                let dotSize = sT * 0.55
                let dotX = xCursor + (cW - dotSize) / 2
                ctx.fill(
                    Path(CGRect(x: dotX, y: yOrigin + dH * 0.28, width: dotSize, height: dotSize)),
                    with: .color(litColor)
                )
                ctx.fill(
                    Path(CGRect(x: dotX, y: yOrigin + dH * 0.62, width: dotSize, height: dotSize)),
                    with: .color(litColor)
                )
                xCursor += cW + charGap * scale
                continue
            }

            let mask = Self.segmentMasks[ch] ?? 0

            // Segment layout helpers (relative to xCursor, yOrigin)
            func segLit(_ bit: UInt8) -> Bool { (mask >> bit) & 1 == 1 }
            func segColor(_ bit: UInt8) -> Color { segLit(bit) ? litColor : dimColor }

            let x0 = xCursor
            let y0 = yOrigin

            // ─── Horizontal segments ───────────────────────────────────────
            // a — top
            ctx.fill(
                hSegPath(x: x0, y: y0, w: dW, t: sT, cut: cC),
                with: .color(segColor(6))
            )
            // g — middle
            ctx.fill(
                hSegPath(x: x0, y: y0 + dH / 2 - sT / 2, w: dW, t: sT, cut: cC),
                with: .color(segColor(0))
            )
            // d — bottom
            ctx.fill(
                hSegPath(x: x0, y: y0 + dH - sT, w: dW, t: sT, cut: cC),
                with: .color(segColor(3))
            )

            // ─── Vertical segments ─────────────────────────────────────────
            // f — top-left
            ctx.fill(
                vSegPath(x: x0, y: y0, h: dH / 2, t: sT, cut: cC),
                with: .color(segColor(1))
            )
            // b — top-right
            ctx.fill(
                vSegPath(x: x0 + dW - sT, y: y0, h: dH / 2, t: sT, cut: cC),
                with: .color(segColor(5))
            )
            // e — bottom-left
            ctx.fill(
                vSegPath(x: x0, y: y0 + dH / 2, h: dH / 2, t: sT, cut: cC),
                with: .color(segColor(2))
            )
            // c — bottom-right
            ctx.fill(
                vSegPath(x: x0 + dW - sT, y: y0 + dH / 2, h: dH / 2, t: sT, cut: cC),
                with: .color(segColor(4))
            )

            xCursor += dW + charGap * scale
        }
    }

    /// A horizontal segment as a beveled rectangle (hexagonal pill shape).
    private func hSegPath(x: CGFloat, y: CGFloat, w: CGFloat, t: CGFloat, cut: CGFloat) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: x + cut,     y: y))
        p.addLine(to: CGPoint(x: x + w - cut, y: y))
        p.addLine(to: CGPoint(x: x + w,       y: y + t / 2))
        p.addLine(to: CGPoint(x: x + w - cut, y: y + t))
        p.addLine(to: CGPoint(x: x + cut,     y: y + t))
        p.addLine(to: CGPoint(x: x,           y: y + t / 2))
        p.closeSubpath()
        return p
    }

    /// A vertical segment as a beveled rectangle.
    private func vSegPath(x: CGFloat, y: CGFloat, h: CGFloat, t: CGFloat, cut: CGFloat) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: x,           y: y + cut))
        p.addLine(to: CGPoint(x: x + t / 2,   y: y))
        p.addLine(to: CGPoint(x: x + t,       y: y + cut))
        p.addLine(to: CGPoint(x: x + t,       y: y + h - cut))
        p.addLine(to: CGPoint(x: x + t / 2,   y: y + h))
        p.addLine(to: CGPoint(x: x,           y: y + h - cut))
        p.closeSubpath()
        return p
    }

    // MARK: - Hero data helpers

    /// The string fed to the 7-segment renderer.
    private var heroTimeString: String {
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

    private var heroSubLabel: String {
        switch controller.mode {
        case .freeRun:
            return "ELAPSED"
        case .interval:
            if let engine = controller.intervalEngine, let step = engine.currentStep {
                return "\(displayName(for: step.type).uppercased()) REMAINING"
            }
            return "REMAINING"
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:   return "ELAPSED"
            case .work:   return "STATION \(controller.recoverySetNumber)"
            case .rest:   return "REST"
            }
        }
    }

    private var heroDisplayColor: Color {
        switch controller.mode {
        case .freeRun:
            return phosphorGreen
        case .interval:
            guard let step = controller.intervalEngine?.currentStep else { return phosphorGreen }
            return stepColor(for: step.type)
        case .gymRecovery:
            if controller.recoveryState == .rest { return coinYellow }
            return phosphorGreen
        }
    }

    private var heroA11yLabel: String {
        switch controller.mode {
        case .freeRun:
            return "Elapsed time \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        case .interval:
            let remaining = controller.intervalEngine?.currentStepTimeRemaining ?? 0
            let stepName = controller.intervalEngine?.currentStep.map { displayName(for: $0.type) } ?? "step"
            return "Time remaining in \(stepName), \(FormattingUtils.formatTimeAccessible(remaining))"
        case .gymRecovery:
            return "Elapsed \(FormattingUtils.formatTimeAccessible(controller.elapsedTime))"
        }
    }

    // MARK: - Metric score helpers

    private var hrScoreValue: String {
        let bpm = controller.heartRateMonitor.current
        return bpm > 0 ? "\(bpm)" : "---"
    }

    private var hrScoreColor: Color {
        let bpm = controller.heartRateMonitor.current
        return bpm > 0 ? ShuttlXColor.forHRZone(bpm) : phosphorGreen.opacity(0.5)
    }

    private var paceScoreValue: String {
        guard let pace = controller.currentPace else { return "--:--" }
        return FormattingUtils.formatPace(pace)
    }

    // MARK: - Step pill helper


    private var stepPillInfo: StepPillInfo? {
        switch controller.mode {
        case .interval:
            guard let engine = controller.intervalEngine,
                  let step = engine.currentStep else { return nil }
            let label = "\(displayName(for: step.type).uppercased())  \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
            return StepPillInfo(label: label, color: stepColor(for: step.type))
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepPillInfo(label: "READY", color: phosphorGreen.opacity(0.65))
            case .work:
                return StepPillInfo(
                    label: "STATION \(controller.recoverySetNumber)",
                    color: phosphorGreen
                )
            case .rest:
                return StepPillInfo(label: "REST", color: coinYellow)
            }
        case .freeRun:
            return nil
        }
    }

}

#if DEBUG
#Preview("Arcade Hero — Free Run") {
    let controller = iPhoneWorkoutController()
    ArcadeTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}

#Preview("Arcade Hero — Paused (INSERT COIN)") {
    let controller = iPhoneWorkoutController()
    // In preview, manually setting isPaused would require accessing internal state —
    // show the running state to verify the 7-segment layout.
    ArcadeTimerHero(controller: controller)
        .environment(ThemeManager.shared)
}
#endif
