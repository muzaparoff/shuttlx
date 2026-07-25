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
                    // Cream tape-label header well with red rule stripe
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

    // MARK: - Mixtape Background (Authentic Cassette Shell)
    //
    // Renders a full-bleed `MixtapeCassetteScene` — a smoke-blue ABS cassette
    // shell with 4 corner screws, hub windows, J-card label well, and tape
    // window strip. This replaces the old generic dark-blue tint.
    //
    // The scene is always "resting" (progress 0, isRunning false) here because
    // `.themedScreenBackground()` has no access to the workout controller.
    // Live spinning reels are drawn by `MixtapeTimerHero` on top during workouts.

    func mixtapeBackground() -> some View {
        self
            .background(
                MixtapeCassetteScene(
                    progress: 0,
                    isRunning: false,
                    reduceDetail: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    showJCard: false,
                    showHubs: false
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
    }

    // Background for the active-workout timer screen. For Mixtape it draws the
    // cassette shell WITHOUT the scene J-card (MixtapeTimerHero owns the J-card
    // on top — drawing the scene's too produced a duplicate strip). All other
    // themes fall through to the standard themed screen background.
    @ViewBuilder
    func timerScreenBackground(themeID: String) -> some View {
        if themeID == "mixtape" {
            self.background(
                MixtapeCassetteScene(
                    progress: 0,
                    isRunning: false,
                    reduceDetail: ProcessInfo.processInfo.isLowPowerModeEnabled,
                    showJCard: false,
                    showHubs: false
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )
        } else {
            self.themedScreenBackground()
        }
    }

}


