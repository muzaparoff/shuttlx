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

    // MARK: - Synthwave Grid Background

    func synthwaveGrid() -> some View {
        self.background(
            GeometryReader { geo in
                let spacing: CGFloat = 24
                let cols = Int(geo.size.width / spacing) + 1
                let rows = Int(geo.size.height / spacing) + 1
                let gridColor = ThemeManager.shared.effects.neonGlowColor ?? Color.cyan

                Canvas { context, size in
                    // Vertical lines
                    for i in 0...cols {
                        let x = CGFloat(i) * spacing
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(gridColor.opacity(0.08)), lineWidth: 0.5)
                    }
                    // Horizontal lines
                    for j in 0...rows {
                        let y = CGFloat(j) * spacing
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(gridColor.opacity(0.08)), lineWidth: 0.5)
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

    // MARK: - Clean Mesh Background

    func cleanMeshBackground() -> some View {
        self.background(
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    .indigo.opacity(0.15), .blue.opacity(0.08), .purple.opacity(0.1),
                    .blue.opacity(0.05), .clear, .indigo.opacity(0.08),
                    .purple.opacity(0.08), .blue.opacity(0.1), .teal.opacity(0.05)
                ]
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
                    Path(ellipseIn: CGRect(x: sunCenter.x - 60, y: sunCenter.y - 20, width: 120, height: 40)),
                    with: .radialGradient(
                        Gradient(colors: [.pink.opacity(0.6), .cyan.opacity(0.2), .clear]),
                        center: sunCenter, startRadius: 0, endRadius: 80))

                // Perspective grid lines (horizontal)
                for i in 0..<12 {
                    let t = CGFloat(i) / 12.0
                    let y = horizon + (size.height - horizon) * pow(t, 0.7)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.cyan.opacity(0.08)), lineWidth: 0.5)
                }

                // Perspective grid lines (vertical, converging)
                let vanishX = size.width / 2
                for i in -8...8 {
                    let bottomX = vanishX + CGFloat(i) * (size.width / 8)
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
        #if os(watchOS)
        let dotSpacing: CGFloat = 6
        #else
        let dotSpacing: CGFloat = 4
        #endif

        return self
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.07, blue: 0.05)
                    Canvas { context, size in
                        let dotColor = Color.green.opacity(0.03)
                        for x in stride(from: CGFloat(0), to: size.width, by: dotSpacing) {
                            for y in stride(from: CGFloat(0), to: size.height, by: dotSpacing) {
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
                        startRadius: 200,
                        endRadius: 500
                    )
                    Color.green.opacity(0.015)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }
}
