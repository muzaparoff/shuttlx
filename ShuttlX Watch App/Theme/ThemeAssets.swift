import SwiftUI
import Foundation

// MARK: - Themed Timer Frame

struct ThemedTimerFrame: View {
    var width: CGFloat = 160
    var height: CGFloat = 160

    var body: some View {
        CleanTimerFrame(width: width, height: height)
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
                        colors: [Color.indigo.opacity(0.06), .clear],
                        center: .center, startRadius: 0, endRadius: size / 2
                    )
                )
                .frame(width: width + 16, height: height + 16)
                .allowsHitTesting(false)

            // Outer beveled stroke
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.3), Color.blue.opacity(0.15)],
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

// MARK: - Themed Completion Badge

struct ThemedCompletionBadge: View {
    var body: some View {
        CleanCompletionBadge()
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
        Circle()
            .fill(ShuttlXColor.watchButtonBackground)
    }

    @ViewBuilder
    private func buttonOverlay(themeID: String, effects: ThemeEffects) -> some View {
        Circle()
            .stroke(ShuttlXColor.surfaceBorder.opacity(0.3), lineWidth: 1)
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
