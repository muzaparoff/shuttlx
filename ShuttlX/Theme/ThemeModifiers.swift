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
                    reduceDetail: ProcessInfo.processInfo.isLowPowerModeEnabled
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


