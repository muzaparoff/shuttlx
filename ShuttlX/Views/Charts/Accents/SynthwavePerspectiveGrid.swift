import SwiftUI

/// Synthwave signature accent: perspective grid backdrop drawn behind chart bars.
/// Three-point vanishing lines converge toward a horizon and fade upward.
/// All Canvas content is decorative — `.allowsHitTesting(false)`.
struct SynthwavePerspectiveGrid: View {
    let gridColor: Color
    let opacity: Double

    var body: some View {
        Canvas { ctx, size in
            drawPerspectiveGrid(ctx: ctx, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawPerspectiveGrid(ctx: GraphicsContext, size: CGSize) {
        let horizon = size.height * 0.45
        let vanishX = size.width * 0.5
        let numLines = 10

        // Horizontal lines — perspective spacing, denser near bottom
        for i in 0..<numLines {
            let t = Double(i) / Double(numLines - 1)
            let y = horizon + (size.height - horizon) * CGFloat(t * t)
            let alphaFade = opacity * (0.1 + 0.9 * (1.0 - t))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(path, with: .color(gridColor.opacity(alphaFade)), lineWidth: 0.5)
        }

        // Vertical lines converging to vanishing point
        let numVLines = 8
        let alphaV = opacity * 0.6
        for i in 0...numVLines {
            let x = size.width * CGFloat(i) / CGFloat(numVLines)
            var path = Path()
            path.move(to: CGPoint(x: vanishX, y: horizon))
            path.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(path, with: .color(gridColor.opacity(alphaV)), lineWidth: 0.5)
        }

        // Horizon glow strip
        let glowRect = CGRect(x: 0, y: horizon - 4, width: size.width, height: 8)
        ctx.fill(Path(glowRect), with: .color(gridColor.opacity(opacity * 0.35)))
    }
}

#Preview {
    SynthwavePerspectiveGrid(
        gridColor: Color(red: 0.0, green: 0.96, blue: 1.0),
        opacity: 0.25
    )
    .frame(width: 320, height: 160)
    .background(Color(red: 0.04, green: 0.04, blue: 0.10))
}
