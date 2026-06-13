import SwiftUI

/// Classic Radio signature accent: a brass needle pointer that marks the
/// latest/current data value at the right edge of a line chart.
/// Drawn as a thin line from the bottom to the value Y with a brass dot tip.
///
/// All Canvas content is decorative — `.allowsHitTesting(false)`.
struct ClassicRadioNeedlePointer: View {
    /// Normalized value: 0.0 = bottom, 1.0 = top of chart frame
    let normalizedValue: Double
    let brassColor: Color
    let chartHeight: CGFloat

    var body: some View {
        Canvas { ctx, size in
            drawNeedle(ctx: ctx, size: size)
        }
        .frame(height: chartHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawNeedle(ctx: GraphicsContext, size: CGSize) {
        let yValue = size.height * (1.0 - CGFloat(normalizedValue))
        let xPos = size.width - 4

        // Needle line from bottom to value
        var needlePath = Path()
        needlePath.move(to: CGPoint(x: xPos, y: size.height))
        needlePath.addLine(to: CGPoint(x: xPos, y: yValue + 6))
        ctx.stroke(needlePath, with: .color(brassColor.opacity(0.80)), lineWidth: 1.5)

        // Brass dot at the tip
        let dotRect = CGRect(
            x: xPos - 4,
            y: yValue - 4,
            width: 8,
            height: 8
        )
        ctx.fill(Path(ellipseIn: dotRect), with: .color(brassColor))
        // Inner highlight
        let innerRect = CGRect(x: xPos - 2, y: yValue - 2, width: 4, height: 4)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(brassColor.opacity(0.45)))

        // Sweep arc (small arc from bottom of needle to value — classic radio dial)
        var arcPath = Path()
        arcPath.addArc(
            center: CGPoint(x: xPos, y: size.height),
            radius: size.height - yValue,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 - Double(normalizedValue) * 60),
            clockwise: true
        )
        ctx.stroke(arcPath, with: .color(brassColor.opacity(0.20)), lineWidth: 0.8)
    }
}

#Preview {
    ClassicRadioNeedlePointer(
        normalizedValue: 0.65,
        brassColor: Color(red: 0.91, green: 0.63, blue: 0.19),
        chartHeight: 140
    )
    .background(Color(red: 0.23, green: 0.18, blue: 0.12))
}
