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
        }
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
        case "clean":   self.cleanMeshBackground()
        case "mixtape": self.mixtapeBackground()
        default:        self.cleanMeshBackground()
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

                    // Static cassette shell frame: rounded shell-edge stroke + 2 top
                    // corner screws. Drawn once, never animates (the live reel lives
                    // in MixtapeTimerOverlay). reduceDetail drops the screw specular.
                    MixtapeCassetteScene(
                        reduceDetail: ProcessInfo.processInfo.isLowPowerModeEnabled
                    )
                }
                .allowsHitTesting(false)
                .ignoresSafeArea()
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


