import SwiftUI
import WatchKit
import ShuttlXShared

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

// MARK: - Mixtape Watch Deck (full-screen LCD timer face)
//
// The watch counterpart to the iOS `MixtapeTimerHero`. It replaces the standard
// stacked-metrics layout for the Mixtape theme during an active free-run or
// interval workout (gym-recovery keeps `RecoveryWorkoutView`).
//
// Redesign (2026-06-20, user direction): the literal twin-reel chrome was cut —
// at 14–18pt it read as bicycle wheels, not a cassette, and stole vertical space
// from the timer. The Walkman identity now lives in the FULL-SCREEN green LCD
// (one big edge-to-edge display), the amber "SIDE A" tag, and the VU meter — not
// a drawn cassette. The timer is the hero and fills the screen.
//
// Composition, top → bottom:
//   1. Now-playing row — amber SIDE A capsule + ▶ phase name, all inline on one
//      line. Sits flush at the top of the content area, visually aligned with the
//      system clock. No competing with the timer for horizontal space.
//   2. Hero number — full-width elapsed or step countdown. Free-run shows total
//      minutes ("68:45" not "1:08:45") — more legible, matches how runners think.
//   3. HR line — VU bar + zone-tinted BPM + "BPM". Zone colour IS the zone cue;
//      crossing a boundary fires a directional haptic (upward only, BPM ≥ 105).
//   4. DIST / PACE — compact two-up.
//
// The whole deck is read-only on workout state.
struct MixtapeWatchDeck: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `true` for interval mode (hero = step countdown), `false` for free-run
    /// (hero = elapsed time).
    let isInterval: Bool
    /// Physical screen height — drives the proportional type sizes.
    let screenH: CGFloat

    /// Last HR zone we fired a haptic for. Drives the zone-change cue that
    /// replaces the old "Z3" badge.
    @State private var lastHapticZone: Int = 0

    private let hrCalc = HeartRateZoneCalculator.fromSharedDefaults()

    // MARK: LCD palette
    private let labelInk      = Color(red: 0.137, green: 0.125, blue: 0.102) // #23201A warm ink
    private let lcdGreen      = Color(red: 1.0,   green: 0.769, blue: 0.302) // #FFC44D amber LCD
    private let lcdGreenDim   = Color(red: 0.431, green: 0.353, blue: 0.133) // #6E5A22 dim amber
    private let lcdWell       = Color(red: 0.082, green: 0.094, blue: 0.059) // #14180F lcdSubstrate
    private let amberPause    = Color(red: 1.0,   green: 0.639, blue: 0.094) // #FFA318 ledAmber
    private let ledRed        = Color(red: 1.0,   green: 0.231, blue: 0.188) // #FF3B30
    private let textSecondary = Color(red: 0.557, green: 0.584, blue: 0.616) // #8E959D chrome-dim
    private let labelCream    = Color(red: 0.937, green: 0.906, blue: 0.824) // #EFE7D2 tape label

    // MARK: Derived sizes (proportional to physical screen height) — the timer is
    // the hero, so it gets the lion's share now that the reel band is gone.
    private var tagSize: CGFloat    { max(9,  screenH * 0.044) }  // SIDE A tag / glyph
    private var subLabel: CGFloat   { max(10, screenH * 0.050) }  // ELAPSED / WORK 2/8
    private var heroSize: CGFloat   { max(38, screenH * 0.200) }  // hero number (slightly smaller to fit 2-row header)
    private var vuHeight: CGFloat   { max(8,  screenH * 0.045) }  // VU bar height
    private var hrSize: CGFloat     { max(28, screenH * 0.160) }  // BPM number
    private var labelSize: CGFloat  { max(10, screenH * 0.052) }  // DIST/PACE/BPM labels
    private var metricSize: CGFloat { max(18, screenH * 0.100) }  // DIST/PACE values

    private var isPaused: Bool { workoutManager.isPaused }

    var body: some View {
        VStack(alignment: .leading, spacing: screenH * 0.008) {
            nowPlayingRow   // SIDE A ▶ ELAPSED — top line, aligns with system clock
            heroTimerRow    // 68:45 — full-width hero timer below
            hrLine
            twoUpMetrics
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(lcdWell.ignoresSafeArea())
        .onChange(of: workoutManager.heartRate) { _, bpm in
            handleZoneHaptic(bpm: bpm)
        }
    }

    // MARK: 1. Now-playing row — SIDE A capsule + ▶ phase name, all inline

    private var nowPlayingRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("SIDE A")
                .font(.system(size: tagSize, weight: .heavy, design: .monospaced))
                .foregroundStyle(labelInk)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(labelCream))
            Image(systemName: isPaused ? "pause.fill" : "play.fill")
                .font(.system(size: tagSize * 1.1, weight: .heavy))
                .foregroundStyle(isPaused ? amberPause : lcdGreen)
            Text(phaseName)
                .font(.system(size: subLabel, weight: .heavy, design: .monospaced))
                .foregroundStyle(isPaused ? amberPause : heroTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Side A, \(heroSubLabel), \(isPaused ? "paused" : "playing")")
    }

    // MARK: 2. Hero timer — full-width elapsed or step countdown

    private var heroTimerRow: some View {
        ZStack(alignment: .leading) {
            // Ghost dead-pixel layer — matches the iOS timer hero
            Text("88:88")
                .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .tracking(-0.5)
                .foregroundStyle(lcdGreen.opacity(0.06))
                .accessibilityHidden(true)
            Text(heroText)
                .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .tracking(-0.5)
                .foregroundStyle(isPaused ? amberPause : heroTint)
                .shadow(color: lcdGreen.opacity(isPaused ? 0 : 0.45), radius: heroSize * 0.05)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroA11yLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Phase label, Mixtape-only walk-run wording. The shared
    /// `IntervalType.displayName` stays "Work/Rest" for every other screen; here
    /// we surface the activity ("RUN"/"WALK") to match a walk-run session. Free-run
    /// has no steps, so it reads "ELAPSED".
    private var phaseName: String {
        guard isInterval, let step = workoutManager.intervalEngine?.currentStep else {
            return "ELAPSED"
        }
        switch step.type {
        case .work:     return "RUN"
        case .rest:     return "WALK"
        case .warmup:   return "WARM UP"
        case .cooldown: return "COOL DOWN"
        }
    }

    // MARK: 3. HR line — 5 LED zone dots + zone-tinted BPM + "BPM"
    //
    // Replaces the 12-segment VU bar with 5 discrete zone dots (lit count = zone
    // number). More authentic to real Walkman hardware and color-blind safe — each
    // dot uses the zone ramp color, unlit dots are outline rings.

    private var hrLine: some View {
        let bpm = workoutManager.heartRate
        let zone = hrCalc.zone(for: Double(bpm))
        let zoneColor = ShuttlXColor.forHRZone(bpm)
        let colors = ThemeManager.shared.colors
        let zoneColors = [colors.hrZone1, colors.hrZone2, colors.hrZone3,
                          colors.hrZone4, colors.hrZone5]
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { z in
                    let isLit = !isPaused && z <= zone
                    let dotColor = isLit ? zoneColors[z - 1] : Color.clear
                    let ringColor = isLit ? zoneColors[z - 1] : lcdGreenDim.opacity(0.5)
                    Circle()
                        .fill(dotColor)
                        .overlay(Circle().strokeBorder(ringColor, lineWidth: 1))
                        .frame(width: vuHeight, height: vuHeight)
                }
            }
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            .accessibilityHidden(true)
            .animation(.easeOut(duration: 0.4), value: zone)
            Text(bpm > 0 ? "\(bpm)" : "\u{2014}")
                .font(.system(size: hrSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(zoneColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            Text("BPM")
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bpm > 0 ? "\(bpm) beats per minute, Zone \(zone)" : "Heart rate, no data")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: 4. DIST / PACE — two-up side-by-side (saves vertical space on small watch)

    private var twoUpMetrics: some View {
        let distVal = FormattingUtils.formatDistance(workoutManager.totalDistance)
        let paceVal = workoutManager.currentPace.map { FormattingUtils.formatPace($0) } ?? "\u{2014}"
        return HStack(alignment: .top, spacing: 16) {
            twoUpMetric("DIST", distVal, a11y: "Distance \(distVal)")
            twoUpMetric("PACE", paceVal,
                        a11y: "Pace \(workoutManager.currentPace == nil ? "no data" : paceVal)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func twoUpMetric(_ label: String, _ value: String, a11y: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
            Text(value)
                .font(.system(size: metricSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(lcdGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(a11y)
    }

    // MARK: Zone-change haptic (replaces the "Z3" badge)
    //
    // Fires a directional Taptic pulse only when the live HR crosses a zone
    // boundary while running: up on escalation, down on de-escalation. Skipped on
    // pause and when HR is absent so we never buzz on a 0→real first reading.
    // Only buzzes on upward zone crossings while BPM ≥ 105 — no buzz when HR drops.
    private func handleZoneHaptic(bpm: Int) {
        let zone = hrCalc.zone(for: Double(bpm))
        guard zone > 0, !isPaused, bpm >= 105 else {
            lastHapticZone = zone
            return
        }
        if lastHapticZone > 0, zone > lastHapticZone {
            WKInterfaceDevice.current().play(.directionUp)
        }
        lastHapticZone = zone
    }

    // MARK: Hero value plumbing

    private var heroText: String {
        if isInterval, let engine = workoutManager.intervalEngine {
            // Step countdown: short duration, standard MM:SS with leading zero stripped
            return trimLeadingZero(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
        }
        // Free-run elapsed: total minutes "68:45" — more legible than "1:08:45"
        let total = max(0, Int(workoutManager.elapsedTime))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    /// Drops a single leading zero on the minutes field for interval countdowns only
    /// ("01:48" → "1:48"). Hour-form times ("1:02:33") are untouched.
    private func trimLeadingZero(_ s: String) -> String {
        guard s.count >= 2, s.first == "0" else { return s }
        let second = s[s.index(after: s.startIndex)]
        return second.isNumber ? String(s.dropFirst()) : s
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

    private var heroA11yLabel: String {
        if isInterval, let engine = workoutManager.intervalEngine {
            return "Time remaining \(FormattingUtils.formatTimeAccessible(engine.currentStepTimeRemaining)), \(heroSubLabel)"
        }
        return "Elapsed time \(FormattingUtils.formatTimeAccessible(workoutManager.elapsedTime))"
    }
}

