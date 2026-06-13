import SwiftUI

/// Mixtape signature accent: renders a tiny tape-spool decoration
/// for a day chip in `WeekStripView` when the day has sessions.
///
/// Two concentric circles (hub + rim) with 6 symmetrical hole dots.
/// Decorative only — `.allowsHitTesting(false)`.
struct MixtapeSpoolDot: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let bounds = CGRect(origin: .zero, size: size)
            drawSpool(ctx: ctx, bounds: bounds)
        }
        .frame(width: self.size, height: self.size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawSpool(ctx: GraphicsContext, bounds: CGRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerR = bounds.width * 0.48
        let middleR = bounds.width * 0.32
        let hubR = bounds.width * 0.14
        let holeR = bounds.width * 0.065

        // Outer rim
        ctx.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - outerR, y: center.y - outerR,
                width: outerR * 2, height: outerR * 2
            )),
            with: .color(color.opacity(0.60)),
            lineWidth: 0.8
        )

        // Middle tape track ring
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - middleR, y: center.y - middleR,
                width: middleR * 2, height: middleR * 2
            )),
            with: .color(color.opacity(0.18))
        )
        ctx.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - middleR, y: center.y - middleR,
                width: middleR * 2, height: middleR * 2
            )),
            with: .color(color.opacity(0.55)),
            lineWidth: 0.8
        )

        // Hub circle
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - hubR, y: center.y - hubR,
                width: hubR * 2, height: hubR * 2
            )),
            with: .color(color.opacity(0.80))
        )

        // 6 equidistant hole dots
        let holeOrbit = (middleR + outerR) * 0.55
        for i in 0..<6 {
            let angle = Double(i) * (Double.pi / 3.0) - Double.pi / 6
            let hx = center.x + holeOrbit * CGFloat(cos(angle))
            let hy = center.y + holeOrbit * CGFloat(sin(angle))
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: hx - holeR, y: hy - holeR,
                    width: holeR * 2, height: holeR * 2
                )),
                with: .color(color.opacity(0.70))
            )
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        MixtapeSpoolDot(color: Color(red: 0.22, green: 1.0, blue: 0.08), size: 24)
        MixtapeSpoolDot(color: Color(red: 0.29, green: 0.54, blue: 0.79), size: 24)
    }
    .padding()
    .background(Color(red: 0.05, green: 0.08, blue: 0.13))
}
