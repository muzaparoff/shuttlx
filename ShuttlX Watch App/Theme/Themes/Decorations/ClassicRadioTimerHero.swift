import SwiftUI

// MARK: - Classic Radio watchOS workout hero chrome
//
// Watch-adapted Classic Radio cabinet timer chrome. The iPhone variant renders
// a full 1960s wood-cabinet radio: horizontal tuning dial (hero), brand plate
// header, three bakelite knobs (TONE / VOLUME / BAND), and station-name labels
// under the dial. On the 41mm watch all of that overruns the screen and the
// bakelite knobs in particular would be sub-30pt and unreadable.
//
// Per design/proposals/timer-theme-redesigns/classic-radio-watch.md the dial is
// *demoted* from hero to a thin "you are here" progress strip pinned to the
// top of the screen — the amber backlit numeric readout the base TrainingView
// already paints in monospaced is what the user actually reads at a glance.
//
// What we cut from the iPhone version:
//   * Three bakelite knobs (TONE / VOLUME / BAND) — would be <30pt and unreadable
//   * Brand plate header (⊙ SHUTTLX · BAND: INTERVAL)
//   * Station-name labels under the dial (WORK · REST · WORK) — step pill carries this
//   * Hero-scale tuning dial — degraded to a thin progress strip
//
// What we keep:
//   * Thin horizontal tuning dial (~6pt tall) with red sweeping needle, two
//     end ticks (00 / 30), and a thin amber centerline — pinned to the top
//   * Subtle wood-grain backdrop band behind the dial so the dial reads as
//     part of a wooden cabinet face, not a floating ruler
//
// The existing `classicRadioBackground` (full-screen wood grain + vignette) is
// painted by `.themedScreenBackground()` on the TrainingView root, so we don't
// re-paint a full-screen wood texture here — only a narrow strip behind the
// dial to give the chrome a physical anchor.
//
// IMPORTANT: this overlay is purely decorative. It uses
// `.allowsHitTesting(false)` so the crown, swipe, and tap targets in
// TrainingView are untouched. It does not modify timer text, the HR row,
// or any workout logic.

struct ClassicRadioTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Classic Radio palette (mirrors ClassicRadioTheme tokens)
    private var amber: Color { Color(red: 1.00, green: 0.72, blue: 0.30) }       // warm amber backlight
    private var amberDim: Color { Color(red: 0.78, green: 0.52, blue: 0.18) }    // dim amber tick
    private var dialRed: Color { Color(red: 0.92, green: 0.22, blue: 0.18) }     // tuning needle
    private var cabinetDark: Color { Color(red: 0.18, green: 0.10, blue: 0.06) } // dark wood
    private var cabinetMid: Color { Color(red: 0.32, green: 0.18, blue: 0.10) }  // mid wood

    /// Strip height — slim enough to leave the workout-name row + step pill the
    /// full top edge of the metrics VStack, but thick enough that the needle
    /// and end ticks read at a glance.
    private let stripHeight: CGFloat = 14

    /// Dial progress 0...1.
    ///
    /// * Interval mode: progress through the current step (decision-critical)
    /// * Free-run / gym mode: a 30-minute sweep (matches the "00...30" dial
    ///   marks the user sees) — when elapsed exceeds 30min it wraps cleanly
    ///   so the needle continues to crawl right, mirroring a long-wave radio
    ///   that you keep retuning. This keeps the needle live and meaningful
    ///   instead of pegging at one end the moment the user logs a long run.
    private var dialProgress: Double {
        if workoutManager.workoutMode == .interval,
           let engine = workoutManager.intervalEngine,
           let step = engine.currentStep,
           step.duration > 0 {
            let remaining = max(0, engine.currentStepTimeRemaining)
            let pct = 1.0 - (remaining / step.duration)
            return max(0, min(1, pct))
        }
        // 30-minute sweep, wrapping
        let cycle: TimeInterval = 30 * 60
        let phase = workoutManager.elapsedTime.truncatingRemainder(dividingBy: cycle)
        return max(0, min(1, phase / cycle))
    }

    var body: some View {
        // Top-pinned thin dial strip. Everything else (timer, HR, tertiary
        // metrics) stays painted by the base TrainingView underneath.
        VStack(spacing: 0) {
            dialStrip
                .frame(height: stripHeight)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Dial strip

    /// Thin horizontal tuning dial. A single Canvas draws:
    ///   1. Wood-grain backdrop band (a couple of horizontal grain strokes so
    ///      the strip reads as a slice of the cabinet, not a floating ruler)
    ///   2. Two end ticks at the strip extremes (the "00" and "30" anchors)
    ///   3. Several minor ticks between them for scale
    ///   4. A thin amber centerline (the dial's lit hairline)
    ///   5. A red sweeping needle at `dialProgress` X-position
    ///
    /// We use a TimelineView at ~12Hz so the needle interpolates smoothly
    /// between the manager's 1Hz elapsedTime ticks during a glance. Paused
    /// state halts the redraw to save battery — the needle simply freezes
    /// at its last position, which matches the "radio paused on a station"
    /// metaphor.
    private var dialStrip: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: workoutManager.isPaused)) { _ in
            Canvas { gfx, size in
                drawWoodBand(gfx: gfx, size: size)
                drawTicks(gfx: gfx, size: size)
                drawCenterline(gfx: gfx, size: size)
                drawNeedle(gfx: gfx, size: size, progress: dialProgress)
            }
        }
    }

    private func drawWoodBand(gfx: GraphicsContext, size: CGSize) {
        // Solid wood base — slightly darker than the screen background grain
        // so the dial reads as an inset panel.
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let gradient = Gradient(stops: [
            .init(color: cabinetDark.opacity(0.55), location: 0.0),
            .init(color: cabinetMid.opacity(0.45), location: 0.5),
            .init(color: cabinetDark.opacity(0.55), location: 1.0)
        ])
        gfx.fill(
            Path(rect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // A few horizontal grain hairlines for cabinet texture.
        var grain = Path()
        let grainCount = 3
        for i in 1...grainCount {
            let y = size.height * CGFloat(i) / CGFloat(grainCount + 1)
            grain.move(to: CGPoint(x: 0, y: y))
            grain.addLine(to: CGPoint(x: size.width, y: y))
        }
        gfx.stroke(grain, with: .color(cabinetDark.opacity(0.35)), lineWidth: 0.4)

        // Soft bottom edge so the strip casts a faint shadow onto the screen
        // underneath. Sells the "inset panel" read at near-zero cost.
        var edge = Path()
        edge.move(to: CGPoint(x: 0, y: size.height - 0.5))
        edge.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
        gfx.stroke(edge, with: .color(.black.opacity(0.35)), lineWidth: 0.5)
    }

    private func drawTicks(gfx: GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        // End ticks — taller, brighter amber. Read as the dial's "00" / "30"
        // anchors even without label text (which would be illegible at 4pt).
        var ends = Path()
        ends.move(to: CGPoint(x: 1, y: midY - 4))
        ends.addLine(to: CGPoint(x: 1, y: midY + 4))
        ends.move(to: CGPoint(x: size.width - 1, y: midY - 4))
        ends.addLine(to: CGPoint(x: size.width - 1, y: midY + 4))
        gfx.stroke(ends, with: .color(amber.opacity(0.95)), lineWidth: 1.0)

        // Minor ticks — short, dimmer. Eight intervals between the ends so the
        // needle has visible scale references as it sweeps.
        var minor = Path()
        let count = 8
        for i in 1..<count {
            let x = size.width * CGFloat(i) / CGFloat(count)
            minor.move(to: CGPoint(x: x, y: midY - 2))
            minor.addLine(to: CGPoint(x: x, y: midY + 2))
        }
        gfx.stroke(minor, with: .color(amberDim.opacity(0.75)), lineWidth: 0.5)
    }

    private func drawCenterline(gfx: GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        var line = Path()
        line.move(to: CGPoint(x: 2, y: midY))
        line.addLine(to: CGPoint(x: size.width - 2, y: midY))
        gfx.stroke(line, with: .color(amber.opacity(0.55)), lineWidth: 0.5)
    }

    private func drawNeedle(gfx: GraphicsContext, size: CGSize, progress: Double) {
        // Needle X — clamp inboard of the end ticks so it never overlaps them.
        let leftMargin: CGFloat = 2
        let rightMargin: CGFloat = 2
        let travel = max(0, size.width - leftMargin - rightMargin)
        let x = leftMargin + CGFloat(progress) * travel

        // Soft red glow halo behind the needle — sells the "warm lamp behind
        // the dial" cue the iPhone variant gets from its bigger surface.
        let haloRect = CGRect(x: x - 3, y: 0, width: 6, height: size.height)
        gfx.fill(
            Path(haloRect),
            with: .color(dialRed.opacity(0.22))
        )

        // The needle itself — full-height, 1pt red.
        var needle = Path()
        needle.move(to: CGPoint(x: x, y: 1))
        needle.addLine(to: CGPoint(x: x, y: size.height - 1))
        gfx.stroke(needle, with: .color(dialRed), lineWidth: 1.0)

        // Needle "tip" — a tiny diamond at the bottom so the needle reads as a
        // pointer, not just a vertical scratch.
        var tip = Path()
        let tipY = size.height - 1
        tip.move(to: CGPoint(x: x, y: tipY - 2))
        tip.addLine(to: CGPoint(x: x - 1.5, y: tipY))
        tip.addLine(to: CGPoint(x: x, y: tipY + 0.5))
        tip.addLine(to: CGPoint(x: x + 1.5, y: tipY))
        tip.closeSubpath()
        gfx.fill(tip, with: .color(dialRed))
    }
}
