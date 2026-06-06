import SwiftUI

// MARK: - VU Meter watchOS workout hero chrome
//
// Watch-adapted VU Meter timer chrome. The iPhone variant uses a wide
// horizontal analog VU arc spanning the screen, with a hero needle measuring
// heart rate, a secondary step-countdown needle, peak-hold LED, and side
// strips for step / distance.
//
// Per design/proposals/timer-theme-redesigns/vu-meter-watch.md the meter is
// rotated 90 degrees and pinned to the right edge as a tall, narrow vertical
// strip — exactly how real cassette decks laid out side-mounted VU strips.
// The left two-thirds of the screen remains free for the recessed elapsed-
// time counter and step pill which the base TrainingView already renders.
//
// Cut from iPhone version:
//   * Horizontal arc spanning full width — replaced by a vertical arc on right
//   * Secondary step-countdown needle — dropped (step pill carries it numerically)
//   * Side strips for step / distance — collapsed into base view's tertiary row
//   * "rec level" pace caption — dropped
//
// Kept (rotated and shrunk for the 41mm screen):
//   * Vertical VU strip with tick marks (60->200 BPM)
//   * HR-driven needle with spring ballistics (mimics 300ms VU swing)
//   * Peak-hold LED dot near the top that lights when HR enters Z4/Z5
//   * Amber illumination band behind the strip
//
// IMPORTANT: this overlay is decorative only. It uses
// `.allowsHitTesting(false)` so the crown, swipe, and tap targets in
// TrainingView are untouched. It does not modify timer text, the HR row,
// or any workout logic.

struct VUMeterTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // VU Meter palette (mirrors VUMeterTheme tokens)
    private var amber: Color { Color(red: 1.00, green: 0.72, blue: 0.18) }      // warm amber needle / glow
    private var amberDim: Color { Color(red: 0.62, green: 0.42, blue: 0.10) }   // dim amber tick
    private var panelDark: Color { Color(red: 0.10, green: 0.07, blue: 0.04) }  // recessed panel
    private var panelEdge: Color { Color(red: 0.22, green: 0.16, blue: 0.08) }  // panel rim
    private var peakRed: Color { Color(red: 0.98, green: 0.22, blue: 0.18) }    // peak-hold LED
    private var needleCore: Color { Color(red: 1.00, green: 0.92, blue: 0.62) } // bright needle tip

    /// VU strip width — narrow enough to leave the left two-thirds of the
    /// screen for the recessed counter, wide enough that the needle and tick
    /// marks read at a glance during a sweaty mid-treadmill check.
    private let stripWidth: CGFloat = 14

    /// Heart-rate range covered by the strip. Standard VU calibration:
    /// 60 BPM = bottom (resting), 200 BPM = top (max effort). Anything
    /// outside this band is clamped so the needle never pegs visually.
    private let minBPM: Double = 60
    private let maxBPM: Double = 200

    /// Normalized HR position 0...1 mapped to vertical needle position.
    /// 0 = bottom of strip (low BPM), 1 = top (high BPM).
    private var hrNormalized: Double {
        guard workoutManager.heartRate > 0 else { return 0 }
        let hr = Double(workoutManager.heartRate)
        let clamped = max(minBPM, min(maxBPM, hr))
        return (clamped - minBPM) / (maxBPM - minBPM)
    }

    /// Peak-hold LED state: lights when the current HR has entered the
    /// high-intensity band (Z4/Z5). Heuristic: HR >= 80% of (220 - 30) max,
    /// i.e. ~152 BPM for a typical adult. We use the simpler "above 152"
    /// threshold rather than a per-user calculation so the LED behaves
    /// predictably across all users. The light reads as "watch your effort"
    /// without competing with the explicit "Heart rate high" warning the
    /// base TrainingView already shows.
    private var peakLit: Bool {
        workoutManager.heartRate >= 152
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            vuStrip
                .frame(width: stripWidth)
                .frame(maxHeight: .infinity)
                .padding(.trailing, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Vertical VU strip

    /// Composite vertical strip: amber illumination band, recessed panel,
    /// tick marks, needle, peak-hold LED. A single Canvas draws all of it so
    /// the redraw cost stays low and the needle interpolates smoothly between
    /// the manager's 1Hz publish ticks.
    ///
    /// TimelineView keeps the redraw cadence smooth during glances; paused
    /// state halts the redraw so the needle freezes at the last position
    /// (matches a real VU meter when the deck is paused).
    private var vuStrip: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: workoutManager.isPaused)) { _ in
            Canvas { gfx, size in
                drawIlluminationBand(gfx: gfx, size: size)
                drawRecessedPanel(gfx: gfx, size: size)
                drawTicks(gfx: gfx, size: size)
                drawNeedle(gfx: gfx, size: size, hr: hrNormalized)
                drawPeakLED(gfx: gfx, size: size, lit: peakLit)
            }
        }
        // Spring ballistics on the strip value so the whole Canvas redraws
        // with a 300ms swing on each HR update — mirrors the iPhone variant's
        // needle animation rule and matches a real analog VU meter's response.
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6),
            value: workoutManager.heartRate
        )
    }

    // MARK: - Drawing helpers

    private func drawIlluminationBand(gfx: GraphicsContext, size: CGSize) {
        // Soft amber wash behind the panel — sells the "lit gauge backlight"
        // cue at low cost. Two stops give a subtle vertical falloff so the
        // top of the strip looks slightly brighter (where the peak LED sits).
        let rect = CGRect(x: -2, y: 0, width: size.width + 4, height: size.height)
        let gradient = Gradient(stops: [
            .init(color: amber.opacity(0.22), location: 0.0),
            .init(color: amber.opacity(0.10), location: 0.55),
            .init(color: amber.opacity(0.04), location: 1.0)
        ])
        gfx.fill(
            Path(rect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawRecessedPanel(gfx: GraphicsContext, size: CGSize) {
        // Dark panel inside the illumination band — gives the strip the
        // "inset gauge" read so it looks recessed into the cabinet face
        // rather than floating on top of the screen.
        let panelInset: CGFloat = 1
        let panelRect = CGRect(
            x: panelInset,
            y: panelInset,
            width: size.width - panelInset * 2,
            height: size.height - panelInset * 2
        )
        let panelPath = Path(roundedRect: panelRect, cornerRadius: 2)
        gfx.fill(panelPath, with: .color(panelDark.opacity(0.85)))
        gfx.stroke(panelPath, with: .color(panelEdge.opacity(0.85)), lineWidth: 0.5)
    }

    private func drawTicks(gfx: GraphicsContext, size: CGSize) {
        // Tick marks running along the right edge of the panel. 10 ticks
        // total, taller / brighter at the 60/200 endpoints, dimmer in the
        // middle. This gives the needle visible scale references as it
        // sweeps without crowding such a narrow strip.
        let tickX = size.width - 3
        let topY: CGFloat = 4
        let bottomY = size.height - 4
        let travel = bottomY - topY
        let tickCount = 10

        var minorTicks = Path()
        for i in 0...tickCount {
            let t = CGFloat(i) / CGFloat(tickCount)
            let y = topY + t * travel
            let isEnd = (i == 0 || i == tickCount)
            let tickLen: CGFloat = isEnd ? 4 : 2
            minorTicks.move(to: CGPoint(x: tickX - tickLen, y: y))
            minorTicks.addLine(to: CGPoint(x: tickX, y: y))
        }
        gfx.stroke(minorTicks, with: .color(amberDim.opacity(0.85)), lineWidth: 0.5)

        // Bright endpoint ticks on top of the dim ones — the "60" / "200"
        // anchors. They read as the dial's scale extremes even without
        // labels (which would be sub-4pt and illegible at this width).
        var endTicks = Path()
        endTicks.move(to: CGPoint(x: tickX - 4, y: topY))
        endTicks.addLine(to: CGPoint(x: tickX, y: topY))
        endTicks.move(to: CGPoint(x: tickX - 4, y: bottomY))
        endTicks.addLine(to: CGPoint(x: tickX, y: bottomY))
        gfx.stroke(endTicks, with: .color(amber.opacity(0.95)), lineWidth: 0.8)
    }

    private func drawNeedle(gfx: GraphicsContext, size: CGSize, hr: Double) {
        // Needle Y — clamp inboard of the end ticks so it never overlaps the
        // peak LED at the top or the bottom endpoint tick. We invert the
        // mapping so HR=1 (max) sits at the TOP of the strip and HR=0
        // (resting) sits at the bottom — matches the iPhone variant's
        // "up = higher BPM" convention.
        let topMargin: CGFloat = 8
        let bottomMargin: CGFloat = 6
        let travel = max(0, size.height - topMargin - bottomMargin)
        let y = (size.height - bottomMargin) - CGFloat(hr) * travel

        // Soft amber glow halo behind the needle — sells the "warm backlit
        // pointer" cue the iPhone variant gets from its larger surface.
        let haloRect = CGRect(x: 1, y: y - 2, width: size.width - 2, height: 4)
        gfx.fill(
            Path(haloRect),
            with: .color(amber.opacity(0.30))
        )

        // The needle itself — horizontal bright line spanning the panel.
        var needle = Path()
        needle.move(to: CGPoint(x: 2, y: y))
        needle.addLine(to: CGPoint(x: size.width - 2, y: y))
        gfx.stroke(needle, with: .color(needleCore), lineWidth: 1.2)

        // Needle tip — small triangle at the right edge so the needle reads
        // as a pointer rather than a scratch.
        var tip = Path()
        tip.move(to: CGPoint(x: size.width - 3, y: y - 2))
        tip.addLine(to: CGPoint(x: size.width - 1, y: y))
        tip.addLine(to: CGPoint(x: size.width - 3, y: y + 2))
        tip.closeSubpath()
        gfx.fill(tip, with: .color(amber))
    }

    private func drawPeakLED(gfx: GraphicsContext, size: CGSize, lit: Bool) {
        // 4pt LED dot near the top of the strip — lights red when the user
        // enters Z4/Z5. When dim, it shows as a dark reservation so the
        // user always sees where it will appear (no surprise pop-in).
        let center = CGPoint(x: size.width / 2, y: 3)
        let radius: CGFloat = 2
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        if lit {
            // Soft red glow behind the LED so it reads as "actually lit"
            // rather than just a colored pixel.
            let haloRect = CGRect(
                x: center.x - 4,
                y: center.y - 4,
                width: 8,
                height: 8
            )
            gfx.fill(
                Path(ellipseIn: haloRect),
                with: .color(peakRed.opacity(0.45))
            )
            gfx.fill(Path(ellipseIn: rect), with: .color(peakRed))
        } else {
            // Dim reservation — dark red so the user can see where the LED
            // sits even when it's off.
            gfx.fill(Path(ellipseIn: rect), with: .color(peakRed.opacity(0.18)))
            gfx.stroke(Path(ellipseIn: rect), with: .color(peakRed.opacity(0.35)), lineWidth: 0.4)
        }
    }
}
