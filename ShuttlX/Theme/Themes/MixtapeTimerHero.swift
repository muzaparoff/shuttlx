import SwiftUI
import ShuttlXShared

/// Mixtape-themed iPhone workout timer hero.
///
/// Renders the **full visible workout body** for the Mixtape theme during an
/// active iPhone workout. The composition layers ON TOP of the cassette shell
/// background drawn by `MixtapeCassetteScene` via `.mixtapeBackground()`.
///
/// The hero owns:
/// - J-card label well: workout name (italic, no rotation), SIDE A box, REC dot,
///   distance + step count, and a ruled baseline with laid-paper texture
/// - LCD tape counter (lcdGreen, shadow radius 4) — 4-digit no-colon tape-counter look
/// - Step pill (interval / gym-recovery modes)
/// - Twin spinning reels clipped into the shell's hub windows (differential
///   reel fill: supply shrinks 1.0→0.65, take-up grows 0.65→1.0; ω ∝ 1/radius)
/// - VU HR strip (28pt BPM + zone badge) + TAPE SPEED pace strip (20pt dominant numeric)
/// - Cassette transport keys via `ThemedTransportButtonStyle`
/// - State variants: IDLE / ACTIVE / PAUSED (amber + PAUSED chip) / COMPLETE
///
/// **State machine:**
/// - `isActive` (not started): reels static, PLAY key up, counter shows READY
/// - `ACTIVE`: reels spin (TimelineView 24fps), PLAY key latched down
/// - `PAUSED`: reels frozen, PLAY key pops up, amber tint, solid amber PAUSED chip
/// - `COMPLETE`: SIDE A COMPLETE label (lcdGreen), reels park at progress 1.0, FLIP hint
///
/// **Plumbing note (option B):** this hero draws its own live reels on top of
/// the resting hub windows drawn by `MixtapeCassetteScene`. No state is
/// published through `ThemeManager`.
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

    // Tape sheen horizontal offset — travels 0→1 over ~6 s while isRunning.
    // Parked at 0 when paused. Disabled under reduceDetail.
    @State private var sheenOffset: Double = 0

    // MARK: - Cassette palette (spec §1 — hard-wired, this IS the theme definition)

    private let shellBackground  = Color(red: 0.086, green: 0.118, blue: 0.161)  // shellBottom #161E29
    private let panelBlue        = Color(red: 0.10, green: 0.19, blue: 0.38)     // #1A3060 panel
    private let borderBlue       = Color(red: 0.29, green: 0.42, blue: 0.60)     // #4A6A9A border
    private let labelPaper       = Color(red: 0.929, green: 0.906, blue: 0.827)  // #EDE7D3 J-card
    private let labelInk         = Color(red: 0.110, green: 0.137, blue: 0.188)  // #1C2330 ink
    private let feltPad          = Color(red: 0.722, green: 0.271, blue: 0.227)  // #B8453A felt
    private let lcdGreen         = Color(red: 0.22,  green: 1.0,  blue: 0.08)   // #39FF14 LCD green
    private let lcdGreenDim      = Color(red: 0.11,  green: 0.50, blue: 0.04)   // dimmed LCD pixel
    private let accentBlue       = Color(red: 0.29,  green: 0.54, blue: 0.79)   // #4A8ACA
    private let ledRed           = Color(red: 1.0,   green: 0.20, blue: 0.20)   // #FF3333
    private let amberPause       = Color(red: 0.95,  green: 0.65, blue: 0.10)   // #F2A61A
    private let textPrimary      = Color(red: 0.70,  green: 0.82, blue: 0.93)   // #B3D1ED
    private let textSecondary    = Color(red: 0.55,  green: 0.68, blue: 0.80)   // #8CADCC

    // MARK: - Computed state

    private var isComplete: Bool {
        controller.intervalEngine?.isComplete == true
    }

    private var isRunning: Bool {
        !controller.isPaused && !isComplete
    }

    private var reduceDetail: Bool {
        reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Scalar 0→1 representing how far through the "side A" tape the workout is.
    /// Drives differential reel scale + RPM.
    ///
    /// Free Run:  min(1.0, elapsedTime / 3600) — one full hour = one side.
    /// Interval:  stepIndex / totalSteps — whole-workout progress (one continuous wind).
    ///            Reels do NOT reset per step; the tape winds steadily left→right.
    /// GymRecovery: falls back to free-run elapsed nominal.
    private var tapeProgress: Double {
        switch controller.mode {
        case .freeRun:
            return min(1.0, controller.elapsedTime / 3600.0)
        case .interval:
            if let engine = controller.intervalEngine, engine.totalStepsCount > 0 {
                return Double(engine.currentStepIndex) / Double(engine.totalStepsCount)
            }
            return min(1.0, controller.elapsedTime / 3600.0)
        case .gymRecovery:
            return min(1.0, controller.elapsedTime / 3600.0)
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { screen in
            ZStack {
                // The cassette scene background is drawn by mixtapeBackground().
                // This hero draws its content ON TOP of the J-card and hub windows.

                VStack(spacing: 0) {
                    // J-card label region (top section)
                    // H3: Dynamic Island safe-area — pad at least safeAreaInsets.top + 12
                    jCardLabelSection
                        .padding(.horizontal, 28)
                        .padding(.top, max(56, screen.safeAreaInsets.top + 12))
                        .padding(.bottom, 8)

                    Spacer(minLength: 0)

                    // Transport keys (bottom row)
                    transportControls
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)  // clears the bottom screws + brand strip
                }

                // ── Live reel overlay — positioned in screen coordinate space ──────
                // Using MixtapeLayoutConstants so live reels sit exactly over scene bezels.
                // This ZStack covers the full screen, allowing absolute positioning.
                reelOverlay(screenSize: screen.size)

                // ── VU + pace panel ───────────────────────────────────────────────
                // Anchored deterministically just below the reel row (reel center +
                // half a hub + 16pt breathing room) so it always tucks under the
                // cassette reels regardless of J-card height. The remaining slack
                // falls into the lower band, where the scene's tape-window strip sits.
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: screen.size.height
                               * MixtapeLayoutConstants.hubCenterYFraction
                               + MixtapeLayoutConstants.hubDiameter / 2 + 16)
                    vuAndPaceStrips
                        .padding(.horizontal, 28)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
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

    // MARK: - J-card label section

    private var jCardLabelSection: some View {
        ZStack(alignment: .topLeading) {
            // Cream paper background with inner top shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(labelPaper)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.12), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 6)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 6,
                                topTrailingRadius: 6
                            )
                        )
                }

            // P2-2: Laid-paper horizontal line texture — every 4pt, ink 2.5%
            Canvas { ctx, size in
                let lineColor = labelInk.opacity(0.025)
                var y: CGFloat = 0
                while y < size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
                    y += 4
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)

            // P2-2: Aged-paper corner crease marks (top-left + bottom-right)
            Canvas { ctx, size in
                let crease = labelInk.opacity(0.12)
                let len: CGFloat = 10
                var tl = Path()
                tl.move(to: CGPoint(x: 2, y: 2 + len))
                tl.addLine(to: CGPoint(x: 2 + len, y: 2))
                ctx.stroke(tl, with: .color(crease), lineWidth: 1)
                var br = Path()
                br.move(to: CGPoint(x: size.width - 2, y: size.height - 2 - len))
                br.addLine(to: CGPoint(x: size.width - 2 - len, y: size.height - 2))
                ctx.stroke(br, with: .color(crease), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                // Row 1: SIDE A box + REC dot + workout name + distance
                HStack(spacing: 6) {
                    // SIDE A box
                    Text(isComplete ? "SIDE B" : "SIDE A")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(labelInk)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(labelInk.opacity(0.5), lineWidth: 1)
                        )

                    // P3-B: REC dot 8pt, full-opacity ledRed when running
                    if !isComplete {
                        Circle()
                            .fill(isRunning ? ledRed : ledRed.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(isRunning ? ledRed.opacity(0.4) : .clear, lineWidth: 2)
                                    .scaleEffect(1.6)
                            )
                    }

                    // P2-G: Workout name — italic, NO rotation (long names overlap PAUSED chip)
                    // P3-C: SIDE A COMPLETE uses lcdGreen (not accentBlue)
                    if isComplete {
                        Text("SIDE A COMPLETE")
                            .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(lcdGreen)   // P3-C: lcdGreen, not accentBlue
                            .italic()
                            // No .rotationEffect — removed per P2-G
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    } else {
                        Text(controller.workoutName.uppercased())
                            .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(controller.isPaused ? amberPause : labelInk)
                            .italic()
                            // No .rotationEffect — removed per P2-G
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }

                    Spacer()

                    // P1-C: PAUSED chip — solid amber fill (#F2A61A), dark ink (~6:1 contrast)
                    if controller.isPaused && !isComplete {
                        Text("PAUSED")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(labelInk)   // dark ink on amber ≈ 6:1
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(amberPause)    // solid fill — no opacity(0.15)
                            )
                    }

                    // P2-B: Distance/steps — high contrast on cream (labelInk-based)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(FormattingUtils.formatDistance(controller.totalDistance)) KM")
                            .font(.system(size: 10, design: .monospaced).weight(.heavy))
                            .foregroundStyle(labelInk)           // ~13:1 on cream
                            .monospacedDigit()
                        Text("\(controller.totalSteps) STEPS")
                            .font(.system(size: 9, design: .monospaced).weight(.semibold))
                            .foregroundStyle(labelInk.opacity(0.75))   // ~8:1 on cream
                            .monospacedDigit()
                    }
                }

                // Baseline rule
                Rectangle()
                    .fill(labelInk.opacity(0.25))
                    .frame(height: 1)
                    .padding(.top, 4)
                    .padding(.horizontal, 2)

                // Row 2: LCD counter + step pill
                HStack(spacing: 8) {
                    lcdCounter
                        .frame(maxWidth: .infinity, alignment: .center)

                    if let pill = stepPillInfo {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(pill.color)
                                .frame(width: 5, height: 5)
                            Text(pill.label.uppercased())
                                .font(.system(size: 8, design: .monospaced).weight(.heavy))
                                .foregroundStyle(pill.color)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(pill.color.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(pill.color.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.top, 6)

                // COMPLETE hint
                if isComplete {
                    Text("▶▶ FLIP TO SIDE B?")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accentBlue.opacity(0.7))
                        .padding(.top, 4)
                }
            }
            .padding(10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(jCardA11yLabel)
    }

    private var jCardA11yLabel: String {
        let name = controller.workoutName
        if isComplete { return "\(name), side A complete" }
        if controller.isPaused { return "\(name), paused" }
        return name
    }

    // MARK: - Reel overlay (full-screen coordinate space)
    //
    // Live reels are positioned using MixtapeLayoutConstants so they sit exactly
    // over the static bezel rings drawn by MixtapeCassetteScene regardless of
    // screen width. Coordinate space: full-screen (same as the scene's GeometryReader).

    @ViewBuilder
    private func reelOverlay(screenSize: CGSize) -> some View {
        let w = screenSize.width
        let h = screenSize.height
        let d = MixtapeLayoutConstants.hubDiameter
        let lx = w * MixtapeLayoutConstants.hubCenterXFractions.0
        let rx = w * MixtapeLayoutConstants.hubCenterXFractions.1
        let cy = h * MixtapeLayoutConstants.hubCenterYFraction

        ZStack {
            // Left (supply) reel — clipped into hub window circle
            reelView(isSupply: true)
                .frame(width: d, height: d)
                .clipShape(Circle())
                .position(x: lx, y: cy)

            // Right (take-up) reel — clipped into hub window circle
            reelView(isSupply: false)
                .frame(width: d, height: d)
                .clipShape(Circle())
                .position(x: rx, y: cy)

            // Glass glare on each hub window — static diagonal specular streak.
            // Disabled under Reduce Motion / Low Power.
            if !reduceDetail {
                glassGlare(diameter: d)
                    .position(x: lx, y: cy)
                glassGlare(diameter: d)
                    .position(x: rx, y: cy)
            }

            // Tape progress track centred between the reels
            tapeProgressBar
                .frame(width: w * 0.30, height: 4)
                .position(x: w / 2, y: cy)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(cassetteA11yLabel)
    }

    /// Fixed diagonal glass glare on a hub window — sells "real polycarbonate".
    @ViewBuilder
    private func glassGlare(diameter: CGFloat) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.10), Color.clear],
            startPoint: UnitPoint(x: 0.1, y: 0.0),
            endPoint: UnitPoint(x: 0.7, y: 0.9)
        )
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .rotationEffect(.degrees(35))
        .allowsHitTesting(false)
    }

    // MARK: - Spinning reels (authentic Public-Domain cassette reel image)
    //
    // The reel artwork is the SAME real Public-Domain cassette reel used on the
    // watch (`MixtapeReel` image asset — Wikimedia "Cassette tape.svg" by Paul
    // Sherman, navy-recolored, circular-masked). It replaces the earlier
    // Canvas-drawn vector reel so both platforms show identical genuine hardware.
    //
    // Differential fill (P1-1):
    // - Supply (left):  scale = 1.0 - 0.35 * tapeProgress (fat → thin)
    // - Take-up (right): scale = 0.65 + 0.35 * tapeProgress (thin → fat)
    // - ω ∝ 1/scale so thinner reel spins faster (physics-correct), capped at 140°/s.
    //
    // Under reduceDetail: static reels at their current-progress scale (no spin).
    //
    // Window material (P2-3): clip background is faint green-tinted polycarbonate.

    @ViewBuilder
    private func reelView(isSupply: Bool) -> some View {
        // Differential scale from tapeProgress
        let scale: Double = isSupply
            ? (1.0 - 0.35 * tapeProgress)   // supply: 1.0 → 0.65 (tape leaves)
            : (0.65 + 0.35 * tapeProgress)  // take-up: 0.65 → 1.0 (tape arrives)

        ZStack {
            // Polycarbonate window tint — faint green, clear polycarbonate look (P2-3)
            Color(red: 0.05, green: 0.10, blue: 0.06).opacity(0.5)

            if reduceDetail {
                // Static at current-progress scale
                reelImage
                    .scaleEffect(scale)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isRunning)) { tl in
                    reelImage
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(reelAngle(date: tl.date, isSupply: isSupply, scale: scale)))
                }
            }
        }
    }

    private var reelImage: some View {
        Image("MixtapeReel")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .shadow(color: .black.opacity(0.4), radius: 1)
    }

    /// Compute the accumulated rotation angle for a reel.
    /// ω is scaled by 1/reelScale so smaller reels spin faster (physics-correct).
    /// Angular velocity is capped at 140°/s to prevent strobing.
    private func reelAngle(date: Date, isSupply: Bool, scale: Double) -> Double {
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
            let inverted = max(0, 600.0 - pace)
            return min(75.0, inverted * 0.125)
        }()
        // ω ∝ 1/radius (smaller reel = faster spin); cap at 140°/s
        let baseOmega = (baseSpeed + paceBonus) / max(0.1, scale)
        let angularVelocity = min(140.0, baseOmega)
        let direction: Double = isSupply ? -1.0 : 1.0
        let now = date.timeIntervalSinceReferenceDate
        return (now * angularVelocity * direction).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - LCD tape counter (4-digit, no colon — intentional tape-counter aesthetic)
    //
    // P3-4 additions: ghost "8888" dead-pixel layer + 1pt center module divider.
    // KEEP the 4-digit no-colon format — it is the tape-counter design decision.

    private var lcdCounter: some View {
        let activeColor: Color = controller.isPaused ? amberPause : lcdGreen

        return VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.02, green: 0.08, blue: 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(lcdGreenDim.opacity(0.4), lineWidth: 1)
                    )

                VStack(spacing: 1) {
                    ZStack {
                        // Ghost "8888" — dead-pixel LCD look (back layer)
                        Text("8888")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(lcdGreen.opacity(0.04))
                            .lineLimit(1)

                        // Active counter
                        Text(lcdCounterText)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(activeColor)
                            .shadow(color: activeColor.opacity(0.5), radius: 4)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        // Center module divider — 1pt vertical line between the two digit pairs.
                        // This is the physical module gap (NOT a colon).
                        Rectangle()
                            .fill(lcdGreenDim.opacity(0.20))
                            .frame(width: 1, height: 24)
                    }

                    Text(lcdCounterSubLabel)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(controller.isPaused ? amberPause.opacity(0.6) : lcdGreenDim)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }

            Text("COUNTER")
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(labelInk.opacity(0.4))
                .tracking(1.5)
        }
        .accessibilityLabel(cassetteCounterA11yLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var lcdCounterText: String {
        let seconds: TimeInterval = {
            switch controller.mode {
            case .freeRun:
                return controller.elapsedTime
            case .interval:
                return max(0, controller.intervalEngine?.currentStepTimeRemaining ?? controller.elapsedTime)
            case .gymRecovery:
                switch controller.recoveryState {
                case .idle:  return controller.elapsedTime
                case .work:  return controller.stationElapsedTime
                case .rest:  return controller.restElapsedTime
                }
            }
        }()
        let total = Int(seconds)
        let mm = min(total / 60, 99)
        let ss = total % 60
        return String(format: "%02d%02d", mm, ss)
    }

    private var lcdCounterSubLabel: String {
        if isComplete { return "COMPLETE" }
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

    // MARK: - Tape progress bar
    // P3-1: leader-tape at start (6pt pale leader at left edge) + near-done red tint.

    private var tapeProgressBar: some View {
        let progress: Double = {
            if let engine = controller.intervalEngine,
               let step = engine.currentStep, step.duration > 0 {
                let remaining = engine.currentStepTimeRemaining
                return 1.0 - (remaining / step.duration)
            }
            let nominal: TimeInterval = 3600
            return min(1.0, controller.elapsedTime / nominal)
        }()

        let barColor = controller.mode == .interval
            ? (controller.intervalEngine?.currentStep.map { sharedStepColor($0.type) } ?? lcdGreen)
            : lcdGreen

        // Near-done: tint remaining track red when >85% done
        let nearDone = progress > 0.85

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Track — with optional near-done red tint on the remaining portion
                RoundedRectangle(cornerRadius: 2)
                    .fill(nearDone ? ledRed.opacity(0.5) : lcdGreenDim.opacity(0.3))

                // Leader tape — 6pt pale leader at left edge (physical cassette leader)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6)

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, proxy.size.width * progress))
                    .shadow(color: barColor.opacity(0.5), radius: 3)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - VU strip + pace strip
    // P2-3: matte-black head-contact panel (no sheen — contrasts the glossy green window).
    // Signature #2: slow tape-sheen band travels across the panel while isRunning.

    private var vuAndPaceStrips: some View {
        VStack(spacing: 8) {
            hrVUStrip
            paceSpeedStrip
        }
        .padding(12)
        .background(
            ZStack(alignment: .leading) {
                // Matte-black head panel — flat fill, no gradient sheen (P2-3)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.04, green: 0.07, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderBlue.opacity(0.4), lineWidth: 1)
                    )

                // Tape sheen — slow horizontal band traveling left→right (~6s period).
                // Behind all numbers, low-opacity; disabled under Reduce Motion / Low Power.
                // Uses sheenOffset 0→1 animated while isRunning (parked when paused).
                if !reduceDetail {
                    GeometryReader { geo in
                        let bandW: CGFloat = geo.size.width * 0.3
                        let travel = (geo.size.width + bandW) * sheenOffset - bandW
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: bandW)
                            .offset(x: travel)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                }

                // Felt pad on leading edge
                Capsule()
                    .fill(feltPad)
                    .frame(width: 5, height: 24)
                    .padding(.leading, 4)
            }
        )
        .onAppear {
            animateSheenIfNeeded()
        }
        .onChange(of: isRunning) { _, running in
            if running {
                animateSheenIfNeeded()
            }
        }
    }

    private func animateSheenIfNeeded() {
        guard !reduceDetail, isRunning else { return }
        sheenOffset = 0
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            sheenOffset = 1
        }
    }

    /// HR VU strip — 10 segment bar-graph + 28pt zone-colored BPM + Z-badge.
    /// The numeric BPM is the primary readout; the VU bar is the preattentive indicator.
    private var hrVUStrip: some View {
        let bpm = controller.heartRateMonitor.current
        let activeCells = bpm > 0 ? max(0, min(10, Int(Double(bpm) / 200.0 * 10.0))) : 0
        let zoneColor: Color = bpm > 0 ? ShuttlXColor.forHRZone(bpm) : accentBlue
        let zoneLabel = bpm > 0 ? hrZoneLabel(bpm) : ""

        return HStack(spacing: 6) {
            Text("HR")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 20, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { idx in
                    let lit = idx < activeCells
                    // Preattentive VU bar keeps its green/amber/red segments
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

            // BPM readout block — 28pt zone-colored numeric + "bpm" label + Z-badge
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        // 28pt BPM — the primary cardiac metric
                        Text(bpm > 0 ? "\(bpm)" : "—")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(zoneColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())

                        Text("bpm")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(textSecondary)
                            .padding(.bottom, 2)
                    }

                    // Zone badge [Z3] — immediately below/right of BPM
                    if bpm > 0 {
                        Text(zoneLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(zoneColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(zoneColor, lineWidth: 1)
                            )
                    }
                }
            }
            .frame(width: 72, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0
            ? "Heart rate \(bpm) beats per minute, zone \(hrZoneLabel(bpm))"
            : "Heart rate no data")
    }

    /// "TAPE SPEED" pace strip — 20pt dominant numeric readout; needle is a thin secondary flourish.
    /// The numeric is the readout; the needle indicates relative speed decoratively.
    private var paceSpeedStrip: some View {
        let pace = controller.currentPace
        let paceStr = pace.map { FormattingUtils.formatPace($0) } ?? "—"
        let needle: Double = {
            guard let p = pace, p > 0 else { return 0.5 }
            let clamped = max(150.0, min(600.0, p))
            return 1.0 - ((clamped - 150.0) / 450.0)
        }()

        return HStack(spacing: 6) {
            Text("SPD")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 20, alignment: .leading)

            // Needle track — demoted to thin secondary flourish (2pt needle, smaller track)
            GeometryReader { proxy in
                let trackW = proxy.size.width
                let centerX = trackW * 0.5
                let needleX = trackW * needle
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lcdGreenDim.opacity(0.20))
                        .frame(height: 4)
                        .padding(.vertical, 4)
                    // Center mark
                    Rectangle()
                        .fill(textSecondary.opacity(0.35))
                        .frame(width: 1, height: 12)
                        .offset(x: centerX - 0.5)
                    // Needle — thin (2pt) flourish indicator
                    Rectangle()
                        .fill(accentBlue.opacity(0.8))
                        .frame(width: 2, height: 12)
                        .shadow(color: accentBlue.opacity(0.4), radius: 2)
                        .offset(x: needleX - 1)
                        .animation(.spring(duration: 0.8), value: needle)
                }
                .frame(height: 12)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
            .frame(maxWidth: .infinity)

            // Pace numeric — 20pt dominant readout (up from 15pt)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(paceStr)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(lcdGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("/km")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(textSecondary)
                    .padding(.bottom, 2)
            }
            .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace \(paceStr) per kilometer")
    }

    // MARK: - Transport controls (cassette transport keys via ThemedTransportButtonStyle)

    private var transportControls: some View {
        HStack(spacing: 10) {

            // ◀◀ Cancel (REW → discard without saving)
            Button {
                showingCancelConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: TransportRole.rewind.sfSymbol)
                        .font(.system(size: 18, weight: .bold))
                    Text("CANCEL")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .tracking(0.3)
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(ThemedTransportButtonStyle(role: .rewind, isLatched: false))
            .accessibilityLabel("Cancel workout")
            .accessibilityHint("Ends without saving. Rewind key.")

            // ▶▶ Skip step (interval only — FFWD)
            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                Button {
                    controller.skipStep()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TransportRole.skip.sfSymbol)
                            .font(.system(size: 18, weight: .bold))
                        Text("SKIP")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .tracking(0.3)
                    }
                    .frame(width: 56, height: 56)
                }
                .buttonStyle(ThemedTransportButtonStyle(role: .skip, isLatched: false))
                .accessibilityLabel("Skip step")
                .accessibilityHint("Skips to the next interval step. Fast-forward key.")
            }

            // ▶ PLAY / ‖ PAUSE — wide primary key; latches DOWN while tape is running
            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2.weight(.heavy))
                    Text(controller.isPaused ? "PLAY" : "PAUSE")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(
                ThemedTransportButtonStyle(
                    role: controller.isPaused ? .play : .pause,
                    // PLAY latches DOWN while the tape is running (not paused)
                    isLatched: !controller.isPaused
                )
            )
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")
            .accessibilityHint("Play key. Latches down while tape is running.")

            // ■ Stop → Finish (saves and ends)
            Button {
                showingFinishConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: TransportRole.stop.sfSymbol)
                        .font(.system(size: 18, weight: .bold))
                    Text("STOP")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .tracking(0.3)
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(ThemedTransportButtonStyle(role: .stop, isLatched: false))
            .accessibilityLabel("Finish workout")
            .accessibilityHint("Saves and ends the workout. Stop key.")
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
            let label = "\(displayName(for: step.type).uppercased()) · TRACK \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
            return StepPillInfo(label: label, color: sharedStepColor(step.type))
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle:
                return StepPillInfo(label: "READY", color: textSecondary)
            case .work:
                return StepPillInfo(label: "STATION \(controller.recoverySetNumber)", color: accentBlue)
            case .rest:
                return StepPillInfo(label: "REST", color: amberPause)
            }
        case .freeRun:
            return nil
        }
    }

    // MARK: - Helpers

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
