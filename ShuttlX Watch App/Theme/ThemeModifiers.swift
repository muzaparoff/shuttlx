import SwiftUI

// MARK: - Themed Card (replaces .glassBackground())

extension View {
    @ViewBuilder
    func themedCard() -> some View {
        let theme = ThemeManager.shared
        switch theme.effects.cardStyle {
        case .glass:
            self.glassBackground(cornerRadius: theme.effects.cardCornerRadius)
        case .neon:
            self
                .padding(0)
                .background(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .fill(theme.colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .stroke(theme.colors.surfaceBorder, lineWidth: 1)
                )
                .neonGlow(
                    color: theme.effects.neonGlowColor ?? .clear,
                    radius: 8
                )
        case .lcd:
            self
                .padding(0)
                .background(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .fill(theme.colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .stroke(theme.colors.surfaceBorder, lineWidth: 1)
                )
        case .pixel:
            self
                .padding(0)
                .background(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .fill(theme.colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .stroke(theme.colors.surfaceBorder, lineWidth: 2)
                )
        }
    }

    // MARK: - Neon Glow (Synthwave)

    func neonGlow(color: Color, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color.opacity(0.3), radius: radius * 0.5)
            .shadow(color: color.opacity(0.15), radius: radius)
    }

    // MARK: - Scanline Overlay (Casio)

    func scanlineOverlay(opacity: Double = 0.05) -> some View {
        self.overlay(
            GeometryReader { geo in
                let lineCount = Int(geo.size.height / 3)
                VStack(spacing: 1) {
                    ForEach(0..<lineCount, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(opacity))
                            .frame(height: 1)
                        Spacer(minLength: 1)
                    }
                }
            }
            .allowsHitTesting(false)
        )
    }

    // MARK: - LCD Panel (Casio)

    func lcdPanel() -> some View {
        let theme = ThemeManager.shared
        return self
            .background(
                RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                    .fill(theme.colors.surface)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                    .strokeBorder(theme.colors.surfaceBorder, lineWidth: 1)
            )
    }

    // MARK: - Themed Screen Background (master switch)

    @ViewBuilder
    func themedScreenBackground() -> some View {
        let theme = ThemeManager.shared
        switch theme.current.id {
        case "clean":     self.cleanMeshBackground()
        case "synthwave": self.synthwaveHorizonBackground()
        case "casio":     self.casioLCDBackground()
        case "arcade":    self.arcadeCRTBackground()
        default:          self
        }
    }

    // MARK: - Clean Mesh Background (watchOS: simplified gradient fallback)

    func cleanMeshBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    .indigo.opacity(0.12),
                    .blue.opacity(0.06),
                    .purple.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Synthwave Horizon Background

    func synthwaveHorizonBackground() -> some View {
        self.background(
            Canvas { context, size in
                let horizon = size.height * 0.45

                // Sky gradient
                let skyRect = CGRect(x: 0, y: 0, width: size.width, height: horizon)
                context.fill(Path(skyRect), with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.06),
                        Color(red: 0.04, green: 0.04, blue: 0.10)
                    ]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

                // Sun glow at horizon
                let sunCenter = CGPoint(x: size.width / 2, y: horizon)
                context.fill(
                    Path(ellipseIn: CGRect(x: sunCenter.x - 40, y: sunCenter.y - 14, width: 80, height: 28)),
                    with: .radialGradient(
                        Gradient(colors: [.pink.opacity(0.6), .cyan.opacity(0.2), .clear]),
                        center: sunCenter, startRadius: 0, endRadius: 50))

                // Perspective grid lines (horizontal) — fewer on watch
                for i in 0..<8 {
                    let t = CGFloat(i) / 8.0
                    let y = horizon + (size.height - horizon) * pow(t, 0.7)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.cyan.opacity(0.08)), lineWidth: 0.5)
                }

                // Perspective grid lines (vertical, converging) — fewer on watch
                let vanishX = size.width / 2
                for i in -4...4 {
                    let bottomX = vanishX + CGFloat(i) * (size.width / 4)
                    var path = Path()
                    path.move(to: CGPoint(x: vanishX, y: horizon))
                    path.addLine(to: CGPoint(x: bottomX, y: size.height))
                    context.stroke(path, with: .color(.cyan.opacity(0.06)), lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Casio LCD Background

    func casioLCDBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.07, blue: 0.05)
                    Canvas { context, size in
                        let dotColor = Color.green.opacity(0.03)
                        // Wider spacing on watch for performance
                        let spacing: CGFloat = 6
                        for x in stride(from: CGFloat(0), to: size.width, by: spacing) {
                            for y in stride(from: CGFloat(0), to: size.height, by: spacing) {
                                context.fill(
                                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                    with: .color(dotColor))
                            }
                        }
                    }
                    LinearGradient(
                        colors: [.white.opacity(0.04), .white.opacity(0.01), .clear],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.6, y: 0.4)
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }

    // MARK: - Arcade CRT Background

    func arcadeCRTBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.06, green: 0.06, blue: 0.18)
                    Canvas { context, size in
                        for y in stride(from: CGFloat(0), to: size.height, by: 2) {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(.black.opacity(0.04)), lineWidth: 1)
                        }
                    }
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        center: .center,
                        startRadius: 100,
                        endRadius: 250
                    )
                    Color.green.opacity(0.015)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }
}
