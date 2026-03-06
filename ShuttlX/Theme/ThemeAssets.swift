import SwiftUI
import Foundation

// MARK: - Themed Timer Frame

struct ThemedTimerFrame: View {
    var size: CGFloat = 160

    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave": SynthwaveTimerFrame(size: size)
        case "casio":     CasioTimerFrame(size: size)
        case "arcade":    ArcadeTimerFrame(size: size)
        default:          CleanTimerFrame(size: size)
        }
    }
}

// MARK: Clean Timer Frame — glass rounded rect with gradient border + specular highlight

private struct CleanTimerFrame: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer glow border
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.3), Color.blue.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: size, height: size)

            // Main glass frame
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 6
                )
                .frame(width: size - 8, height: size - 8)

            // Top specular highlight bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.15))
                .frame(width: size * 0.55, height: 3)
                .offset(y: -(size / 2 - 12))

            // Tick marks at cardinal positions
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                TickMark(color: .white.opacity(0.2), length: 6, width: 1.5)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 6, height: size - 6)
        }
        .frame(width: size, height: size)
    }
}

// MARK: Synthwave Timer Frame — neon glow rounded rect (cyan/magenta)

private struct SynthwaveTimerFrame: View {
    let size: CGFloat
    private let cyan = Color(red: 0.0, green: 0.96, blue: 1.0)
    private let magenta = Color(red: 1.0, green: 0.18, blue: 0.58)

    var body: some View {
        ZStack {
            // Dark background fill
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0.04, green: 0.04, blue: 0.1))
                .frame(width: size, height: size)

            // Outer magenta glow border
            RoundedRectangle(cornerRadius: 24)
                .stroke(magenta.opacity(0.4), lineWidth: 2)
                .frame(width: size - 4, height: size - 4)
                .shadow(color: magenta.opacity(0.3), radius: 8)

            // Main cyan neon frame
            RoundedRectangle(cornerRadius: 22)
                .stroke(cyan, lineWidth: 3)
                .frame(width: size - 12, height: size - 12)
                .shadow(color: cyan.opacity(0.5), radius: 6)
                .shadow(color: cyan.opacity(0.25), radius: 12)

            // Inner thin cyan frame
            RoundedRectangle(cornerRadius: 18)
                .stroke(cyan.opacity(0.3), lineWidth: 1)
                .frame(width: size - 24, height: size - 24)

            // Cyan tick marks at cardinal positions
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                TickMark(color: cyan.opacity(0.8), length: 8, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 6, height: size - 6)

            // Magenta accent ticks at diagonals
            ForEach([45, 135, 225, 315], id: \.self) { angle in
                TickMark(color: magenta.opacity(0.4), length: 5, width: 1.5)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 6, height: size - 6)
        }
        .frame(width: size, height: size)
    }
}

// MARK: Casio Timer Frame — LCD segment-style rectangular border

private struct CasioTimerFrame: View {
    let size: CGFloat
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let amber = Color(red: 1.0, green: 0.72, blue: 0.0)

    var body: some View {
        ZStack {
            // Outer LCD panel border
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(white: 0.2), lineWidth: 2)
                .frame(width: size, height: size * 0.7)

            // Inner inset border
            RoundedRectangle(cornerRadius: 2)
                .stroke(lcdGreen.opacity(0.15), lineWidth: 1)
                .frame(width: size - 8, height: size * 0.7 - 8)

            // Corner brackets (LCD segment style)
            ForEach(0..<4, id: \.self) { corner in
                LCDBracket(color: lcdGreen.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .position(bracketPosition(corner: corner, size: size))
            }

            // Dot matrix overlay
            Canvas { context, canvasSize in
                let dotColor = lcdGreen.opacity(0.04)
                for x in stride(from: CGFloat(0), to: canvasSize.width, by: 6) {
                    for y in stride(from: CGFloat(0), to: canvasSize.height, by: 6) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(dotColor)
                        )
                    }
                }
            }
            .frame(width: size - 10, height: size * 0.7 - 10)
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
    }

    private func bracketPosition(corner: Int, size: CGFloat) -> CGPoint {
        let w = size, h = size * 0.7
        let inset: CGFloat = 8
        let cx = size / 2, cy = size / 2
        switch corner {
        case 0: return CGPoint(x: cx - w / 2 + inset, y: cy - h / 2 + inset)
        case 1: return CGPoint(x: cx + w / 2 - inset, y: cy - h / 2 + inset)
        case 2: return CGPoint(x: cx - w / 2 + inset, y: cy + h / 2 - inset)
        case 3: return CGPoint(x: cx + w / 2 - inset, y: cy + h / 2 - inset)
        default: return .zero
        }
    }
}

// MARK: Arcade Timer Frame — pixelated circle with CRT phosphor glow

private struct ArcadeTimerFrame: View {
    let size: CGFloat
    private let phosphorGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let accentOrange = Color(red: 1.0, green: 0.67, blue: 0.0)

    var body: some View {
        ZStack {
            // Outer pixel border
            Circle()
                .stroke(phosphorGreen.opacity(0.5), lineWidth: 3)
                .frame(width: size, height: size)

            // Inner dashed pixel ring
            Circle()
                .stroke(phosphorGreen.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: size - 10, height: size - 10)

            // Pixel corner decorations
            ForEach(0..<4, id: \.self) { corner in
                PixelCorner(color: phosphorGreen.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(pixelCornerOffset(corner: corner, radius: size / 2 - 4))
            }

            // Green tick marks
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                TickMark(color: phosphorGreen.opacity(0.6), length: 6, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 4, height: size - 4)

            // Orange accent pixels at diagonals
            ForEach([45, 135, 225, 315], id: \.self) { angle in
                TickMark(color: accentOrange.opacity(0.4), length: 4, width: 2)
                    .rotationEffect(.degrees(Double(angle)))
            }
            .frame(width: size - 4, height: size - 4)

            // CRT phosphor glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [phosphorGreen.opacity(0.03), .clear],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
    }

    private func pixelCornerOffset(corner: Int, radius: CGFloat) -> CGSize {
        let angle = Double(corner) * 90 + 45
        let rad = angle * .pi / 180
        return CGSize(width: CGFloat(Foundation.cos(rad)) * radius * 0.7, height: CGFloat(Foundation.sin(rad)) * radius * 0.7)
    }
}

// MARK: - Themed Completion Badge

struct ThemedCompletionBadge: View {
    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave": SynthwaveCompletionBadge()
        case "casio":     CasioCompletionBadge()
        case "arcade":    ArcadeCompletionBadge()
        default:          CleanCompletionBadge()
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
                .stroke(Color.indigo.opacity(0.3), lineWidth: 2)
                .frame(width: 52, height: 52)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: Synthwave Completion Badge — neon trophy

private struct SynthwaveCompletionBadge: View {
    private let cyan = Color(red: 0.0, green: 0.96, blue: 1.0)
    private let amber = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        ZStack {
            // Trophy icon with glow
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [amber, Color(red: 1.0, green: 0.65, blue: 0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: amber.opacity(0.5), radius: 6)

            // Cyan star overlay
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(cyan)
                .shadow(color: cyan.opacity(0.6), radius: 4)
                .offset(y: -4)
        }
    }
}

// MARK: Casio Completion Badge — LCD "COMPLETE" display

private struct CasioCompletionBadge: View {
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)

    var body: some View {
        VStack(spacing: 4) {
            // LCD panel frame
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
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(white: 0.2), lineWidth: 1.5)
        )
    }
}

// MARK: Arcade Completion Badge — "HIGH SCORE" CRT display

private struct ArcadeCompletionBadge: View {
    private let green = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let orange = Color(red: 1.0, green: 0.67, blue: 0.0)

    var body: some View {
        VStack(spacing: 4) {
            Text("HIGH SCORE")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(orange)
                .shadow(color: orange.opacity(0.4), radius: 2)

            HStack(spacing: 2) {
                Image(systemName: "star.fill").foregroundColor(.yellow)
                Image(systemName: "star.fill").foregroundColor(.cyan)
                Image(systemName: "star.fill").foregroundColor(.pink)
            }
            .font(.system(size: 8))

            Text("COMPLETE")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundColor(green)
                .shadow(color: green.opacity(0.5), radius: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(green.opacity(0.5), lineWidth: 2)
        )
    }
}

// MARK: - Themed Control Button Style (watchOS only — uses watch-specific size tokens)

#if os(watchOS)
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
        case "synthwave":
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.16))
        case "casio":
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.2))
        default:
            RoundedRectangle(cornerRadius: 12)
                .fill(ShuttlXColor.watchButtonBackground)
        }
    }

    @ViewBuilder
    private func buttonOverlay(themeID: String, effects: ThemeEffects) -> some View {
        switch themeID {
        case "synthwave":
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.0, green: 0.96, blue: 1.0).opacity(0.4), lineWidth: 1.5)
                .shadow(color: Color(red: 0.0, green: 0.96, blue: 1.0).opacity(0.3), radius: 4)
        case "casio":
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(white: 0.25), lineWidth: 1.5)
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.4), lineWidth: 2)
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

private struct LCDBracket: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

private struct PixelCorner: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 2
            context.fill(Path(CGRect(x: 0, y: 0, width: s, height: s)), with: .color(color))
            context.fill(Path(CGRect(x: s, y: 0, width: s, height: s)), with: .color(color.opacity(0.5)))
            context.fill(Path(CGRect(x: 0, y: s, width: s, height: s)), with: .color(color.opacity(0.5)))
        }
    }
}
