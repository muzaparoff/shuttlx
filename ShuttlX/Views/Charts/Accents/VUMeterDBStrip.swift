import SwiftUI

/// VU Meter signature accent: renders a single horizontal dB-meter strip.
/// 14 segments per bar; segments past the 0dB threshold (roughly 80% of bar)
/// glow red (peak zone). Used in HRZoneChart and pace zone bars.
///
/// All Canvas content is decorative — `.allowsHitTesting(false)`.
struct VUMeterDBStrip: View {
    /// 0.0 – 1.0 fill fraction (percentage / 100)
    let fillFraction: Double
    /// The active (lit) amber color
    let amberColor: Color
    /// The red zone color for segments beyond ~80%
    let redZoneColor: Color
    /// Height of the strip
    let height: CGFloat

    private let segmentCount = 14
    private let redZoneStart = 0.80  // segments after this fraction are red zone
    private let gapFraction: CGFloat = 0.15

    var body: some View {
        Canvas { ctx, size in
            drawStrip(ctx: ctx, size: size)
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStrip(ctx: GraphicsContext, size: CGSize) {
        let totalGap = CGFloat(segmentCount - 1) * (size.width / CGFloat(segmentCount) * gapFraction)
        let segWidth = (size.width - totalGap) / CGFloat(segmentCount)
        let gapWidth = size.width / CGFloat(segmentCount) * gapFraction

        for i in 0..<segmentCount {
            let segFraction = Double(i + 1) / Double(segmentCount)
            let isLit = segFraction <= fillFraction
            let isRedZone = segFraction > redZoneStart

            let x = CGFloat(i) * (segWidth + gapWidth)
            let rect = CGRect(x: x, y: 0, width: segWidth, height: size.height)
            let path = Path(roundedRect: rect, cornerRadius: 1)

            if isLit {
                let color = isRedZone ? redZoneColor : amberColor
                let alpha: Double = isRedZone ? 1.0 : 0.85
                ctx.fill(path, with: .color(color.opacity(alpha)))

                // Glow for red zone segments
                if isRedZone {
                    let glowRect = rect.insetBy(dx: -2, dy: -2)
                    ctx.fill(
                        Path(roundedRect: glowRect, cornerRadius: 2),
                        with: .color(redZoneColor.opacity(0.25))
                    )
                }
            } else {
                // Dim unlit segment
                ctx.fill(path, with: .color(amberColor.opacity(0.12)))
            }
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        VUMeterDBStrip(
            fillFraction: 0.6,
            amberColor: Color(red: 0.91, green: 0.63, blue: 0.19),
            redZoneColor: Color(red: 0.80, green: 0.27, blue: 0.27),
            height: 20
        )
        VUMeterDBStrip(
            fillFraction: 0.95,
            amberColor: Color(red: 0.91, green: 0.63, blue: 0.19),
            redZoneColor: Color(red: 0.80, green: 0.27, blue: 0.27),
            height: 20
        )
    }
    .padding()
    .background(Color(red: 0.10, green: 0.09, blue: 0.06))
}
