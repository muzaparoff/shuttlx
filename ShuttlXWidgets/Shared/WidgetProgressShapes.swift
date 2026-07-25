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
//
// NOTE: every arithmetic expression below is deliberately split into small,
// explicitly-typed `let` bindings. Release builds (whole-module optimization)
// type-check far more aggressively than Debug, and mixed Double/CGFloat
// arithmetic inside a `Canvas` closure — especially combined with `cos`/`sin`
// (which are overloaded for both `Double` and `CGFloat`) and ternaries — is a
// classic trigger for "unable to type-check this expression in reasonable
// time" in whole-module Release archives. Keep new arithmetic here similarly
// small and explicitly typed.

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
            let inset: CGFloat = lineWidth / 2
            let rect: CGRect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let radius: CGFloat = min(rect.width, rect.height) / 2
            let center: CGPoint = CGPoint(x: rect.midX, y: rect.midY)
            let clamped: Double = min(max(progress, 0), 1)

            let trackStartAngle: Angle = .degrees(-90)
            let trackEndAngle: Angle = .degrees(270)
            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: trackStartAngle, endAngle: trackEndAngle, clockwise: false)

            let trackColor: Color = accentColor.opacity(trackOpacity)
            let ringStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            context.stroke(track, with: .color(trackColor), style: ringStyle)

            guard clamped > 0 else { return }

            let sweepDegrees: Double = 360 * clamped
            let endDegrees: Double = -90 + sweepDegrees
            let progressStartAngle: Angle = .degrees(-90)
            let progressEndAngle: Angle = .degrees(endDegrees)

            var progressArc = Path()
            progressArc.addArc(center: center, radius: radius, startAngle: progressStartAngle, endAngle: progressEndAngle, clockwise: false)
            context.stroke(progressArc, with: .color(accentColor), style: ringStyle)
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
            let radius: CGFloat = min(size.width, size.height) / 2
            let center: CGPoint = CGPoint(x: size.width / 2, y: size.height / 2)
            let hubRadius: CGFloat = radius * 0.30
            let spokeCount: Int = max(total, 1)
            let filledCount: Int = min(max(completed, 0), spokeCount)

            drawRim(in: context, center: center, radius: radius)
            drawSpokes(in: context, center: center, radius: radius, hubRadius: hubRadius, spokeCount: spokeCount, filledCount: filledCount)
            drawHub(in: context, center: center, hubRadius: hubRadius)
        }
    }

    // `GraphicsContext` is a frozen struct whose `stroke`/`fill` methods are
    // non-mutating (they draw immediately) — passed by value here, no
    // `inout` needed.
    private func drawRim(in context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let diameter: CGFloat = radius * 2
        let originX: CGFloat = center.x - radius
        let originY: CGFloat = center.y - radius
        let rimRect = CGRect(x: originX, y: originY, width: diameter, height: diameter)

        var rim = Path()
        rim.addEllipse(in: rimRect)

        let rimLineWidth: CGFloat = max(1.5, radius * 0.09)
        let rimStyle = StrokeStyle(lineWidth: rimLineWidth)
        context.stroke(rim, with: .color(surfaceColor), style: rimStyle)
    }

    private func drawSpokes(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        hubRadius: CGFloat,
        spokeCount: Int,
        filledCount: Int
    ) {
        let hubRadiusD: Double = Double(hubRadius)
        let outerRadiusD: Double = Double(radius) * 0.88
        let centerXD: Double = Double(center.x)
        let centerYD: Double = Double(center.y)
        let twoPi: Double = 2 * Double.pi
        let quarterTurn: Double = Double.pi / 2
        let spokeLineWidth: CGFloat = max(1.5, radius * 0.10)
        let spokeStyle = StrokeStyle(lineWidth: spokeLineWidth, lineCap: .round)
        let filledColor: Color = accentColor
        let unfilledColor: Color = surfaceColor.opacity(0.5)

        for i in 0..<spokeCount {
            let fraction: Double = Double(i) / Double(spokeCount)
            let angle: Double = (fraction * twoPi) - quarterTurn
            let cosAngle: Double = cos(angle)
            let sinAngle: Double = sin(angle)

            let innerX: Double = centerXD + (cosAngle * hubRadiusD)
            let innerY: Double = centerYD + (sinAngle * hubRadiusD)
            let outerX: Double = centerXD + (cosAngle * outerRadiusD)
            let outerY: Double = centerYD + (sinAngle * outerRadiusD)

            let inner = CGPoint(x: CGFloat(innerX), y: CGFloat(innerY))
            let outer = CGPoint(x: CGFloat(outerX), y: CGFloat(outerY))

            var spoke = Path()
            spoke.move(to: inner)
            spoke.addLine(to: outer)

            let isFilled: Bool = i < filledCount
            let spokeColor: Color = isFilled ? filledColor : unfilledColor
            context.stroke(spoke, with: .color(spokeColor), style: spokeStyle)
        }
    }

    private func drawHub(in context: GraphicsContext, center: CGPoint, hubRadius: CGFloat) {
        let diameter: CGFloat = hubRadius * 2
        let originX: CGFloat = center.x - hubRadius
        let originY: CGFloat = center.y - hubRadius
        let hubRect = CGRect(x: originX, y: originY, width: diameter, height: diameter)

        var hub = Path()
        hub.addEllipse(in: hubRect)
        context.fill(hub, with: .color(accentColor))
    }
}
