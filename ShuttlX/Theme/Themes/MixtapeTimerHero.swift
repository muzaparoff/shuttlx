import SwiftUI
import ShuttlXShared

/// Mixtape-themed iPhone workout timer hero — Cassette Shell Simplified.
///
/// Layout (top → bottom):
/// 1. J-card strip  — compact cream header: SIDE A · workout name · PAUSED · stats
/// 2. Big LCD panel — hero timer (56pt, dark LCD glass, ghost dead-pixel layer)
/// 3. VU + HR strip — 10-segment bar + 28pt zone-colored BPM
/// 4. Pace strip    — TAPE SPEED indicator
/// 5. Decorative reels — spinning reel pair with tape progress bar
/// 6. Transport keys   — cassette transport buttons
///
/// The cassette shell scene (screws, gradient, tape window, brand strip) is drawn
/// by `MixtapeCassetteScene` via `timerScreenBackground()`. The hero lays its
/// content on top. Hub bezels are suppressed in the scene so the hero's own reel
/// row is the sole reel element.
struct MixtapeTimerHero: View {

    @ObservedObject var controller: iPhoneWorkoutController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingFinishConfirmation = false
    @State private var showingCancelConfirmation = false
    @State private var sheenOffset: Double = 0

    // MARK: - Cassette palette (hard-wired — this IS the Mixtape theme definition)

    private let labelPaper       = Color(red: 0.929, green: 0.906, blue: 0.827)
    private let labelInk         = Color(red: 0.110, green: 0.137, blue: 0.188)
    private let feltPad          = Color(red: 0.722, green: 0.271, blue: 0.227)
    private let lcdGreen         = Color(red: 0.22,  green: 1.0,  blue: 0.08)
    private let lcdGreenDim      = Color(red: 0.11,  green: 0.50, blue: 0.04)
    private let accentBlue       = Color(red: 0.29,  green: 0.54, blue: 0.79)
    private let borderBlue       = Color(red: 0.29,  green: 0.42, blue: 0.60)
    private let ledRed           = Color(red: 1.0,   green: 0.20, blue: 0.20)
    private let amberPause       = Color(red: 0.95,  green: 0.65, blue: 0.10)
    private let textSecondary    = Color(red: 0.55,  green: 0.68, blue: 0.80)

    // MARK: - State

    private var isComplete: Bool { controller.intervalEngine?.isComplete == true }
    private var isRunning: Bool  { !controller.isPaused && !isComplete }

    private var reduceDetail: Bool {
        reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

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
            VStack(spacing: 0) {
                jCardStrip
                    .padding(.horizontal, 20)
                    .padding(.top, max(52, screen.safeAreaInsets.top + 8))
                    .padding(.bottom, 10)

                bigLCDPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                vuAndPaceStrips
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                Spacer(minLength: 16)

                decorativeReelsRow
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                transportControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(28, screen.safeAreaInsets.bottom + 12))
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

    // MARK: - J-card strip (compact header)

    private var jCardStrip: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(labelPaper)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.12), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: 5)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6))
                }

            HStack(spacing: 6) {
                // SIDE A / SIDE B box
                Text(isComplete ? "SIDE B" : "SIDE A")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(labelInk)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(labelInk.opacity(0.5), lineWidth: 1))

                // REC dot (pulses while running)
                if !isComplete {
                    Circle()
                        .fill(isRunning ? ledRed : ledRed.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle()
                                .stroke(isRunning ? ledRed.opacity(0.4) : .clear, lineWidth: 2)
                                .scaleEffect(1.6)
                        )
                }

                // Workout name or COMPLETE
                if isComplete {
                    Text("SIDE A COMPLETE")
                        .font(.system(.caption, design: .monospaced).weight(.heavy))
                        .foregroundStyle(lcdGreen).italic()
                        .lineLimit(1).minimumScaleFactor(0.65)
                } else {
                    Text(controller.workoutName.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.heavy))
                        .foregroundStyle(controller.isPaused ? amberPause : labelInk)
                        .italic().lineLimit(1).minimumScaleFactor(0.65)
                }

                Spacer()

                // PAUSED chip
                if controller.isPaused && !isComplete {
                    Text("PAUSED")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(labelInk)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(amberPause))
                }

                // Distance + steps
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(FormattingUtils.formatDistance(controller.totalDistance)) KM")
                        .font(.system(size: 9, design: .monospaced).weight(.heavy))
                        .foregroundStyle(labelInk).monospacedDigit()
                    Text("\(controller.totalSteps) STEPS")
                        .font(.system(size: 8, design: .monospaced).weight(.semibold))
                        .foregroundStyle(labelInk.opacity(0.75)).monospacedDigit()
                }
            }
            .padding(8)
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(jCardA11yLabel)
    }

    private var jCardA11yLabel: String {
        let name = controller.workoutName
        if isComplete { return "\(name), side A complete" }
        if controller.isPaused { return "\(name), paused" }
        return name
    }

    // MARK: - Big LCD hero panel

    private var bigLCDPanel: some View {
        let activeColor: Color = controller.isPaused ? amberPause : lcdGreen

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.01, green: 0.06, blue: 0.01))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(lcdGreenDim.opacity(0.5), lineWidth: 1.5)
                )

            VStack(spacing: 8) {
                ZStack {
                    // Ghost "88:88" dead-pixel layer
                    Text("88:88")
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(lcdGreen.opacity(0.05))

                    // Active timer
                    Text(bigTimerText)
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(activeColor)
                        .shadow(color: activeColor.opacity(0.55), radius: 8)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }

                // Sublabel + step pill
                HStack(spacing: 8) {
                    Text(bigTimerSubLabel)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(controller.isPaused ? amberPause.opacity(0.6) : lcdGreenDim)
                        .tracking(1)

                    if let pill = stepPillInfo {
                        HStack(spacing: 3) {
                            Circle().fill(pill.color).frame(width: 4, height: 4)
                            Text(pill.label.uppercased())
                                .font(.system(size: 8, design: .monospaced).weight(.heavy))
                                .foregroundStyle(pill.color).monospacedDigit()
                        }
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(pill.color.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(pill.color.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .accessibilityLabel(lcdA11yLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var bigTimerText: String {
        let seconds: TimeInterval = {
            switch controller.mode {
            case .freeRun:
                return controller.elapsedTime
            case .interval:
                return max(0, controller.intervalEngine?.currentStepTimeRemaining ?? controller.elapsedTime)
            case .gymRecovery:
                switch controller.recoveryState {
                case .idle: return controller.elapsedTime
                case .work: return controller.stationElapsedTime
                case .rest: return controller.restElapsedTime
                }
            }
        }()
        let total = Int(seconds)
        return String(format: "%02d:%02d", min(total / 60, 99), total % 60)
    }

    private var bigTimerSubLabel: String {
        if isComplete { return "COMPLETE" }
        switch controller.mode {
        case .freeRun: return "ELAPSED"
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

    private var lcdA11yLabel: String {
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

    // MARK: - Tape progress bar

    private var tapeProgressBar: some View {
        let progress: Double = {
            if let engine = controller.intervalEngine,
               let step = engine.currentStep, step.duration > 0 {
                return 1.0 - (engine.currentStepTimeRemaining / step.duration)
            }
            return min(1.0, controller.elapsedTime / 3600)
        }()
        let barColor = controller.mode == .interval
            ? (controller.intervalEngine?.currentStep.map { sharedStepColor($0.type) } ?? lcdGreen)
            : lcdGreen
        let nearDone = progress > 0.85

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(nearDone ? ledRed.opacity(0.5) : lcdGreenDim.opacity(0.3))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: max(0, proxy.size.width * progress))
                    .shadow(color: barColor.opacity(0.5), radius: 3)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Decorative reel row (lower, below metrics)

    private let reelSize: CGFloat = 84

    private var decorativeReelsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                reelDecorative(isSupply: true)
                VStack(spacing: 6) {
                    tapeProgressBar
                    if isComplete {
                        Text("▶▶ FLIP TO SIDE B?")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(accentBlue.opacity(0.7))
                    }
                }
                reelDecorative(isSupply: false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(cassetteA11yLabel)
    }

    @ViewBuilder
    private func reelDecorative(isSupply: Bool) -> some View {
        let scale: Double = isSupply
            ? (1.0 - 0.35 * tapeProgress)
            : (0.65 + 0.35 * tapeProgress)

        ZStack {
            // Polycarbonate window tint
            Color(red: 0.05, green: 0.10, blue: 0.06).opacity(0.5)

            if reduceDetail {
                reelImage.scaleEffect(scale)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isRunning)) { tl in
                    reelImage
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(reelAngle(date: tl.date, isSupply: isSupply, scale: scale)))
                }
            }

            // Diagonal glass glare
            if !reduceDetail {
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.clear],
                    startPoint: UnitPoint(x: 0.1, y: 0.0),
                    endPoint: UnitPoint(x: 0.7, y: 0.9)
                )
                .rotationEffect(.degrees(35))
            }
        }
        .frame(width: reelSize, height: reelSize)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.45), Color.white.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
        )
        .allowsHitTesting(false)
    }

    private var reelImage: some View {
        Image("MixtapeReel")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .shadow(color: .black.opacity(0.4), radius: 1)
    }

    private func reelAngle(date: Date, isSupply: Bool, scale: Double) -> Double {
        let isPausedOrRest: Bool = {
            if controller.isPaused { return true }
            if controller.mode == .interval {
                if let step = controller.intervalEngine?.currentStep {
                    return appType(for: step.type) == .rest || appType(for: step.type) == .cooldown
                }
            }
            return false
        }()
        let baseSpeed: Double = isPausedOrRest ? 0 : 45.0
        let paceBonus: Double = {
            guard !isPausedOrRest, let pace = controller.currentPace, pace > 0 else { return 0 }
            return min(75.0, max(0, 600.0 - pace) * 0.125)
        }()
        let angularVelocity = min(140.0, (baseSpeed + paceBonus) / max(0.1, scale))
        let direction: Double = isSupply ? -1.0 : 1.0
        return (date.timeIntervalSinceReferenceDate * angularVelocity * direction)
            .truncatingRemainder(dividingBy: 360)
    }

    private var cassetteA11yLabel: String { "\(controller.workoutName). \(lcdA11yLabel)" }

    // MARK: - VU + pace strip panel

    private var vuAndPaceStrips: some View {
        VStack(spacing: 8) {
            hrVUStrip
            paceSpeedStrip
        }
        .padding(12)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.04, green: 0.07, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderBlue.opacity(0.4), lineWidth: 1)
                    )

                // Slow tape-sheen band travels left→right while running
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
                                    startPoint: .leading, endPoint: .trailing
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
        .onAppear { animateSheenIfNeeded() }
        .onChange(of: isRunning) { _, running in if running { animateSheenIfNeeded() } }
    }

    private func animateSheenIfNeeded() {
        guard !reduceDetail, isRunning else { return }
        sheenOffset = 0
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            sheenOffset = 1
        }
    }

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

            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(bpm > 0 ? "\(bpm)" : "—")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(zoneColor)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        Text("bpm")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(textSecondary)
                            .padding(.bottom, 2)
                    }
                    if bpm > 0 {
                        Text(zoneLabel)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(zoneColor)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(zoneColor, lineWidth: 1))
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

    private var paceSpeedStrip: some View {
        let pace = controller.currentPace
        let paceStr = pace.map { FormattingUtils.formatPace($0) } ?? "—"
        let needle: Double = {
            guard let p = pace, p > 0 else { return 0.5 }
            return 1.0 - ((max(150.0, min(600.0, p)) - 150.0) / 450.0)
        }()

        return HStack(spacing: 6) {
            Text("SPD")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 20, alignment: .leading)

            GeometryReader { proxy in
                let trackW = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lcdGreenDim.opacity(0.20))
                        .frame(height: 4).padding(.vertical, 4)
                    Rectangle()
                        .fill(textSecondary.opacity(0.35))
                        .frame(width: 1, height: 12)
                        .offset(x: trackW * 0.5 - 0.5)
                    Rectangle()
                        .fill(accentBlue.opacity(0.8))
                        .frame(width: 2, height: 12)
                        .shadow(color: accentBlue.opacity(0.4), radius: 2)
                        .offset(x: trackW * needle - 1)
                        .animation(.spring(duration: 0.8), value: needle)
                }
                .frame(height: 12).frame(maxHeight: .infinity)
            }
            .frame(height: 12).frame(maxWidth: .infinity)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(paceStr)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit().foregroundStyle(lcdGreen)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("/km")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(textSecondary).padding(.bottom, 2)
            }
            .frame(width: 92, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace \(paceStr) per kilometer")
    }

    // MARK: - Transport controls

    private var transportControls: some View {
        HStack(spacing: 10) {
            Button {
                showingCancelConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: TransportRole.rewind.sfSymbol)
                        .font(.system(size: 18, weight: .bold))
                    Text("CANCEL")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced)).tracking(0.3)
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(ThemedTransportButtonStyle(role: .rewind, isLatched: false))
            .accessibilityLabel("Cancel workout")
            .accessibilityHint("Ends without saving. Rewind key.")

            if controller.mode == .interval, controller.intervalEngine?.isComplete == false {
                Button {
                    controller.skipStep()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: TransportRole.skip.sfSymbol)
                            .font(.system(size: 18, weight: .bold))
                        Text("SKIP")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced)).tracking(0.3)
                    }
                    .frame(width: 56, height: 56)
                }
                .buttonStyle(ThemedTransportButtonStyle(role: .skip, isLatched: false))
                .accessibilityLabel("Skip step")
                .accessibilityHint("Skips to the next interval step. Fast-forward key.")
            }

            Button {
                if controller.isPaused { controller.resume() } else { controller.pause() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: controller.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2.weight(.heavy))
                    Text(controller.isPaused ? "PLAY" : "PAUSE")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .tracking(1).lineLimit(1).minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity).frame(height: 56)
            }
            .buttonStyle(
                ThemedTransportButtonStyle(
                    role: controller.isPaused ? .play : .pause,
                    isLatched: !controller.isPaused
                )
            )
            .accessibilityLabel(controller.isPaused ? "Resume workout" : "Pause workout")
            .accessibilityHint("Play key. Latches down while tape is running.")

            Button {
                showingFinishConfirmation = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: TransportRole.stop.sfSymbol)
                        .font(.system(size: 18, weight: .bold))
                    Text("STOP")
                        .font(.system(size: 7, weight: .heavy, design: .monospaced)).tracking(0.3)
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(ThemedTransportButtonStyle(role: .stop, isLatched: false))
            .accessibilityLabel("Finish workout")
            .accessibilityHint("Saves and ends the workout. Stop key.")
        }
    }

    // MARK: - Step pill

    private struct StepPillInfo {
        let label: String
        let color: Color
    }

    private var stepPillInfo: StepPillInfo? {
        switch controller.mode {
        case .interval:
            guard let engine = controller.intervalEngine,
                  let step = engine.currentStep else { return nil }
            // Show only the type name — step count already appears in bigTimerSubLabel
            return StepPillInfo(
                label: displayName(for: step.type).uppercased(),
                color: sharedStepColor(step.type)
            )
        case .gymRecovery:
            switch controller.recoveryState {
            case .idle: return StepPillInfo(label: "READY", color: textSecondary)
            case .work: return StepPillInfo(label: "STATION \(controller.recoverySetNumber)", color: accentBlue)
            case .rest: return StepPillInfo(label: "REST", color: amberPause)
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
        case ..<0.60:       return "Z1"
        case 0.60..<0.70:  return "Z2"
        case 0.70..<0.80:  return "Z3"
        case 0.80..<0.90:  return "Z4"
        default:            return "Z5"
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
