import SwiftUI

// MARK: - MixtapeLayoutConstants
// Single source of truth for hub window positions shared by both the resting
// scene (MixtapeCassetteScene) and the live hero overlay (MixtapeTimerHero).
// Both files reference these constants so the live reels always sit exactly
// over the static bezel rings regardless of screen width.
enum MixtapeLayoutConstants {
    /// Fractional x positions of the supply (0) and take-up (1) hub centers,
    /// expressed as a fraction of the full scene width.
    static let hubCenterXFractions: (CGFloat, CGFloat) = (0.30, 0.70)
    /// Fractional y position of both hub centers, expressed as a fraction of
    /// the full scene height.
    static let hubCenterYFraction: CGFloat = 0.42
    /// Visual diameter of the live reel clip circle, matching the bezel ring.
    static let hubDiameter: CGFloat = 96
}

// MARK: - ThemedScene Protocol

/// Contract for a full-bleed "hardware scene" background view.
///
/// Each theme that adopts the authentic-hardware design pattern implements
/// this protocol for its scene composition (cassette shell, arcade cabinet,
/// radio housing, etc.). The `contentSafeInsets` property tells overlay views
/// (heroes, metric cards) where to inset their content so it lands on the
/// theme's "screen" or "label" area.
///
/// Plumbing note (option B): `ThemedScene` views are "resting" globally —
/// progress and isRunning state are NOT published through ThemeManager. The
/// live spinning reels and PLAY-latch are managed exclusively inside
/// `MixtapeTimerHero`, which is only visible during an active workout session.
/// This keeps ThemeManager free of workout-state creep.
protocol ThemedScene: View {
    /// The inset region where foreground content (counters, metric cards) should live.
    /// E.g. the J-card label area for Mixtape; the LCD panel for FM Tuner.
    var contentSafeInsets: EdgeInsets { get }
}

// MARK: - MixtapeCassetteScene

/// Full-bleed cassette shell scene for the Mixtape theme.
///
/// Renders the physical anatomy of an audio cassette:
/// - Smoke-blue ABS shell (RoundedRectangle, vertical gradient)
/// - Horizontal plastic mold lines (Canvas, white 2.5%)
/// - 4 corner screws (Circle + Phillips slot, radial gradient)
/// - Write-protect tab wells (top edge)
/// - J-card label well (cream paper, SIDE A box, baseline rule)
/// - 2 hub windows (circular bezel cut-outs; reel content is NOT drawn here —
///   the hero draws its own live reels on top when a workout is active)
/// - Tape window strip with felt pad accent (bottom section)
/// - Bottom brand strip
///
/// **Resting state (default):** `progress = 0`, `isRunning = false`.
/// The scene draws only the static shell. The timer hero (`MixtapeTimerHero`)
/// draws live spinning reels on top during an active session.
///
/// **Reduce Detail:** when `reduceDetail` is true (Reduce Motion or Low Power),
/// screws are drawn without the specular highlight dot and corner chrome
/// is simplified.
struct MixtapeCassetteScene: View, ThemedScene {

    var progress: Double = 0          // 0…1; drives oxide distribution on reel thumbnails (static)
    var isRunning: Bool = false       // reserved for future live-reel plumbing (currently unused here)
    var reduceDetail: Bool = false    // Reduce Motion / Low Power — flatten specular chrome
    // Timer screen suppresses the scene J-card: MixtapeTimerHero draws its own
    // J-card on top, so drawing the scene's too would show a duplicate strip.
    var showJCard: Bool = true

    /// The safe region where content (J-card label, hero metrics) must live.
    var contentSafeInsets: EdgeInsets {
        EdgeInsets(top: 96, leading: 28, bottom: 150, trailing: 28)
    }

    // MARK: - Cassette palette (hard-wired — this IS the Mixtape theme definition)

    private let shellTop        = Color(red: 0.149, green: 0.188, blue: 0.247) // #26303F
    private let shellBottom     = Color(red: 0.086, green: 0.118, blue: 0.161) // #161E29
    private let moldLine        = Color.white.opacity(0.025)
    private let screwRim        = Color(red: 0.541, green: 0.576, blue: 0.627) // #8A93A0
    private let screwRecess     = Color(red: 0.227, green: 0.259, blue: 0.314) // #3A4250
    private let hubWindowBezel  = Color(red: 0.055, green: 0.078, blue: 0.125) // #0E1420
    private let labelPaper      = Color(red: 0.929, green: 0.906, blue: 0.827) // #EDE7D3
    private let labelInk        = Color(red: 0.110, green: 0.137, blue: 0.188) // #1C2330
    private let feltPad         = Color(red: 0.722, green: 0.271, blue: 0.227) // #B8453A
    private let brandText       = Color(red: 0.541, green: 0.676, blue: 0.800) // #8CADCC
    private let tabWell         = Color(red: 0.043, green: 0.063, blue: 0.094) // #0B1018
    private let lcdGreen        = Color(red: 0.22,  green: 1.0,  blue: 0.08)   // #39FF14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // ── Shell body ────────────────────────────────────────────────
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [shellTop, shellBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // ── Horizontal mold lines ─────────────────────────────────────
                Canvas { ctx, size in
                    let lineSpacing: CGFloat = 8
                    var y: CGFloat = 0
                    while y < size.height {
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(moldLine), lineWidth: 1)
                        y += lineSpacing
                    }
                }
                .allowsHitTesting(false)

                // ── 4 corner screws ───────────────────────────────────────────
                let screwPositions: [(id: String, point: CGPoint)] = [
                    ("tl", CGPoint(x: 20,     y: 20)),
                    ("tr", CGPoint(x: w - 20, y: 20)),
                    ("bl", CGPoint(x: 20,     y: h - 20)),
                    ("br", CGPoint(x: w - 20, y: h - 20))
                ]
                ForEach(screwPositions, id: \.id) { item in
                    screwView(center: item.point, reduceDetail: reduceDetail)
                }

                // ── Write-protect tab wells (top edge) ────────────────────────
                writeProtectWell
                    .position(x: w * 0.30, y: 28)
                writeProtectWell
                    .position(x: w * 0.70, y: 28)

                // ── J-card label well ─────────────────────────────────────────
                if showJCard {
                    jCardLabel(width: w)
                        .frame(width: w - 56)
                        .position(x: w / 2, y: h * 0.28)
                }

                // ── Hub windows (circular bezel cut-outs) ─────────────────────
                // The static bezel rings are drawn here.
                // Live reels are drawn ON TOP by MixtapeTimerHero during workouts.
                hubWindowBezelView(diameter: MixtapeLayoutConstants.hubDiameter)
                    .position(x: w * MixtapeLayoutConstants.hubCenterXFractions.0,
                              y: h * MixtapeLayoutConstants.hubCenterYFraction)
                hubWindowBezelView(diameter: MixtapeLayoutConstants.hubDiameter)
                    .position(x: w * MixtapeLayoutConstants.hubCenterXFractions.1,
                              y: h * MixtapeLayoutConstants.hubCenterYFraction)

                // Static reel placeholders (resting oxide distribution)
                staticReelThumbnail(isSupply: true, progress: progress)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .position(x: w * MixtapeLayoutConstants.hubCenterXFractions.0,
                              y: h * MixtapeLayoutConstants.hubCenterYFraction)
                    .allowsHitTesting(false)

                staticReelThumbnail(isSupply: false, progress: progress)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .position(x: w * MixtapeLayoutConstants.hubCenterXFractions.1,
                              y: h * MixtapeLayoutConstants.hubCenterYFraction)
                    .allowsHitTesting(false)

                // ── Tape window strip (head contact area) ─────────────────────
                tapeWindowStrip(width: w)
                    .frame(width: w - 56, height: 32)
                    .position(x: w / 2, y: h * 0.74)

                // ── Bottom brand strip ─────────────────────────────────────────
                brandStrip(width: w)
                    .frame(width: w - 60)
                    .position(x: w / 2, y: h - 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Sub-views

    /// Single Phillips screw with radial gradient and slot cross.
    @ViewBuilder
    private func screwView(center: CGPoint, reduceDetail: Bool) -> some View {
        ZStack {
            // Rim circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [screwRim, screwRecess],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 12, height: 12)

            // Phillips slot (cross)
            Canvas { ctx, size in
                let cx = size.width / 2
                let cy = size.height / 2
                let slotLen: CGFloat = 4

                // Horizontal slot
                var h = Path()
                h.move(to: CGPoint(x: cx - slotLen, y: cy))
                h.addLine(to: CGPoint(x: cx + slotLen, y: cy))
                ctx.stroke(h, with: .color(screwRecess), lineWidth: 1.2)

                // Vertical slot
                var v = Path()
                v.move(to: CGPoint(x: cx, y: cy - slotLen))
                v.addLine(to: CGPoint(x: cx, y: cy + slotLen))
                ctx.stroke(v, with: .color(screwRecess), lineWidth: 1.2)
            }
            .frame(width: 12, height: 12)

            // Top-left specular dot (omit when reduceDetail)
            if !reduceDetail {
                Circle()
                    .fill(Color.white.opacity(0.40))
                    .frame(width: 3, height: 3)
                    .offset(x: -2, y: -2)
            }
        }
        .position(center)
        .allowsHitTesting(false)
    }

    /// Small square write-protect tab recess.
    private var writeProtectWell: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(tabWell)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
            .frame(width: 10, height: 6)
            .allowsHitTesting(false)
    }

    /// J-card cream paper label well with SIDE A box, baseline rule, and placeholder title area.
    /// Includes laid-paper horizontal line texture + diagonal corner crease marks (P2-2).
    @ViewBuilder
    private func jCardLabel(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Cream paper fill with top-edge inner shadow
            RoundedRectangle(cornerRadius: 6)
                .fill(labelPaper)
                .overlay(alignment: .top) {
                    // Inner shadow on top edge
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 6)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 6,
                                topTrailingRadius: 6
                            )
                        )
                }

            // Laid-paper horizontal line texture — every 4pt, ink 2.5%
            // Pattern borrowed from ClassicRadioTimerFrame brushed-metal Canvas.
            Canvas { ctx, size in
                let lineColor = labelInk.opacity(0.025)
                var y: CGFloat = 0
                while y < size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
                    y += 4
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)

            // Aged-paper corner crease marks (top-left + bottom-right)
            Canvas { ctx, size in
                let crease = labelInk.opacity(0.12)
                let len: CGFloat = 10
                // top-left crease
                var tl = Path()
                tl.move(to: CGPoint(x: 2, y: 2 + len))
                tl.addLine(to: CGPoint(x: 2 + len, y: 2))
                ctx.stroke(tl, with: .color(crease), lineWidth: 1)
                // bottom-right crease
                var br = Path()
                br.move(to: CGPoint(x: size.width - 2, y: size.height - 2 - len))
                br.addLine(to: CGPoint(x: size.width - 2 - len, y: size.height - 2))
                ctx.stroke(br, with: .color(crease), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                // SIDE A box + REC dot row
                HStack(spacing: 6) {
                    Text("SIDE A")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(labelInk)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(labelInk.opacity(0.5), lineWidth: 1)
                        )

                    // Passive REC dot (active pulsing version lives in hero)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.20, blue: 0.20).opacity(0.7))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.20, blue: 0.20).opacity(0.3),
                                        lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                }

                // Ruled baseline (the hero draws the title on this area)
                Rectangle()
                    .fill(labelInk.opacity(0.25))
                    .frame(height: 1)
                    .padding(.horizontal, 2)
            }
            .padding(8)
        }
        .frame(height: 56)
    }

    /// Circular bezel ring representing a hub window cut-out.
    /// Lit correctly: concave cut-out reads bright at top (light hits the rim face),
    /// dark at bottom (shadowed). ABS rim ring adds plastic depth.
    @ViewBuilder
    private func hubWindowBezelView(diameter: CGFloat) -> some View {
        ZStack {
            // ABS rim ring — plastic bezel just outside the window, top-lit
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: diameter + 4, height: diameter + 4)

            // Dark bezel ring (the window frame itself)
            Circle()
                .fill(hubWindowBezel)
                .frame(width: diameter, height: diameter)

            // Concave inset shadow — top bright (0.6) fades to near-clear at bottom (0.15)
            // This is the correct orientation for a cut-out: rim face lit by overhead light,
            // floor of the well in shadow.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: diameter, height: diameter)

            // Faint topLeading translucency highlight — polycarbonate surface glint
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: diameter * 0.35, height: diameter * 0.35)
                .offset(x: -diameter * 0.22, y: -diameter * 0.22)
        }
        .allowsHitTesting(false)
    }

    /// Static reel thumbnail for resting state (no animation).
    @ViewBuilder
    private func staticReelThumbnail(isSupply: Bool, progress: Double) -> some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2

            let maxOuter: CGFloat = min(size.width, size.height) * 0.46
            let minOuter: CGFloat = maxOuter * 0.42

            let outerRadius: CGFloat = {
                if isSupply {
                    return maxOuter - CGFloat(progress) * (maxOuter - minOuter)
                } else {
                    return minOuter + CGFloat(progress) * (maxOuter - minOuter)
                }
            }()
            let hubRadius  = maxOuter * 0.22
            let tapeRadius = outerRadius * 0.75

            let panelBlue = Color(red: 0.10, green: 0.19, blue: 0.38)
            let borderBlue = Color(red: 0.29, green: 0.42, blue: 0.60)
            let reelDark = Color(red: 0.06, green: 0.06, blue: 0.08)

            // Tape ring
            ctx.fill(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - outerRadius, y: cy - outerRadius,
                                            width: outerRadius * 2, height: outerRadius * 2))
                },
                with: .color(Color(red: 0.20, green: 0.14, blue: 0.06).opacity(0.95))
            )
            ctx.stroke(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - outerRadius, y: cy - outerRadius,
                                            width: outerRadius * 2, height: outerRadius * 2))
                },
                with: .color(borderBlue.opacity(0.5)), lineWidth: 1.2
            )

            // Window ring
            ctx.fill(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - tapeRadius, y: cy - tapeRadius,
                                            width: tapeRadius * 2, height: tapeRadius * 2))
                },
                with: .color(panelBlue.opacity(0.90))
            )

            // 6 spokes
            for i in 0..<6 {
                let angle = Double(i) * 60.0 * .pi / 180.0
                var spoke = Path()
                spoke.move(to: CGPoint(x: cx + CGFloat(cos(angle)) * hubRadius,
                                       y: cy + CGFloat(sin(angle)) * hubRadius))
                spoke.addLine(to: CGPoint(x: cx + CGFloat(cos(angle)) * tapeRadius * 0.88,
                                          y: cy + CGFloat(sin(angle)) * tapeRadius * 0.88))
                ctx.stroke(spoke, with: .color(borderBlue.opacity(0.7)), lineWidth: 2.5)
            }

            // Hub
            ctx.fill(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - hubRadius, y: cy - hubRadius,
                                            width: hubRadius * 2, height: hubRadius * 2))
                },
                with: .color(reelDark)
            )
            ctx.stroke(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - hubRadius, y: cy - hubRadius,
                                            width: hubRadius * 2, height: hubRadius * 2))
                },
                with: .color(borderBlue.opacity(0.8)), lineWidth: 1.5
            )

            // Spindle
            let spindleR: CGFloat = hubRadius * 0.30
            ctx.fill(
                Path { p in
                    p.addEllipse(in: CGRect(x: cx - spindleR, y: cy - spindleR,
                                            width: spindleR * 2, height: spindleR * 2))
                },
                with: .color(borderBlue)
            )
        }
    }

    /// Tape window strip with felt pad accent.
    @ViewBuilder
    private func tapeWindowStrip(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.04, green: 0.07, blue: 0.10).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0.29, green: 0.42, blue: 0.60).opacity(0.4), lineWidth: 1)
                )

            // Felt pad accent on leading edge
            Capsule()
                .fill(feltPad)
                .frame(width: 6, height: 20)
                .padding(.leading, 4)
        }
        .allowsHitTesting(false)
    }

    /// Bottom brand strip label — generic cassette vocabulary, no trademarks.
    @ViewBuilder
    private func brandStrip(width: CGFloat) -> some View {
        HStack {
            Text("IEC TYPE II")
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(brandText.opacity(0.5))
                .tracking(1.5)
            Spacer()
            Text("HIGH BIAS · 90")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(brandText.opacity(0.5))
                .tracking(1.0)
            Spacer()
            Text("C-90 · 90 MIN")
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .foregroundStyle(brandText.opacity(0.5))
                .tracking(1.5)
        }
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Cassette Scene — Resting") {
    MixtapeCassetteScene(progress: 0, isRunning: false, reduceDetail: false)
        .ignoresSafeArea()
}

#Preview("Cassette Scene — Mid Progress") {
    MixtapeCassetteScene(progress: 0.6, isRunning: false, reduceDetail: false)
        .ignoresSafeArea()
}
#endif
