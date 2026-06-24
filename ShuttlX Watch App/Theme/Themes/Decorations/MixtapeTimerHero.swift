import SwiftUI
import WatchKit

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
//   1. Status line — phase sublabel (WORK 3/8 / ELAPSED) on the left; small amber
//      SIDE A tag + play/pause glyph on the right. Sits under the system clock.
//   2. Hero number — huge interval countdown / free-run elapsed, vertically
//      centered with flexible space above and below so it dominates.
//   3. HR line — VU bar (fills slack) + big zone-TINTED BPM number + small "BPM".
//      No zone badge: the colour IS the zone. Crossing a zone boundary fires a
//      directional haptic (up on escalation, down on de-escalation).
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
    private let labelInk      = Color(red: 0.110, green: 0.137, blue: 0.188) // #1C2330
    private let lcdGreen      = Color(red: 0.22,  green: 1.0,   blue: 0.08)  // #39FF14
    private let lcdGreenDim   = Color(red: 0.11,  green: 0.50,  blue: 0.04)
    private let lcdWell       = Color(red: 0.02,  green: 0.08,  blue: 0.02)  // LCD black-green
    private let amberPause    = Color(red: 0.95,  green: 0.65,  blue: 0.10)  // #F2A61A
    private let ledRed        = Color(red: 1.0,   green: 0.20,  blue: 0.20)  // #FF3333
    private let textSecondary = Color(red: 0.55,  green: 0.68,  blue: 0.80)  // #8CADCC
    private let lcdAmber      = Color(red: 1.0,   green: 0.690, blue: 0.180) // #FFB02E

    // MARK: Derived sizes (proportional to physical screen height) — the timer is
    // the hero, so it gets the lion's share now that the reel band is gone.
    private var tagSize: CGFloat    { max(9,  screenH * 0.044) }  // SIDE A tag / glyph
    private var subLabel: CGFloat   { max(10, screenH * 0.050) }  // ELAPSED / WORK 2/8
    private var heroSize: CGFloat   { max(40, screenH * 0.225) }  // hero number
    private var vuHeight: CGFloat   { max(8,  screenH * 0.045) }  // VU bar height
    private var hrSize: CGFloat     { max(28, screenH * 0.160) }  // BPM number
    private var labelSize: CGFloat  { max(10, screenH * 0.052) }  // DIST/PACE/BPM labels
    private var metricSize: CGFloat { max(18, screenH * 0.100) }  // DIST/PACE values

    private var isPaused: Bool { workoutManager.isPaused }

    var body: some View {
        VStack(alignment: .leading, spacing: screenH * 0.012) {
            Spacer(minLength: 0)    // push content down — more breathing room at top
            heroBlock               // SIDE A label (left) + big timer (right) on one line
            hrLine
            metricLine("DIST", FormattingUtils.formatDistance(workoutManager.totalDistance),
                       a11y: "Distance \(FormattingUtils.formatDistance(workoutManager.totalDistance))")
            metricLine("PACE", workoutManager.currentPace.map { FormattingUtils.formatPace($0) } ?? "\u{2014}",
                       a11y: "Pace \(workoutManager.currentPace == nil ? "no data" : FormattingUtils.formatPace(workoutManager.currentPace))")
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(lcdWell.ignoresSafeArea())
        .onChange(of: workoutManager.heartRate) { _, bpm in
            handleZoneHaptic(bpm: bpm)
        }
    }

    // MARK: 1+2. Hero block — SIDE A label column (left) + big timer (right), same line

    private var heroBlock: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SIDE A")
                    .font(.system(size: tagSize, weight: .heavy, design: .monospaced))
                    .foregroundStyle(labelInk)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(lcdAmber.opacity(0.88)))
                HStack(spacing: 3) {
                    Image(systemName: isPaused ? "pause.fill" : "play.fill")
                        .font(.system(size: tagSize * 1.1, weight: .heavy))
                        .foregroundStyle(isPaused ? amberPause : lcdGreen)
                    Text(phaseName)
                        .font(.system(size: subLabel, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isPaused ? amberPause : heroTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Side A, \(heroSubLabel), \(isPaused ? "paused" : "playing")")

            Spacer(minLength: 4)

            Text(heroText)
                .font(.system(size: heroSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(isPaused ? amberPause : heroTint)
                .shadow(color: lcdAmber.opacity(isPaused ? 0 : 0.55), radius: heroSize * 0.05)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(heroA11yLabel)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: 3. HR line — VU bar + zone-tinted BPM + "BPM" (all one row)

    private var hrLine: some View {
        let bpm = workoutManager.heartRate
        let zone = hrCalc.zone(for: Double(bpm))
        let zoneColor = ShuttlXColor.forHRZone(bpm)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            MixtapeVUMeter(level: vuLevel(bpm: bpm),
                           paused: isPaused,
                           reduceMotion: reduceMotion,
                           height: vuHeight,
                           litGreen: lcdGreen,
                           litAmber: lcdAmber,
                           litRed: ledRed,
                           unlit: lcdGreenDim.opacity(0.25),
                           pausedColor: amberPause)
                .frame(maxWidth: .infinity)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                .accessibilityHidden(true)
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

    // MARK: 4. DIST / PACE — one readout per line (label left, value right)

    private func metricLine(_ label: String, _ value: String, a11y: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: labelSize, weight: .bold, design: .monospaced))
                .foregroundStyle(textSecondary)
                .fixedSize()
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: metricSize, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(lcdGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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

    /// VU drive level: normalized HR fraction with a floor at 40% of max HR.
    private func vuLevel(bpm: Int) -> Double {
        guard bpm > 0 else { return 0 }
        let maxHR = hrCalc.estimatedMaxHR
        guard maxHR > 0 else { return 0 }
        let restApprox = maxHR * 0.40
        let denom = maxHR - restApprox
        guard denom > 0 else { return 0 }
        return min(1.0, max(0.0, (Double(bpm) - restApprox) / denom))
    }

    // MARK: Hero value plumbing

    private var heroText: String {
        if isInterval, let engine = workoutManager.intervalEngine {
            return trimLeadingZero(FormattingUtils.formatTimer(max(0, engine.currentStepTimeRemaining)))
        }
        return trimLeadingZero(FormattingUtils.formatTimer(workoutManager.elapsedTime))
    }

    /// Drops a single leading zero on the minutes field for the hero only
    /// ("01:48" → "1:48", "00:48" → "0:48"). Two-digit minutes ("12:30") and
    /// hour-form times ("1:02:33") are untouched. `formatTimer` itself stays
    /// `%02d`-padded for every other surface that depends on fixed width.
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

// MARK: - VU meter (§4)
//
// 12-segment horizontal peak meter mapping HR effort cold-green → hot-red.
// Lit count = round(level * 12); per-segment color by index band. Paused freezes
// the count and recolors all lit segments amber. The only data-driven motion is a
// 0.5s ease on litN changes (event-driven off HR ticks, halts when steady / paused
// / Reduce Motion). Decorative — accessibilityHidden upstream.
private struct MixtapeVUMeter: View {
    let level: Double            // 0…1 HR effort
    let paused: Bool
    let reduceMotion: Bool
    let height: CGFloat
    let litGreen: Color
    let litAmber: Color
    let litRed: Color
    let unlit: Color
    let pausedColor: Color

    private let segments = 12

    private var litN: Int { Int((level * Double(segments)).rounded()) }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 2
            let segW = max(1, (proxy.size.width - spacing * CGFloat(segments - 1)) / CGFloat(segments))
            HStack(spacing: spacing) {
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: height * 0.3)
                        .fill(color(for: i))
                        .frame(width: segW, height: height)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: litN)
    }

    private func color(for i: Int) -> Color {
        guard i < litN else { return unlit }
        if paused { return pausedColor }
        if i >= 10 { return litRed }       // peak / clip
        if i >= 7  { return litAmber }     // working
        return litGreen                    // cool
    }
}
