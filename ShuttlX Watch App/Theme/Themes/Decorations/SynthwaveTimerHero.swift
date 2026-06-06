import SwiftUI

// MARK: - Synthwave watchOS workout hero chrome
//
// Watch-adapted Synthwave timer chrome. The iPhone variant has a trapezoidal
// dash frame, chevron ticks, three vertical needle gauges, and a destination
// step pill. On the 41mm watch all of that eats horizontal space and clutters
// the glanceable timer, so we cut the frame entirely and keep only the part
// that carries the brand: the perspective horizon grid + neon sun halo.
//
// Cut from iPhone version:
//   * Trapezoidal chevron frame around the time
//   * Chevron tick marks and destination-sign step pill on top
//   * Three vertical needle gauges (HR / Pace / Dist row)
//
// Kept (at reduced intensity for backlight bloom):
//   * Perspective horizon grid in the lower ~50% of the screen
//   * Neon sun halo behind the timer line
//   * Magenta haze "fog" at horizon, 60% intensity
//
// IMPORTANT: this overlay is purely decorative. It uses
// `.allowsHitTesting(false)` so the crown, swipe, and tap targets in
// TrainingView are untouched. It does not modify timer text, the HR row,
// or any workout logic.

struct SynthwaveTimerOverlay: View {
    @ObservedObject var workoutManager: WatchWorkoutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Brand neon palette (mirrors SynthwaveTheme)
    private var neonCyan: Color { Color(red: 0.0, green: 0.96, blue: 1.0) }
    private var neonMagenta: Color { Color(red: 1.0, green: 0.18, blue: 0.58) }
    private var sunCore: Color { Color(red: 1.0, green: 0.86, blue: 0.42) }

    /// Scroll speed driver: pace (sec/km) clamped to a slow-fast band.
    /// Faster running = faster scroll. Falls back to a slow ambient drift
    /// when pace is nil (start of workout) or the workout is paused.
    private var scrollSpeed: Double {
        if workoutManager.isPaused { return 0 }
        guard let pace = workoutManager.currentPace, pace > 0 else { return 0.25 }
        // 8:00/km -> slow, 4:00/km -> fast. Clamp to [0.2, 1.2].
        let normalized = max(0.2, min(1.2, 480.0 / pace))
        return normalized
    }

    var body: some View {
        ZStack {
            // --- Backdrop layer: sun halo + horizon grid + magenta fog ---
            //
            // Sits inside the lower 50% of the screen via a vertical alignment
            // trick (Spacer on top). This keeps the top half of the screen
            // clean for the HR row & step pill which the base TrainingView
            // already renders.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                horizonBackdrop
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            // --- Foreground bloom: soft neon halo behind the hero timer ---
            //
            // The base TrainingView centers the timer roughly at vertical
            // center. We render a 38pt circular haze a bit above center so
            // the timer numerals appear to emit cyan/magenta light. Pure
            // backdrop — does not touch the actual Text.
            timerBloom
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: - Horizon backdrop (Canvas)

    private var horizonBackdrop: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gfx, size in
                drawSunHalo(gfx: gfx, size: size)
                drawGrid(gfx: gfx, size: size, time: t)
                drawHorizonFog(gfx: gfx, size: size)
            }
        }
    }

    private func drawSunHalo(gfx: GraphicsContext, size: CGSize) {
        // Sun sits on the horizon line (top edge of the 80pt strip).
        let center = CGPoint(x: size.width / 2, y: 6)
        let radius = max(28, size.width * 0.22)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let gradient = Gradient(stops: [
            .init(color: sunCore.opacity(0.55), location: 0.0),
            .init(color: neonMagenta.opacity(0.35), location: 0.55),
            .init(color: neonMagenta.opacity(0.0), location: 1.0)
        ])
        gfx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 2,
                endRadius: radius
            )
        )
    }

    private func drawGrid(gfx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let horizonY: CGFloat = 6
        let vanishX = size.width / 2
        let bottomY = size.height
        let scroll = CGFloat((time * scrollSpeed).truncatingRemainder(dividingBy: 1.0))

        // Horizontal scrolling perspective lines (8 lines, eased toward horizon).
        var hPath = Path()
        let lineCount = 8
        for i in 0..<lineCount {
            // 0...1 progress with scroll offset, eased so lines bunch near horizon.
            let raw = (CGFloat(i) + scroll) / CGFloat(lineCount)
            let eased = pow(raw, 2.0)
            let y = horizonY + eased * (bottomY - horizonY)
            hPath.move(to: CGPoint(x: 0, y: y))
            hPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        gfx.stroke(hPath, with: .color(neonCyan.opacity(0.42)), lineWidth: 0.5)

        // Vertical perspective lines converging at the vanishing point.
        var vPath = Path()
        let cols = 5
        for i in -cols...cols {
            let xBottom = vanishX + CGFloat(i) * (size.width / 4.5)
            vPath.move(to: CGPoint(x: vanishX, y: horizonY))
            vPath.addLine(to: CGPoint(x: xBottom, y: bottomY))
        }
        gfx.stroke(vPath, with: .color(neonCyan.opacity(0.55)), lineWidth: 0.6)
    }

    private func drawHorizonFog(gfx: GraphicsContext, size: CGSize) {
        // 60% intensity magenta haze along the horizon strip.
        let band = CGRect(x: 0, y: 0, width: size.width, height: 14)
        let gradient = Gradient(stops: [
            .init(color: neonMagenta.opacity(0.36), location: 0.0),
            .init(color: neonMagenta.opacity(0.0), location: 1.0)
        ])
        gfx.fill(
            Path(band),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: 14)
            )
        )
    }

    // MARK: - Timer bloom halo

    /// A soft cyan halo with a magenta inner ring rendered behind the hero
    /// timer position. Does not modify the timer Text — it's a pure visual
    /// echo, sized so the numerals appear to emit light.
    private var timerBloom: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(neonCyan.opacity(0.18))
                    .frame(width: 110, height: 60)
                    .blur(radius: 14)
                Circle()
                    .fill(neonMagenta.opacity(0.22))
                    .frame(width: 70, height: 36)
                    .blur(radius: 10)
            }
            .blendMode(.plusLighter)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
