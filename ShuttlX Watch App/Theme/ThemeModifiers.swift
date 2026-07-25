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
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 0.690, green: 0.220, blue: 0.180)) // #B0392E labelRule
                            .frame(width: 2.5)
                        Text(label.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(0.1)
                            .foregroundStyle(Color(red: 0.137, green: 0.125, blue: 0.102)) // #23201A labelInk
                            .padding(.leading, 6)
                            .padding(.trailing, 8)
                        Spacer()
                    }
                    .frame(height: 22)
                    .background(Color(red: 0.937, green: 0.906, blue: 0.824)) // #EFE7D2 labelCream
                }
                self.padding(0)
            }
            .background(
                RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.227, green: 0.243, blue: 0.263), // #3A3E43 bodyTop
                            Color(red: 0.141, green: 0.153, blue: 0.169)  // #24272B bodyBase
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            )
            .overlay(RoundedRectangle(cornerRadius: theme.effects.cardCornerRadius).stroke(theme.colors.surfaceBorder.opacity(0.35), lineWidth: 1))
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
                    Color(red: 0.141, green: 0.153, blue: 0.169) // #24272B gunmetal body
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


