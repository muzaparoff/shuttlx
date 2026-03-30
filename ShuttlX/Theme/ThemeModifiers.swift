import SwiftUI

// MARK: - Themed Card (replaces .glassBackground())

extension View {
    @ViewBuilder
    func themedCard(accent: Color? = nil, statusLine: (mode: String, file: String, position: String)? = nil) -> some View {
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
        case .tape:
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
        case .meter:
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
        case .terminal:
            let barWidth = theme.effects.cardAccentBarWidth
            let accentColor = accent ?? theme.colors.ctaPrimary
            VStack(spacing: 0) {
                self.padding(0)
                // Statusline at bottom of card (Neovim-style)
                if let sl = statusLine {
                    TerminalStatusLine(mode: sl.mode, file: sl.file, position: sl.position, modeColor: accentColor)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                    .stroke(theme.colors.surfaceBorder, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if barWidth > 0 {
                    UnevenRoundedRectangle(
                        topLeadingRadius: theme.effects.cardCornerRadius,
                        bottomLeadingRadius: theme.effects.cardCornerRadius
                    )
                    .fill(accentColor)
                    .frame(width: barWidth)
                }
            }
        }
    }

    // MARK: - Theme Mode Tag (Neovim)

    @ViewBuilder
    func themeModeTag(_ text: String) -> some View {
        let theme = ThemeManager.shared
        if theme.effects.cardStyle == .terminal {
            VStack(spacing: 4) {
                Text("-- \(text) --")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.colors.ctaPrimary)
                self
            }
        } else {
            self
        }
    }

    // MARK: - Theme Line Number (Neovim)

    @ViewBuilder
    func themeLineNumber(_ number: Int) -> some View {
        let theme = ThemeManager.shared
        if theme.effects.cardStyle == .terminal {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.314, green: 0.286, blue: 0.271)) // bg2 #504945
                    .frame(width: 14, alignment: .trailing)
                self
            }
        } else {
            self
        }
    }

    // MARK: - Neon Glow (Synthwave)

    func neonGlow(color: Color, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color.opacity(0.3), radius: radius * 0.5)
            .shadow(color: color.opacity(0.15), radius: radius)
    }

    // MARK: - Scanline Overlay (Mixtape)

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

    // MARK: - LCD Panel (Mixtape)

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
        case "clean":        self.cleanMeshBackground()
        case "synthwave":    self.synthwaveHorizonBackground()
        case "mixtape":      self.mixtapeBackground()
        case "arcade":       self.arcadeCRTBackground()
        case "classicradio": self.classicRadioBackground()
        case "vumeter":      self.vuMeterBackground()
        case "neovim":       self.neovimBackground()
        default:             self
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

    // MARK: - Mixtape Background (Portable Player)

    func mixtapeBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.08, blue: 0.13)
                    // Subtle horizontal texture lines (plastic body)
                    Canvas { context, size in
                        let lineColor = Color.white.opacity(0.015)
                        for y in stride(from: CGFloat(0), to: size.height, by: 3) {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                        }
                    }
                    // Blue sheen gradient
                    LinearGradient(
                        colors: [Color.blue.opacity(0.06), .clear, Color.blue.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
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

    // MARK: - Classic Radio Background

    func classicRadioBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.11, green: 0.08, blue: 0.03)
                    // Subtle plastic grain texture
                    Canvas { context, size in
                        let grainColor = Color.white.opacity(0.008)
                        for y in stride(from: CGFloat(0), to: size.height, by: 4) {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(grainColor), lineWidth: 0.5)
                        }
                    }
                    // Warm brown vignette
                    RadialGradient(
                        colors: [Color(red: 0.15, green: 0.10, blue: 0.05).opacity(0.3), .clear],
                        center: .center,
                        startRadius: 100,
                        endRadius: 500
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }

    // MARK: - Neovim Background (Code Editor)

    func neovimBackground() -> some View {
        self.background(
            ZStack {
                Color(red: 0.114, green: 0.125, blue: 0.129) // #1D2021
                // Subtle left gutter stripe (sign column)
                HStack(spacing: 0) {
                    Color(red: 0.235, green: 0.220, blue: 0.212).opacity(0.08) // bg1
                        .frame(width: 24)
                    Spacer()
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        )
    }

    // MARK: - VU Meter Background

    func vuMeterBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.10, green: 0.09, blue: 0.06)
                    // Horizontal panel lines
                    Canvas { context, size in
                        let lineColor = Color(red: 0.91, green: 0.63, blue: 0.19).opacity(0.02)
                        for y in stride(from: CGFloat(0), to: size.height, by: 6) {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                        }
                    }
                    // Amber radial glow
                    RadialGradient(
                        colors: [Color(red: 0.91, green: 0.63, blue: 0.19).opacity(0.06), .clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 400
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }
}

// MARK: - Terminal Status Line (Neovim)

struct TerminalStatusLine: View {
    let mode: String
    let file: String
    let position: String
    var modeColor: Color = Color(red: 0.722, green: 0.733, blue: 0.149) // Gruvbox green

    var body: some View {
        HStack(spacing: 0) {
            Text(mode)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.157, green: 0.157, blue: 0.157)) // bg0
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(modeColor)

            Text(file)
                .font(.system(size: 7, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.659, green: 0.600, blue: 0.518)) // fg4 #A89984
                .padding(.horizontal, 6)
                .frame(height: 16, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.235, green: 0.220, blue: 0.212)) // bg1

            Text(position)
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.922, green: 0.859, blue: 0.698)) // fg
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(Color(red: 0.314, green: 0.286, blue: 0.271)) // bg2
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: ThemeManager.shared.effects.cardCornerRadius,
                bottomTrailingRadius: ThemeManager.shared.effects.cardCornerRadius
            )
        )
    }
}
