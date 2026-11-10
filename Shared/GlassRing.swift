import SwiftUI

// The Clean theme's signature shape: a soft glass ring (design-system.md, "Signature Shape DNA").
// Static on purpose: no animation, no TimelineView. Three uses and no more:
//   progress arc  (widgets, Today week), coloured arcs (run / walk / cycle parts), track only.
// Arithmetic stays in small typed lets: Release (WMO) type-checks Canvas closures with cos/sin slowly.

public struct GlassRing: View {
    public struct Arc: Sendable {
        public var fraction: Double
        public var color: Color
        public init(fraction: Double, color: Color) {
            self.fraction = fraction
            self.color = color
        }
    }

    let arcs: [Arc]
    let trackColor: Color
    let trackOpacity: Double
    let lineWidth: CGFloat

    /// One progress arc, 0...1. Pass 1.0 for a decorative full ring.
    public init(progress: Double, accentColor: Color, trackOpacity: Double = 0.18, lineWidth: CGFloat = 10) {
        self.arcs = [Arc(fraction: progress, color: accentColor)]
        self.trackColor = accentColor
        self.trackOpacity = trackOpacity
        self.lineWidth = lineWidth
    }

    /// Several coloured arcs in order from 12 o'clock; fractions are shares of the full circle (total clamped to 1).
    public init(arcs: [Arc], trackColor: Color, trackOpacity: Double = 0.18, lineWidth: CGFloat = 10) {
        self.arcs = arcs
        self.trackColor = trackColor
        self.trackOpacity = trackOpacity
        self.lineWidth = lineWidth
    }

    /// Track only (empty state).
    public init(trackColor: Color, trackOpacity: Double = 0.18, lineWidth: CGFloat = 10) {
        self.init(arcs: [], trackColor: trackColor, trackOpacity: trackOpacity, lineWidth: lineWidth)
    }

    public var body: some View {
        Canvas { context, size in
            let inset: CGFloat = lineWidth / 2
            let rect: CGRect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let radius: CGFloat = min(rect.width, rect.height) / 2
            let center: CGPoint = CGPoint(x: rect.midX, y: rect.midY)

            var track = Path()
            track.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
            let trackStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            context.stroke(track, with: .color(trackColor.opacity(trackOpacity)), style: trackStyle)

            // Round caps for one arc; butt caps between neighbours so colours do not smear.
            let cap: CGLineCap = arcs.count > 1 ? .butt : .round
            let arcStyle = StrokeStyle(lineWidth: lineWidth, lineCap: cap)
            var used: Double = 0
            for arc in arcs {
                let share: Double = min(max(arc.fraction, 0), 1 - used)
                guard share > 0 else { continue }
                let startDegrees: Double = -90 + 360 * used
                let endDegrees: Double = startDegrees + 360 * share
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: .degrees(startDegrees), endAngle: .degrees(endDegrees), clockwise: false)
                context.stroke(path, with: .color(arc.color), style: arcStyle)
                used += share
            }
        }
    }
}
