import SwiftUI

// MARK: - Mixtape watchOS workout hero chrome
//
// Watch-adapted Mixtape Walkman timer chrome. The iPhone variant renders a full
// blue cassette body shell with two spinning reels, a Side-A label sticker, the
// pulled-out LCD tape counter, and a six-glyph transport row (◀◀ ▶ ❚❚ ■ ▶▶).
// On the 41mm watch all of that overruns the screen and competes with the
// always-on HR row + tertiary metrics grid, so we cut the cassette body and
// keep only the *single* element that carries the metaphor at a glance: ONE
// spinning reel pinned to the left edge. The LCD digits stay rendered by the
// base TrainingView so we don't double-draw the timer text.
//
// Cut from iPhone version:
//   * Cassette body shell + Side-A sticker
//   * Second (take-up) reel — one reel alone carries the rotation cue
//   * Transport row — controls live on the dedicated controls page on watchOS
//   * Pulled-out LCD bezel — base TrainingView's monospaced timer is the LCD
//
// Kept:
//   * One Canvas-drawn reel (concentric hub + 6 radial spokes), left edge
//   * Subtle blue-plastic deck backdrop strip behind the reel (so the spokes
//     read against the screen background instead of floating in space)
//
// Rotation rules:
//   * Continuous rotation tied to `workoutManager.elapsedTime`
//   * Pauses cleanly when `workoutManager.isPaused` (no snap-back)
//   * TimelineView drives smooth interpolation between 1Hz manager ticks so
//     spokes don't visibly judder during a glance
//
// IMPORTANT: this overlay is decorative only. It uses `.allowsHitTesting(false)`
// so swipe, crown, and tap targets in TrainingView are untouched. It does not
// modify timer text, the HR row, or workout state.

struct MixtapeTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Mixtape palette (mirrors MixtapeTheme tokens)
    private var deckBody: Color { Color(red: 0.10, green: 0.19, blue: 0.38) }      // #1A3060 blue panel
    private var deckBorder: Color { Color(red: 0.29, green: 0.42, blue: 0.60) }    // #4A6A9A blue-steel
    private var reelHub: Color { Color(red: 0.05, green: 0.08, blue: 0.13) }       // dark blue hub
    private var reelTeeth: Color { Color(red: 0.42, green: 0.54, blue: 0.67) }     // muted blue spokes
    private var amber: Color { Color(red: 0.95, green: 0.65, blue: 0.10) }         // #F2A61A center dot

    /// Reel diameter — sized to fit comfortably to the left of the metrics
    /// column on a 41mm screen without crowding the HR row or step pill.
    private let reelDiameter: CGFloat = 56

    /// Continuous rotation angle driven by the workout clock.
    ///
    /// We accumulate spin from `elapsedTime` rather than wall-clock time so the
    /// reel halts immediately on pause (no awkward catch-up animation on
    /// resume) and so wrist-down -> wrist-up wakes don't snap to a phase-jumped
    /// angle.
    private var spinDegrees: Double {
        // 1 full rotation every 4 seconds at normal pace — slow enough to read
        // as "tape advancing", fast enough to look alive.
        let revPerSecond = 0.25
        return (workoutManager.elapsedTime * revPerSecond * 360.0)
            .truncatingRemainder(dividingBy: 360.0)
    }

    var body: some View {
        // The reel sits in the upper-left quadrant so the metrics VStack
        // (workout name + step pill row, then the timer hero) gets unobstructed
        // horizontal real-estate. Bottom half is left clear for HR + tertiary.
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                reelStack
                    .frame(width: reelDiameter, height: reelDiameter)
                    .padding(.leading, 2)
                    .padding(.top, 22)   // clear the step-pill row drawn by base view
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Reel composite

    private var reelStack: some View {
        ZStack {
            // Deck-plastic backdrop disc — gives the spokes something to read
            // against and hints at the cassette window from the iPhone version
            // without rebuilding the whole shell.
            Circle()
                .fill(deckBody.opacity(0.55))
                .overlay(
                    Circle()
                        .stroke(deckBorder.opacity(0.55), lineWidth: 0.6)
                )
                .blur(radius: 0.4)

            // The reel itself — rotates with workout time.
            reelCanvas
                .rotationEffect(.degrees(reduceMotion ? 0 : spinDegrees))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: workoutManager.isPaused)
        }
    }

    /// Canvas-drawn reel: outer rim, 6 radial spokes, inner hub, amber center.
    /// Driven by TimelineView so it ticks between 1Hz manager publishes — the
    /// rotation transform above provides the actual angle; TimelineView just
    /// keeps the redraw cadence smooth.
    private var reelCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: workoutManager.isPaused)) { _ in
            Canvas { gfx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerR = min(size.width, size.height) / 2 - 1
                let hubR = outerR * 0.32
                let spokeInner = hubR + 1
                let spokeOuter = outerR - 2

                // Outer rim
                let rimRect = CGRect(
                    x: center.x - outerR,
                    y: center.y - outerR,
                    width: outerR * 2,
                    height: outerR * 2
                )
                gfx.stroke(
                    Path(ellipseIn: rimRect),
                    with: .color(reelTeeth.opacity(0.85)),
                    lineWidth: 1.2
                )

                // 6 radial spokes (Walkman reel pattern)
                var spokes = Path()
                for i in 0..<6 {
                    let theta = Double(i) * .pi / 3.0
                    let p0 = CGPoint(
                        x: center.x + CGFloat(cos(theta)) * spokeInner,
                        y: center.y + CGFloat(sin(theta)) * spokeInner
                    )
                    let p1 = CGPoint(
                        x: center.x + CGFloat(cos(theta)) * spokeOuter,
                        y: center.y + CGFloat(sin(theta)) * spokeOuter
                    )
                    spokes.move(to: p0)
                    spokes.addLine(to: p1)
                }
                gfx.stroke(spokes, with: .color(reelTeeth.opacity(0.95)), lineWidth: 1.1)

                // Inner hub
                let hubRect = CGRect(
                    x: center.x - hubR,
                    y: center.y - hubR,
                    width: hubR * 2,
                    height: hubR * 2
                )
                gfx.fill(Path(ellipseIn: hubRect), with: .color(reelHub))
                gfx.stroke(Path(ellipseIn: hubRect), with: .color(reelTeeth), lineWidth: 0.6)

                // Amber center dot — the spindle hole, a tiny brand cue
                let dotR = hubR * 0.35
                let dotRect = CGRect(
                    x: center.x - dotR,
                    y: center.y - dotR,
                    width: dotR * 2,
                    height: dotR * 2
                )
                gfx.fill(Path(ellipseIn: dotRect), with: .color(amber.opacity(0.9)))
            }
        }
    }
}
