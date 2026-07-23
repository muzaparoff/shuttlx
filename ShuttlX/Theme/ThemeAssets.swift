import SwiftUI
import Foundation

// MARK: - Themed Timer Frame

struct ThemedTimerFrame: View {
    var width: CGFloat = 160
    var height: CGFloat = 160

    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "mixtape": MixtapeTimerFrame(width: width, height: height)
        default:        CleanTimerFrame(width: width, height: height)
        }
    }
}

// MARK: Clean Timer Frame — premium glass chronograph with beveled edges + chapter ring

private struct CleanTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private var size: CGFloat { min(width, height) }

    var body: some View {
        ZStack {
            // Ambient glow behind frame
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    RadialGradient(
                        colors: [ShuttlXColor.ctaPrimary.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: width + 16, height: height + 16)
                .allowsHitTesting(false)

            // Outer beveled stroke
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [ShuttlXColor.ctaPrimary.opacity(0.3), ShuttlXColor.ctaPrimary.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: width, height: height)

            // Inner beveled stroke (gap creates bevel feel)
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width - 8, height: height - 8)

            // 12-mark chapter ring (4 cardinal + 8 intermediate)
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0
                let isCardinal = i % 3 == 0
                TickMark(
                    color: .white.opacity(isCardinal ? 0.2 : 0.1),
                    length: isCardinal ? 6 : 3,
                    width: isCardinal ? 1.5 : 1
                )
                .rotationEffect(.degrees(angle))
            }
            .frame(width: size - 6, height: size - 6)

            // Top specular arc
            Canvas { context, canvasSize in
                let arcW = canvasSize.width * 0.55
                let arcX = (canvasSize.width - arcW) / 2
                let arcY: CGFloat = 10
                var path = Path()
                path.move(to: CGPoint(x: arcX, y: arcY + 2))
                path.addQuadCurve(
                    to: CGPoint(x: arcX + arcW, y: arcY + 2),
                    control: CGPoint(x: canvasSize.width / 2, y: arcY - 2)
                )
                context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 2)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Bottom shadow line
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.black.opacity(0.05))
                .frame(width: width * 0.5, height: 1)
                .offset(y: height / 2 - 14)

            // Center cross-hair
            Canvas { context, canvasSize in
                let cx = canvasSize.width / 2
                let cy = canvasSize.height / 2
                let arm: CGFloat = 2
                let color = Color.white.opacity(0.06)
                // Horizontal
                var h = Path()
                h.move(to: CGPoint(x: cx - arm, y: cy))
                h.addLine(to: CGPoint(x: cx + arm, y: cy))
                context.stroke(h, with: .color(color), lineWidth: 1)
                // Vertical
                var v = Path()
                v.move(to: CGPoint(x: cx, y: cy - arm))
                v.addLine(to: CGPoint(x: cx, y: cy + arm))
                context.stroke(v, with: .color(color), lineWidth: 1)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
    }
}

// MARK: Mixtape Timer Frame — portable player LCD screen with bezel + screws

private struct MixtapeTimerFrame: View {
    let width: CGFloat
    let height: CGFloat
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let playerBlue = Color(red: 0.29, green: 0.42, blue: 0.60)

    var body: some View {
        ZStack {
            // Green-gray LCD fill
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.14, blue: 0.10))

            // Outer bezel (3D plastic effect)
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [playerBlue.opacity(0.8), playerBlue.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 3
                )

            // Inner inset border
            RoundedRectangle(cornerRadius: 4)
                .stroke(lcdGreen.opacity(0.12), lineWidth: 1)
                .padding(5)

            // Green accent line at LCD top edge
            Canvas { context, canvasSize in
                var path = Path()
                path.move(to: CGPoint(x: 8, y: 6))
                path.addLine(to: CGPoint(x: canvasSize.width - 8, y: 6))
                context.stroke(path, with: .color(lcdGreen.opacity(0.2)), lineWidth: 0.5)
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Corner screws
            GeometryReader { geo in
                let inset: CGFloat = 8
                ForEach(0..<4, id: \.self) { corner in
                    ScrewDecoration(color: playerBlue.opacity(0.35))
                        .frame(width: 4, height: 4)
                        .position(screwPosition(corner: corner, w: geo.size.width, h: geo.size.height, inset: inset))
                }
            }

            // Dot matrix texture
            DotGrid(color: lcdGreen.opacity(0.04), dotSize: 0.8, spacing: 6)
                .frame(width: width - 12, height: height - 12)
                .allowsHitTesting(false)

            // LCD segment dividers (dashed lines at 1/3 and 2/3)
            Canvas { context, canvasSize in
                let lineColor = lcdGreen.opacity(0.08)
                let inset: CGFloat = 8
                for frac in [1.0 / 3.0, 2.0 / 3.0] {
                    let y = canvasSize.height * frac
                    var path = Path()
                    path.move(to: CGPoint(x: inset, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - inset, y: y))
                    context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }
            }
            .frame(width: width, height: height)
            .allowsHitTesting(false)

            // Glass reflection (top 30%)
            LinearGradient(
                colors: [Color.white.opacity(0.03), .clear],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.3)
            )
            .frame(width: width - 6, height: height - 6)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .allowsHitTesting(false)

            // Tape counter display
            Text("000")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(lcdGreen.opacity(0.3))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(8)

            // Transport row: rewind + play + fast-forward
            HStack(spacing: 6) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 5))
                    .foregroundColor(playerBlue.opacity(0.2))
                Image(systemName: "play.fill")
                    .font(.system(size: 6))
                    .foregroundColor(playerBlue.opacity(0.35))
                Image(systemName: "forward.fill")
                    .font(.system(size: 5))
                    .foregroundColor(playerBlue.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 7)
        }
        .frame(width: width, height: height)
    }

    private func screwPosition(corner: Int, w: CGFloat, h: CGFloat, inset: CGFloat) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: inset, y: inset)
        case 1: return CGPoint(x: w - inset, y: inset)
        case 2: return CGPoint(x: inset, y: h - inset)
        case 3: return CGPoint(x: w - inset, y: h - inset)
        default: return .zero
        }
    }
}

// MARK: - Themed Completion Badge

struct ThemedCompletionBadge: View {
    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "mixtape": MixtapeCompletionBadge()
        default:        CleanCompletionBadge()
        }
    }
}

// MARK: Clean Completion Badge — glass checkmark circle

private struct CleanCompletionBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)

            Circle()
                .stroke(ShuttlXColor.ctaPrimary.opacity(0.3), lineWidth: 2)
                .frame(width: 52, height: 52)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ShuttlXColor.positive, ShuttlXColor.walking],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: Mixtape Completion Badge — "REWIND COMPLETE" on green LCD

private struct MixtapeCompletionBadge: View {
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let playerBlue = Color(red: 0.29, green: 0.42, blue: 0.60)

    var body: some View {
        VStack(spacing: 4) {
            Text("REWIND")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(playerBlue)

            Text("COMPLETE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(lcdGreen)
                .shadow(color: lcdGreen.opacity(0.4), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(lcdGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(playerBlue, lineWidth: 1.5)
        )
    }
}

// MARK: - Themed Control Button Style (watchOS only — uses watch-specific size tokens)

#if os(watchOS)
// Note: button style is watchOS-only; iOS uses standard button styles
struct ThemedControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let themeID = ThemeManager.shared.current.id
        let effects = ThemeManager.shared.effects

        configuration.label
            .frame(width: ShuttlXSize.controlButtonDiameter, height: ShuttlXSize.controlButtonDiameter)
            .background(buttonBackground(themeID: themeID))
            .overlay(buttonOverlay(themeID: themeID, effects: effects))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(themeID: String) -> some View {
        switch themeID {
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.20))
        default:
            RoundedRectangle(cornerRadius: 12)
                .fill(ShuttlXColor.watchButtonBackground)
        }
    }

    @ViewBuilder
    private func buttonOverlay(themeID: String, effects: ThemeEffects) -> some View {
        switch themeID {
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.29, green: 0.42, blue: 0.60), lineWidth: 1.5)
        default:
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}
#endif

// MARK: - Helper Shapes

private struct TickMark: View {
    let color: Color
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(color)
                .frame(width: width, height: length)
                .position(x: geo.size.width / 2, y: length / 2)
        }
    }
}

// MARK: New Helper Shapes

/// Tiny circle with cross line — used for screw decorations (Mixtape corners, VU Meter mounting)
private struct ScrewDecoration: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(size.width, size.height) / 2

            // Outer circle
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(color), lineWidth: 0.5
            )
            // Cross lines
            var h = Path()
            h.move(to: CGPoint(x: cx - r * 0.6, y: cy))
            h.addLine(to: CGPoint(x: cx + r * 0.6, y: cy))
            context.stroke(h, with: .color(color), lineWidth: 0.5)

            var v = Path()
            v.move(to: CGPoint(x: cx, y: cy - r * 0.6))
            v.addLine(to: CGPoint(x: cx, y: cy + r * 0.6))
            context.stroke(v, with: .color(color), lineWidth: 0.5)
        }
    }
}

/// Canvas-based dot matrix grid — used for LCD textures (Mixtape) and sub-pixel patterns (Arcade)
private struct DotGrid: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)
            let offsetX = (size.width - CGFloat(cols) * spacing) / 2
            let offsetY = (size.height - CGFloat(rows) * spacing) / 2

            for row in 0...rows {
                for col in 0...cols {
                    let x = offsetX + CGFloat(col) * spacing
                    let y = offsetY + CGFloat(row) * spacing
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)),
                        with: .color(color)
                    )
                }
            }
        }
    }
}


