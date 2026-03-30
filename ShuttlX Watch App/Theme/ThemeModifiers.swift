import SwiftUI

// MARK: - Themed Card (replaces .glassBackground())

extension View {
    @ViewBuilder
    func themedCard(
        accent: Color? = nil,
        statusLine: (mode: String, file: String, position: String)? = nil,
        headerLabel: String? = nil,
        footerLabel: String? = nil
    ) -> some View {
        let theme = ThemeManager.shared
        switch theme.effects.cardStyle {
        case .glass:
            self.glassBackground(cornerRadius: theme.effects.cardCornerRadius)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.1),
                                    .init(color: .white.opacity(0.12), location: 0.3),
                                    .init(color: .white.opacity(0.2), location: 0.5),
                                    .init(color: .white.opacity(0.12), location: 0.7),
                                    .init(color: .clear, location: 0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 8)
                        .clipped()
                }
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
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [.clear, theme.effects.neonGlowColor ?? .cyan, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .shadow(color: (theme.effects.neonGlowColor ?? .cyan).opacity(0.6), radius: 4)
                    .padding(.horizontal, 12)
                    .padding(.top, 1)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color(red: 1.0, green: 0.18, blue: 0.58).opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 1)
                }
        case .lcd:
            VStack(spacing: 0) {
                if let label = headerLabel {
                    CassetteHeaderView(label: label)
                }
                self.padding(0)
                if headerLabel != nil {
                    ReelCounterView()
                }
            }
            .background(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).fill(theme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).stroke(theme.colors.surfaceBorder, lineWidth: 1))
        case .pixel:
            VStack(spacing: 0) {
                if let label = headerLabel {
                    ArcadeScoreHeader(label: label)
                }
                self.padding(0)
                if headerLabel != nil {
                    ArcadeCreditFooter(label: footerLabel ?? "CREDIT 0")
                }
            }
            .background(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).fill(theme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).stroke(theme.colors.surfaceBorder, lineWidth: 2))
        case .tape:
            VStack(spacing: 0) {
                if headerLabel != nil { RadioDialHeader() }
                self.padding(0)
                if headerLabel != nil { RadioBandFooter() }
            }
            .background(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).fill(theme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).stroke(theme.colors.surfaceBorder, lineWidth: 1))
        case .meter:
            VStack(spacing: 0) {
                if headerLabel != nil { VUGaugeHeader() }
                self.padding(0)
                if headerLabel != nil { VUScaleFooter() }
            }
            .background(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).fill(theme.colors.surface))
            .overlay(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).stroke(theme.colors.surfaceBorder, lineWidth: 1))
        case .terminal:
            let barWidth = theme.effects.cardAccentBarWidth
            let accentColor = accent ?? theme.colors.ctaPrimary
            VStack(spacing: 0) {
                self.padding(0)
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
                    .foregroundStyle(Color(red: 0.314, green: 0.286, blue: 0.271))
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

    // MARK: - Mixtape Background (Portable Player)

    func mixtapeBackground() -> some View {
        self
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.08, blue: 0.13)
                    // Subtle horizontal texture lines (plastic body)
                    Canvas { context, size in
                        let lineColor = Color.white.opacity(0.015)
                        for y in stride(from: CGFloat(0), to: size.height, by: 4) {
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
                        startRadius: 100,
                        endRadius: 250
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
                    // Subtle grain texture
                    Canvas { context, size in
                        let grainColor = Color.white.opacity(0.008)
                        for y in stride(from: CGFloat(0), to: size.height, by: 5) {
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
                        startRadius: 50,
                        endRadius: 200
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }

    // MARK: - Neovim Background (Code Editor)

    func neovimBackground() -> some View {
        self.background(
            Color(red: 0.114, green: 0.125, blue: 0.129) // #1D2021
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
                        startRadius: 30,
                        endRadius: 200
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
    var modeColor: Color = Color(red: 0.722, green: 0.733, blue: 0.149)

    var body: some View {
        HStack(spacing: 0) {
            Text(mode)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.157, green: 0.157, blue: 0.157))
                .padding(.horizontal, 4)
                .frame(height: 14)
                .background(modeColor)

            Text(file)
                .font(.system(size: 6, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.659, green: 0.600, blue: 0.518))
                .padding(.horizontal, 4)
                .frame(height: 14, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.235, green: 0.220, blue: 0.212))

            Text(position)
                .font(.system(size: 7, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(red: 0.922, green: 0.859, blue: 0.698))
                .padding(.horizontal, 4)
                .frame(height: 14)
                .background(Color(red: 0.314, green: 0.286, blue: 0.271))
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: ThemeManager.shared.effects.cardCornerRadius,
                bottomTrailingRadius: ThemeManager.shared.effects.cardCornerRadius
            )
        )
    }
}

// MARK: - Cassette Header (Mixtape)

struct CassetteHeaderView: View {
    let label: String

    var body: some View {
        HStack {
            HStack(spacing: 3) {
                Text("A")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(ThemeManager.shared.colors.surfaceBorder.opacity(0.3))
                    .cornerRadius(2)
                Text(label)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
            }
            Spacer()
            Text("IEC TYPE II")
                .font(.system(size: 6, weight: .regular, design: .monospaced))
        }
        .foregroundStyle(ThemeManager.shared.colors.surfaceBorder)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ThemeManager.shared.colors.surfaceBorder.opacity(0.08))
    }
}

// MARK: - Reel Counter (Mixtape)

struct ReelCounterView: View {
    var body: some View {
        HStack {
            Text("◀◀ REW")
            Spacer()
            Text("0000:00")
                .foregroundStyle(ThemeManager.shared.colors.ctaPrimary)
            Spacer()
            Text("FF ▶▶")
        }
        .font(.system(size: 7, weight: .medium, design: .monospaced))
        .foregroundStyle(ThemeManager.shared.colors.surfaceBorder.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ThemeManager.shared.colors.surfaceBorder.opacity(0.15))
                .frame(height: 1)
        }
    }
}

// MARK: - Arcade Score Header

struct ArcadeScoreHeader: View {
    let label: String

    var body: some View {
        HStack {
            Text("SCORE")
                .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.0))
            Spacer()
            Text(label)
                .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.0))
        }
        .font(.system(size: 8, weight: .heavy, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.15))
                .frame(height: 1)
        }
    }
}

// MARK: - Arcade Credit Footer

struct ArcadeCreditFooter: View {
    var label: String = "CREDIT 0"

    var body: some View {
        Text(label)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .overlay(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.1))
                    .frame(height: 1)
            }
    }
}

// MARK: - Radio Dial Header (Classic Radio)

struct RadioDialHeader: View {
    private let amberColor = Color(red: 0.95, green: 0.80, blue: 0.50)
    private let separatorColor = Color(red: 0.55, green: 0.46, blue: 0.31)

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(amberColor.opacity(0.4))
                .frame(width: 4, height: 4)
            dialScale()
            // Needle
            RoundedRectangle(cornerRadius: 1)
                .fill(amberColor.opacity(0.7))
                .frame(width: 3, height: 10)
            dialScale()
            Circle()
                .fill(amberColor.opacity(0.4))
                .frame(width: 4, height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(separatorColor.opacity(0.3))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func dialScale() -> some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(amberColor.opacity(0.2))
                    .frame(height: 1)
                HStack(spacing: 0) {
                    ForEach(0..<Int(geo.size.width / 8), id: \.self) { _ in
                        Rectangle()
                            .fill(amberColor.opacity(0.15))
                            .frame(width: 1, height: 5)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }
}

// MARK: - Radio Band Footer (Classic Radio)

struct RadioBandFooter: View {
    private let amberColor = Color(red: 0.95, green: 0.80, blue: 0.50)
    private let separatorColor = Color(red: 0.55, green: 0.46, blue: 0.31)

    var body: some View {
        HStack {
            Text("AM")
                .foregroundStyle(amberColor.opacity(0.3))
            Spacer()
            Text("FM 103.5")
                .foregroundStyle(amberColor.opacity(0.6))
                .fontWeight(.bold)
        }
        .font(.system(size: 7, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(separatorColor.opacity(0.2))
                .frame(height: 1)
        }
    }
}

// MARK: - VU Gauge Header

struct VUGaugeHeader: View {
    private let amberColor = Color(red: 0.91, green: 0.63, blue: 0.19)

    var body: some View {
        HStack(spacing: 3) {
            Text("L")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(amberColor.opacity(0.5))
                .frame(width: 12)
            HStack(spacing: 1) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(segmentColor(for: i))
                        .frame(width: 3, height: 8)
                }
            }
            Text("-3dB")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(amberColor.opacity(0.6))
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(amberColor.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if index < 7 {
            return Color(red: 0.55, green: 0.76, blue: 0.29)   // green
        } else if index < 10 {
            return Color(red: 1.0, green: 0.76, blue: 0.03)    // yellow
        } else if index < 12 {
            return Color(red: 0.96, green: 0.26, blue: 0.21)   // red
        } else {
            return amberColor.opacity(0.08)                      // unlit
        }
    }
}

// MARK: - VU Scale Footer

struct VUScaleFooter: View {
    private let amberColor = Color(red: 0.91, green: 0.63, blue: 0.19)
    private let marks = ["-20", "-10", "-7", "-5", "-3", "0", "+3"]

    var body: some View {
        HStack {
            ForEach(Array(marks.enumerated()), id: \.offset) { index, mark in
                Text(mark)
                if index < marks.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.system(size: 6, weight: .regular, design: .monospaced))
        .foregroundStyle(amberColor.opacity(0.25))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(amberColor.opacity(0.08))
                .frame(height: 1)
        }
    }
}
