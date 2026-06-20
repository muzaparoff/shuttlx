import SwiftUI

// MARK: - Arcade watchOS workout hero chrome
//
// Watch-adapted Arcade cabinet timer chrome. The iPhone variant renders a full
// 1983-arcade attract screen: separate `1UP` / `HI` corner score slots, a
// blinking `★ HI-SCORE ★` banner, a `STAGE 3-8 ●●●●●○○○○` interval-dot row, and
// a bottom `WORK ░░▓▓░░` power-bar progress strip. On the 41mm watch all of
// that overruns the screen height and competes with the HR row + tertiary
// metric grid the base TrainingView already renders.
//
// What we cut from the iPhone version (per design/proposals/timer-theme-redesigns/arcade-watch.md):
//   * Separate 1UP / HI corner score slots
//   * Blinking ★ HI-SCORE ★ banner
//   * STAGE 3-8 ●●●●●○○○○ interval-dot row (covered by base step pill)
//   * Bottom WORK ░░▓▓░░ power-bar progress strip
//   * "INSERT COIN" idle taunt — handled by the paused-state overlay elsewhere
//   * Custom 7-segment elapsed time digits — the base TrainingView already
//     renders the monospaced timer text in `forStepType` color; double-drawing
//     would conflict with the interval color wash and cost battery
//
// What we keep:
//   * Phosphor-green pixel-border frame around the entire screen
//     (Canvas, 4pt corner radius, ~1pt stroke), with corner "rivets" so it
//     reads as a cabinet bezel and not just a rounded rectangle
//   * Faint scanline grid backdrop (1pt horizontal lines, 4px pitch) at very
//     low opacity so we don't compete with the HR row or timer for legibility
//
// IMPORTANT: this overlay is purely decorative. It uses
// `.allowsHitTesting(false)` so the crown, swipe, and tap targets in
// TrainingView are untouched. It does not modify timer text, the HR row,
// or any workout logic.

struct ArcadeTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Handheld (GBC-era) identity palette — purple shell frame echoes the iPhone
    // skin so the two platforms read as the same device family. Generic colour
    // only; no trademark shapes on the tiny watch face.
    private var phosphor: Color { Color(red: 0.341, green: 0.290, blue: 0.612) }   // #574a9c body purple
    private var phosphorDim: Color { Color(red: 0.169, green: 0.137, blue: 0.337) } // #2b2356 edge

    var body: some View {
        ZStack {
            // --- Backdrop layer: faint scanline grid ---
            //
            // Drawn behind everything except the screen background. Keeps the
            // "CRT inside a cabinet" feel without ever stepping on the metrics
            // VStack, which the base TrainingView centers above.
            scanlineBackdrop
                .allowsHitTesting(false)

            // --- Foreground frame: pixel-border bezel ---
            //
            // A 1pt phosphor-green stroke hugging the screen edge with 4pt
            // corner radius + four corner rivets. Sits on top of the scanlines
            // so the bezel reads as the "cabinet edge", and on top of any tab
            // background so it isn't clipped by safe-area insets.
            pixelBorder
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Scanline backdrop

    /// Horizontal scanlines at very low opacity — the "phosphor grid" of a
    /// dim CRT. 4pt pitch is dense enough to read as a CRT, sparse enough that
    /// it doesn't visually merge into a solid wash and obscure the metrics.
    private var scanlineBackdrop: some View {
        Canvas { gfx, size in
            let pitch: CGFloat = 4
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += pitch
            }
            gfx.stroke(path, with: .color(phosphor.opacity(0.06)), lineWidth: 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: - Pixel border bezel

    /// The cabinet bezel: a 1pt rounded-rect stroke hugging the screen edge,
    /// with four corner "rivet" squares so it reads as a chunky pixel-art
    /// frame instead of a generic rounded outline.
    ///
    /// We render via Canvas (not Rectangle().stroke) so the corner rivets and
    /// the bezel line are a single drawing pass — keeps redraw cost down and
    /// guarantees the rivets land exactly on the bezel corners regardless of
    /// safe-area insets.
    private var pixelBorder: some View {
        Canvas { gfx, size in
            let inset: CGFloat = 2
            let cornerRadius: CGFloat = 4
            let rect = CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )

            // Bezel stroke (outer phosphor line)
            let bezelPath = Path(roundedRect: rect, cornerRadius: cornerRadius)
            gfx.stroke(bezelPath, with: .color(phosphor.opacity(0.85)), lineWidth: 1.0)

            // Inner faint stroke 1.5pt inboard — gives the bezel a subtle
            // "metal extrusion" depth read at low cost (one extra stroke pass)
            let innerRect = rect.insetBy(dx: 1.5, dy: 1.5)
            let innerPath = Path(roundedRect: innerRect, cornerRadius: max(0, cornerRadius - 1.5))
            gfx.stroke(innerPath, with: .color(phosphorDim.opacity(0.5)), lineWidth: 0.5)

            // Corner rivets — 2x2pt squares at each corner of the bezel.
            // The rivets sit slightly inboard of the corner so they read as
            // bolts holding the bezel down rather than as the corner itself.
            let rivetSize: CGFloat = 2
            let rivetInset: CGFloat = 4
            let rivetPositions: [CGPoint] = [
                CGPoint(x: rect.minX + rivetInset, y: rect.minY + rivetInset),
                CGPoint(x: rect.maxX - rivetInset - rivetSize, y: rect.minY + rivetInset),
                CGPoint(x: rect.minX + rivetInset, y: rect.maxY - rivetInset - rivetSize),
                CGPoint(x: rect.maxX - rivetInset - rivetSize, y: rect.maxY - rivetInset - rivetSize)
            ]
            for p in rivetPositions {
                let rivetRect = CGRect(x: p.x, y: p.y, width: rivetSize, height: rivetSize)
                gfx.fill(Path(rivetRect), with: .color(phosphor.opacity(0.9)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
