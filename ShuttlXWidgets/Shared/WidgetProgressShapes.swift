import SwiftUI

// MARK: - Signature-shape progress canvases (design system: "Signature Shape DNA")
//
// One parametric Canvas per theme, reused across every home-screen widget
// that needs a progress/decorative ring (W1 Start Training, W3 Weekly Goal
// Ring, and future widgets per the widget-lineup proposal). Never draw N
// bespoke illustrations per widget — dispatch through these two views.
//
// Lock-screen accessory families intentionally do NOT use these — they stay
// system-tinted (`Gauge` + `.widgetAccentable()`), per the "no per-theme art
// on lock screen" rule.

/// Clean theme's signature shape: a soft glass ring. `progress` is 0...1;
/// pass 1.0 for a purely decorative (non-progress) ring, as used by W1's
/// play affordance.
struct GlassRingProgress: View {
    let progress: Double
    let accentColor: Color
    var trackOpacity: Double = 0.18
    var lineWidth: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let inset = lineWidth / 2
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let radius = min(rect.width, rect.height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let clamped = min(max(progress, 0), 1)

            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
            context.stroke(track, with: .color(accentColor.opacity(trackOpacity)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            guard clamped > 0 else { return }
            var progressArc = Path()
            let endAngle = -90 + (360 * clamped)
            progressArc.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(endAngle), clockwise: false)
            context.stroke(progressArc, with: .color(accentColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

/// Mixtape theme's signature shape: a cassette spool. `completed` spokes (out
/// of `total`) are drawn filled with the accent color — reads as tape wound
/// onto a reel. `total` is clamped to a minimum of 1 to avoid a degenerate
/// (zero-spoke) draw.
struct CassetteSpoolProgress: View {
    let completed: Int
    let total: Int
    let accentColor: Color
    let surfaceColor: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let radius = min(rect.width, rect.height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let hubRadius = radius * 0.30
            let spokeCount = max(total, 1)
            let filledCount = min(max(completed, 0), spokeCount)

            var rim = Path()
            rim.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(rim, with: .color(surfaceColor), style: StrokeStyle(lineWidth: max(1.5, radius * 0.09)))

            for i in 0..<spokeCount {
                let angle = (Double(i) / Double(spokeCount)) * 2 * .pi - (.pi / 2)
                let isFilled = i < filledCount
                let inner = CGPoint(x: center.x + cos(angle) * hubRadius, y: center.y + sin(angle) * hubRadius)
                let outer = CGPoint(x: center.x + cos(angle) * radius * 0.88, y: center.y + sin(angle) * radius * 0.88)
                var spoke = Path()
                spoke.move(to: inner)
                spoke.addLine(to: outer)
                context.stroke(
                    spoke,
                    with: .color(isFilled ? accentColor : surfaceColor.opacity(0.5)),
                    style: StrokeStyle(lineWidth: max(1.5, radius * 0.10), lineCap: .round)
                )
            }

            var hub = Path()
            hub.addEllipse(in: CGRect(x: center.x - hubRadius, y: center.y - hubRadius, width: hubRadius * 2, height: hubRadius * 2))
            context.fill(hub, with: .color(accentColor))
        }
    }
}
