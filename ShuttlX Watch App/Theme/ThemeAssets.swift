import SwiftUI
import Foundation

// MARK: - Themed Timer Frame

struct ThemedTimerFrame: View {
    var size: CGFloat = 160

    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave":    SynthwaveTimerFrame(size: size)
        case "mixtape":      MixtapeTimerFrame(size: size)
        case "arcade":       ArcadeTimerFrame(size: size)
        case "classicradio": ClassicRadioTimerFrame(size: size)
        case "vumeter":      VUMeterTimerFrame(size: size)
        default:             CleanTimerFrame(size: size)
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

// MARK: Mixtape Timer Frame — green LCD panel on blue player body

private struct MixtapeTimerFrame: View {
    let size: CGFloat
    private let lcdGreen = Color(red: 0.22, green: 1.0, blue: 0.08)
    private let playerBlue = Color(red: 0.29, green: 0.42, blue: 0.60)

    var body: some View {
        ZStack {
            // Green-gray LCD fill
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.14, blue: 0.10))
                .frame(width: size, height: size * 0.7)

            // Blue-steel border
            RoundedRectangle(cornerRadius: 6)
                .stroke(playerBlue, lineWidth: 2)
                .frame(width: size, height: size * 0.7)

            // Inner inset border
            RoundedRectangle(cornerRadius: 4)
                .stroke(lcdGreen.opacity(0.12), lineWidth: 1)
                .frame(width: size - 8, height: size * 0.7 - 8)

            // Corner brackets
            ForEach(0..<4, id: \.self) { corner in
                LCDBracket(color: playerBlue.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .position(bracketPosition(corner: corner, size: size))
            }
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

// MARK: Classic Radio Timer Frame — cassette label shape with cream fill

private struct ClassicRadioTimerFrame: View {
    let size: CGFloat
    private let cream = Color(red: 0.96, green: 0.90, blue: 0.78)
    private let brown = Color(red: 0.35, green: 0.29, blue: 0.20)

    var body: some View {
        ZStack {
            // Cream label fill
            RoundedRectangle(cornerRadius: 4)
                .fill(cream.opacity(0.08))
                .frame(width: size, height: size * 0.7)

            // Brown border
            RoundedRectangle(cornerRadius: 4)
                .stroke(brown, lineWidth: 2)
                .frame(width: size, height: size * 0.7)

            // Lined paper texture (horizontal rules)
            Canvas { context, canvasSize in
                let lineColor = brown.opacity(0.12)
                for y in stride(from: CGFloat(8), to: canvasSize.height - 4, by: 10) {
                    var path = Path()
                    path.move(to: CGPoint(x: 6, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width - 6, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
            }
            .frame(width: size - 4, height: size * 0.7 - 4)
            .allowsHitTesting(false)

            // Inner inset
            RoundedRectangle(cornerRadius: 2)
                .stroke(cream.opacity(0.1), lineWidth: 1)
                .frame(width: size - 10, height: size * 0.7 - 10)
        }
        .frame(width: size, height: size)
    }
}

// MARK: VU Meter Timer Frame — analog meter panel with arc markings

private struct VUMeterTimerFrame: View {
    let size: CGFloat
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)
    private let darkPanel = Color(red: 0.07, green: 0.05, blue: 0.03)

    var body: some View {
        ZStack {
            // Dark meter panel fill
            RoundedRectangle(cornerRadius: 8)
                .fill(darkPanel)
                .frame(width: size, height: size * 0.7)

            // Amber border
            RoundedRectangle(cornerRadius: 8)
                .stroke(amber.opacity(0.4), lineWidth: 2)
                .frame(width: size, height: size * 0.7)

            // VU arc markings
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.75)
                let radius = canvasSize.width * 0.35

                // Arc path
                var arcPath = Path()
                arcPath.addArc(center: center, radius: radius,
                              startAngle: .degrees(-150), endAngle: .degrees(-30),
                              clockwise: false)
                context.stroke(arcPath, with: .color(amber.opacity(0.2)), lineWidth: 1)

                // Tick marks along arc
                for i in 0...10 {
                    let angle = -150.0 + Double(i) * 12.0
                    let rad = angle * .pi / 180
                    let innerR = radius - 4
                    let outerR = radius + 4
                    let tickColor = i >= 8 ? Color.red.opacity(0.4) : amber.opacity(0.3)

                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + cos(rad) * innerR,
                        y: center.y + sin(rad) * innerR
                    ))
                    tick.addLine(to: CGPoint(
                        x: center.x + cos(rad) * outerR,
                        y: center.y + sin(rad) * outerR
                    ))
                    context.stroke(tick, with: .color(tickColor), lineWidth: 1)
                }
            }
            .frame(width: size - 4, height: size * 0.7 - 4)
            .allowsHitTesting(false)

            // Inner inset
            RoundedRectangle(cornerRadius: 6)
                .stroke(amber.opacity(0.15), lineWidth: 1)
                .frame(width: size - 12, height: size * 0.7 - 12)
        }
        .frame(width: size, height: size)
    }
}

// MARK: Arcade Timer Frame — pixelated rounded rect with CRT phosphor glow

private struct ArcadeTimerFrame: View {
    let size: CGFloat
    private let phosphorGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
    private let accentOrange = Color(red: 1.0, green: 0.67, blue: 0.0)

    var body: some View {
        ZStack {
            // Outer pixel border
            RoundedRectangle(cornerRadius: 4)
                .stroke(phosphorGreen.opacity(0.5), lineWidth: 3)
                .frame(width: size, height: size)

            // Inner dashed pixel ring
            RoundedRectangle(cornerRadius: 4)
                .stroke(phosphorGreen.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: size - 10, height: size - 10)

            // Pixel corner decorations
            ForEach(0..<4, id: \.self) { corner in
                PixelCorner(color: phosphorGreen.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(pixelCornerOffset(corner: corner, size: size))
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
            RoundedRectangle(cornerRadius: 4)
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

    private func pixelCornerOffset(corner: Int, size: CGFloat) -> CGSize {
        let half = size / 2 - 8
        switch corner {
        case 0: return CGSize(width: -half, height: -half)
        case 1: return CGSize(width: half, height: -half)
        case 2: return CGSize(width: -half, height: half)
        case 3: return CGSize(width: half, height: half)
        default: return .zero
        }
    }
}

// MARK: - Themed Completion Badge

struct ThemedCompletionBadge: View {
    var body: some View {
        let themeID = ThemeManager.shared.current.id
        switch themeID {
        case "synthwave":    SynthwaveCompletionBadge()
        case "mixtape":      MixtapeCompletionBadge()
        case "arcade":       ArcadeCompletionBadge()
        case "classicradio": ClassicRadioCompletionBadge()
        case "vumeter":      VUMeterCompletionBadge()
        default:             CleanCompletionBadge()
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

// MARK: Classic Radio Completion Badge — "SIDE A COMPLETE" tape label

private struct ClassicRadioCompletionBadge: View {
    private let cream = Color(red: 0.96, green: 0.90, blue: 0.78)
    private let brown = Color(red: 0.35, green: 0.29, blue: 0.20)
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)

    var body: some View {
        VStack(spacing: 4) {
            Text("SIDE A")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(brown)

            Text("COMPLETE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.3), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(cream.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(brown, lineWidth: 1.5)
        )
    }
}

// MARK: VU Meter Completion Badge — "RECORDING DONE" amber on dark panel

private struct VUMeterCompletionBadge: View {
    private let amber = Color(red: 0.91, green: 0.63, blue: 0.19)
    private let darkPanel = Color(red: 0.07, green: 0.05, blue: 0.03)

    var body: some View {
        VStack(spacing: 4) {
            Text("RECORDING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(amber.opacity(0.6))

            Text("DONE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
                .shadow(color: amber.opacity(0.4), radius: 2)

            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(amber)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(darkPanel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(amber.opacity(0.4), lineWidth: 1.5)
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

// MARK: - Themed Control Button Style

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
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.20))
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.2))
        case "classicradio":
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.23, green: 0.18, blue: 0.12))
        case "vumeter":
            Circle()
                .fill(Color(red: 0.14, green: 0.11, blue: 0.07))
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
        case "mixtape":
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.29, green: 0.42, blue: 0.60), lineWidth: 1.5)
        case "arcade":
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.4), lineWidth: 2)
        case "classicradio":
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.35, green: 0.29, blue: 0.20), lineWidth: 1.5)
        case "vumeter":
            Circle()
                .stroke(Color(red: 0.91, green: 0.63, blue: 0.19).opacity(0.4), lineWidth: 1.5)
        default:
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

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
