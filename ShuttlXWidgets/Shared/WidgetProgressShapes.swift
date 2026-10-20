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
