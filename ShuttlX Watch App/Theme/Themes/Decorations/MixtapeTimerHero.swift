import SwiftUI

// MARK: - Mixtape watchOS workout hero chrome
//
// Watch-adapted Mixtape cassette timer chrome. The reel badge rides inline on the
// J-card header line beside the workout name — it does NOT pin to the screen or
// inset the metrics column (an earlier full-height overlay truncated the timer /
// HR / pace values on 41–46mm). Cassette identity is carried by this reel + the
// J-card name strip + the shell-frame screws from mixtapeBackground().
//
// The reel artwork is a REAL public-domain cassette illustration, not a
// hand-drawn vector. Source: Wikimedia Commons "Cassette tape.svg" by Paul
// Sherman (Public Domain). We extracted the left reel's toothed spindle cog,
// recolored its greys to the Mixtape navy palette (steel flange + silver cog on
// a dark navy well), masked it to a transparent circle, and embedded it as the
// `MixtapeReel` image asset (1x/2x/3x). See the asset catalog for the PNGs.
//
// Rotation rules:
//   * Continuous rotation tied to `workoutManager.elapsedTime` (monotonic, so a
//     linear per-tick animation stays smooth and never snaps backwards)
//   * Halts immediately when paused/idle (elapsedTime stops advancing) with no
//     catch-up animation on resume
//   * Respects Reduce Motion (no rotation)
//
// IMPORTANT: this badge is decorative only — `.allowsHitTesting(false)` so swipe,
// crown, and tap targets in TrainingView are untouched.

struct MixtapeReelBadge: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rendered size of the reel badge. Kept small so it rides on the J-card
    /// header line beside the workout name rather than stealing horizontal
    /// space from the timer / HR / pace rows (those stay full-width).
    var diameter: CGFloat = 30

    /// Continuous rotation angle driven by the workout clock.
    ///
    /// We accumulate spin from `elapsedTime` rather than wall-clock time so the
    /// reel halts immediately on pause (no awkward catch-up animation on resume)
    /// and so wrist-down -> wrist-up wakes don't snap to a phase-jumped angle.
    /// Left unwrapped (no modulo) so the angle increases monotonically and the
    /// per-tick linear animation never spins backwards across a 360° boundary.
    private var spinDegrees: Double {
        // ~30°/s — 1 full rotation every ~12 seconds. Slowed from the prior
        // 90°/s (P2-E): calmer for older eyes (vestibular) and lighter on the
        // watch battery while still reading as "tape advancing" (0.0833 rev/s × 360°).
        workoutManager.elapsedTime * 0.0833 * 360.0
    }

    var body: some View {
        Image("MixtapeReel")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .rotationEffect(.degrees(reduceMotion ? 0 : spinDegrees))
            // Linear, 1s — matched to the manager's ~1Hz elapsedTime publish so
            // the ~30°/tick step plays out as a continuous spin between ticks.
            .animation(reduceMotion ? nil : .linear(duration: 1.0), value: spinDegrees)
            .shadow(color: .black.opacity(0.4), radius: 1)
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
    }
}

// MARK: - Mixtape Parked Reel (static)
//
// A non-animated twin reel for the COMPLETE summary screen — "tape wound to the
// end of SIDE A". Renders the same end-state the active deck reaches at
// tapeProgress 1.0: the supply reel (left) shrunk to 0.7, the take-up reel
// (right) grown to 1.0. Drawn once with no rotation so it never animates outside
// an active workout. Static reels keep the differential-fill cue consistent
// between the active deck and the finish summary.
struct MixtapeParkedReel: View {
    var body: some View {
        HStack(spacing: 4) {
            // Supply reel: wound out (thin) at end of side A.
            reel.scaleEffect(0.7)
            // Take-up reel: wound full (fat).
            reel.scaleEffect(1.0)
        }
    }

    private var reel: some View {
        Image("MixtapeReel")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}

// MARK: - Mixtape Watch Deck (full cassette-deck timer face)
//
// The watch counterpart to the iOS `MixtapeTimerHero` full cassette deck. It
// replaces the standard stacked-metrics layout for the Mixtape theme during an
// active free-run or interval workout (gym-recovery keeps `RecoveryWorkoutView`).
//
// Composition, top → bottom, tuned to fit the ~180pt 41/42mm height budget while
// keeping HR + the hero number glanceable (the watchOS BPM-visibility rule):
//
//   1. J-card label strip — cream paper, SIDE A tag + REC dot + slanted italic
//      workout name + PAUSED chip. One line; never tilts the values below it.
//   2. Cassette window band — TWIN authentic `MixtapeReel` images spinning in
//      opposite directions, flanking a central recessed LCD tape-window that
//      holds the HERO number (interval countdown / free-run elapsed) plus a tiny
//      sublabel and a thin tape-progress bar. This is the signature cassette look.
//   3. HR row — big zone-coloured BPM + Z badge (second-tier, full width).
//   4. DIST / PACE — compact two-up.
//
// Spin is driven off `workoutManager.elapsedTime` (monotonic) so the reels halt
// the instant the tape "stops" (pause) with no catch-up animation, and respect
// Reduce Motion. The whole deck is read-only on workout state.
struct MixtapeWatchDeck: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `true` for interval mode (hero = step countdown), `false` for free-run
    /// (hero = elapsed time).
    let isInterval: Bool
    /// Physical screen height — drives the proportional type sizes.
    let screenH: CGFloat

    private let hrCalc = HeartRateZoneCalculator.fromSharedDefaults()

    // MARK: Cassette palette (mirrors the iOS hero §1 tokens)
    private let labelPaper    = Color(red: 0.929, green: 0.906, blue: 0.827) // #EDE7D3 J-card
    private let labelInk      = Color(red: 0.110, green: 0.137, blue: 0.188) // #1C2330
    private let lcdGreen      = Color(red: 0.22,  green: 1.0,   blue: 0.08)  // #39FF14
    private let lcdGreenDim   = Color(red: 0.11,  green: 0.50,  blue: 0.04)
    private let lcdWell       = Color(red: 0.02,  green: 0.08,  blue: 0.02)  // recessed LCD black
    private let amberPause    = Color(red: 0.95,  green: 0.65,  blue: 0.10)  // #F2A61A
    private let ledRed        = Color(red: 1.0,   green: 0.20,  blue: 0.20)  // #FF3333
    private let borderBlue    = Color(red: 0.29,  green: 0.42,  blue: 0.60)  // #4A6A9A
    private let textSecondary = Color(red: 0.55,  green: 0.68,  blue: 0.80)  // #8CADCC

    // MARK: Derived sizes
    private var reelSize: CGFloat   { max(26, screenH * 0.135) }
    private var heroSize: CGFloat   { max(30, screenH * 0.17) }
    private var hrSize: CGFloat     { max(30, screenH * 0.155) }
    private var labelSize: CGFloat  { max(9,  screenH * 0.052) }
    private var metricSize: CGFloat { max(15, screenH * 0.085) }

    private var isRunning: Bool { !workoutManager.isPaused }

    /// Monotonic spin — halts on pause because elapsedTime stops advancing.
    /// ~30°/s (1 rev / ~12s), slowed from 90°/s per P2-E for vestibular comfort
    /// and battery on the small watch reels.
    private var spinDegrees: Double { workoutManager.elapsedTime * 0.0833 * 360.0 }

    /// 0 at workout start → 1 at "end of side" — drives the differential reel
    /// size cue (supply shrinks, take-up grows). Free-run: nominal one-hour tape;
    /// interval: whole-workout step progress (one continuous wind, not per-step).
    private var tapeProgress: Double {
        if isInterval, let engine = workoutManager.intervalEngine, engine.totalStepsCount > 0 {
            return min(1.0, Double(engine.currentStepIndex) / Double(engine.totalStepsCount))
        }
        let nominal: TimeInterval = 3600
        return min(1.0, workoutManager.elapsedTime / nominal)
    }

    /// Supply reel (left): fat → thin as the tape unwinds (1.0 → 0.7).
    private var supplyScale: CGFloat { 1.0 - 0.3 * CGFloat(tapeProgress) }
    /// Take-up reel (right): thin → fat as the tape winds on (0.7 → 1.0).
    private var takeUpScale: CGFloat { 0.7 + 0.3 * CGFloat(tapeProgress) }

    var body: some View {
        VStack(spacing: 3) {
            jCardStrip
            cassetteWindowBand
            hrRow
            metricsRow
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ShuttlXSpacing.xs)
        .padding(.top, 22)   // clears the 2 top corner screws drawn by the shell scene
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: J-card label strip

    private var jCardStrip: some View {
        HStack(spacing: 4) {
            Text("SIDE A")
                .font(.system(size: labelSize - 1, weight: .heavy, design: .monospaced))
                .foregroundStyle(labelInk)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .overlay(RoundedRectangle(cornerRadius: 2)
                    .stroke(labelInk.opacity(0.5), lineWidth: 1))

            Circle()
                .fill(workoutManager.isPaused ? amberPause : ledRed)
                .frame(width: 5, height: 5)

            Text(workoutManager.workoutName.uppercased())
                .font(.system(size: labelSize + 1, weight: .heavy, design: .monospaced))
                .italic()
                .foregroundStyle(workoutManager.isPaused ? amberPause : labelInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .rotationEffect(.degrees(-3))

            Spacer(minLength: 0)

            if workoutManager.isPaused {
                // Solid amber chip with dark ink (P1-C): the prior stroke-only
                // outline was ~1.5:1 on cream; solid fill + labelInk ≈ 6:1.
                Text("PAUSED")
                    .font(.system(size: labelSize - 1, weight: .heavy, design: .monospaced))
                    .foregroundStyle(labelInk)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3)
                        .fill(amberPause))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(labelPaper.opacity(0.92))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workoutManager.isPaused
            ? "\(workoutManager.workoutName), paused"
            : workoutManager.workoutName)
    }

    // MARK: Cassette window band — twin reels + central LCD tape-window

    private var cassetteWindowBand: some View {
        HStack(spacing: 4) {
            // Supply reel (left): unwinds, shrinks over the workout.
            reel(direction: -1, scale: supplyScale)
                .frame(width: reelSize, height: reelSize)
            lcdWindow
                .frame(maxWidth: .infinity)
            // Take-up reel (right): winds on, grows over the workout.
            reel(direction: 1, scale: takeUpScale)
                .frame(width: reelSize, height: reelSize)
        }
    }

    /// Differential reel (P1-1 lite): size-only on watch — supply shrinks, take-up
    /// grows via `scale`. We deliberately skip the per-reel RPM coupling the iOS
    /// deck uses (battery + the tiny reel won't read it). The fixed slow spin
    /// (P2-E) plus the size delta is the cheap, high-impact "tape winding" cue.
    private func reel(direction: Double, scale: CGFloat) -> some View {
        Image("MixtapeReel")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .rotationEffect(.degrees(reduceMotion ? 0 : spinDegrees * direction))
            .animation(reduceMotion ? nil : .linear(duration: 1.0), value: spinDegrees)
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.6), value: scale)
            .shadow(color: .black.opacity(0.4), radius: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lcdWindow: some View {
        let heroColor = workoutManager.isPaused ? amberPause : heroTint
        return VStack(spacing: 1) {
            Text(heroText)
                .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(heroColor)
                .shadow(color: heroColor.opacity(0.5), radius: 3)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(heroSubLabel)
                .font(.system(size: labelSize - 1, weight: .heavy, design: .monospaced))
                // P2-A: full-opacity amber when paused; lcdGreen.opacity(0.8) when
                // running (lcdGreenDim on the near-black LCD well was borderline).
                .foregroundStyle(workoutManager.isPaused ? amberPause : lcdGreen.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            tapeProgressBar
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(lcdWell)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(lcdGreenDim.opacity(0.4), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroA11yLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var tapeProgressBar: some View {
        let barColor = workoutManager.isPaused ? amberPause : heroTint
        // P3-1 (lite): tint the remaining track red once the tape is nearly out.
        let trackColor = heroProgress > 0.85 ? ledRed.opacity(0.5) : lcdGreenDim.opacity(0.3)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(barColor)
                    .frame(width: max(0, proxy.size.width * heroProgress))
                    .animation(.linear(duration: 1), value: heroProgress)
            }
        }
        .frame(height: 5)   // fattened 3 → 5 for glanceability (doubles as the differential-fill confirmation)
    }

    // MARK: HR row

    private var hrRow: some View {
        let bpm = workoutManager.heartRate
        let zone = hrCalc.zone(for: Double(bpm))
        return HStack(spacing: 4) {
            Text("HR")
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
            Spacer(minLength: 0)
            Text(bpm > 0 ? "\(bpm)" : "\u{2014}")
                .font(.system(size: hrSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.forHRZone(bpm))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("BPM")
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
            if zone > 0 {
                Text("Z\(zone)")
                    .font(.system(size: max(10, labelSize), weight: .bold, design: .monospaced))
                    .foregroundStyle(ShuttlXColor.forHRZone(bpm).opacity(0.85))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(ShuttlXColor.forHRZone(bpm).opacity(0.5), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0 ? "\(bpm) beats per minute, Zone \(zone)" : "Heart rate no data")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: DIST / PACE compact two-up

    private var metricsRow: some View {
        HStack(spacing: 8) {
            compact("DIST", FormattingUtils.formatDistance(workoutManager.totalDistance))
            compact("PACE", workoutManager.currentPace.map { FormattingUtils.formatPace($0) } ?? "\u{2014}")
        }
    }

    private func compact(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: metricSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(lcdGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: Hero value plumbing

    private var heroText: String {
        if isInterval, let engine = workoutManager.intervalEngine {
            return FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining))
        }
        return FormattingUtils.formatTimer(workoutManager.elapsedTime)
    }

    private var heroSubLabel: String {
        if isInterval, let engine = workoutManager.intervalEngine, let step = engine.currentStep {
            return "\(step.type.displayName.uppercased()) \(engine.currentStepIndex + 1)/\(engine.totalStepsCount)"
        }
        return "ELAPSED"
    }

    private var heroTint: Color {
        if isInterval, let step = workoutManager.intervalEngine?.currentStep {
            return ShuttlXColor.forStepType(step.type)
        }
        return lcdGreen
    }

    private var heroProgress: Double {
        if isInterval, let engine = workoutManager.intervalEngine,
           let step = engine.currentStep, step.duration > 0 {
            return 1.0 - (engine.currentStepTimeRemaining / step.duration)
        }
        let nominal: TimeInterval = 3600
        return min(1.0, workoutManager.elapsedTime / nominal)
    }

    private var heroA11yLabel: String {
        if isInterval, let engine = workoutManager.intervalEngine {
            return "Time remaining \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), \(heroSubLabel)"
        }
        return "Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))"
    }
}
