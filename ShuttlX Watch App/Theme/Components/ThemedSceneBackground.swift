import SwiftUI

// MARK: - Themed Scene Background (watchOS)
//
// Mirror of the iOS `Theme/Components/ThemedSceneBackground.swift`, compressed to
// the 41mm budget. On iOS the `MixtapeCassetteScene` draws the FULL cassette shell
// (4 screws, twin hub windows, tape window, J-card well). On watch we draw only the
// STATIC SHELL FRAME: a rounded shell-edge stroke + 2 top corner screws. This is
// enough to read "cassette shell" behind the metrics without stealing the ~180pt
// height budget, and it is drawn ONCE (no TimelineView, no animation).
//
// Per the resolved scene/reel ownership question (iOS option b): the scene is
// INERT — it does NOT know `isRunning` and does NOT draw a reel. The single live
// reel lives in `MixtapeTimerOverlay` (the hero), which draws on top. This keeps
// ThemeManager free of scene/workout state and honors "no idle animation outside
// an active workout" — the shell frame never animates.

/// A full-bleed theme scene. `contentSafeInsets` marks where foreground content
/// must live so screens can inset; on watch the frame is thin so insets are small.
protocol ThemedScene: View {
    var contentSafeInsets: EdgeInsets { get }
}

struct MixtapeCassetteScene: View, ThemedScene {
    /// Reduce Motion / Low Power: omit screw specular highlight and texture lines.
    var reduceDetail: Bool = false

    var contentSafeInsets: EdgeInsets { .init(top: 26, leading: 6, bottom: 28, trailing: 6) }

    // Cassette chrome palette (matches the watch hero + iOS §1 tokens).
    private let shellTop     = Color(red: 0.149, green: 0.188, blue: 0.247)  // #26303F
    private let shellBottom  = Color(red: 0.086, green: 0.118, blue: 0.161)  // #161E29
    private let screwRim     = Color(red: 0.541, green: 0.576, blue: 0.627)  // #8A93A0
    private let screwRecess  = Color(red: 0.227, green: 0.259, blue: 0.314)  // #3A4250
    private let shellEdge    = Color(red: 0.29,  green: 0.42,  blue: 0.60)   // #4A6A9A
    private let tapeWindow   = Color(red: 0.043, green: 0.063, blue: 0.094)  // #0B1018 near-black

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Base plastic fill
                LinearGradient(colors: [shellTop, shellBottom],
                               startPoint: .top, endPoint: .bottom)

                // Horizontal plastic mold lines — 2.5% white, every 4pt
                if !reduceDetail {
                    Canvas { ctx, size in
                        let lineColor = Color.white.opacity(0.025)
                        for y in stride(from: CGFloat(0), to: size.height, by: 4) {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(lineColor), lineWidth: 0.5)
                        }
                    }
                }

                // Shell-edge stroke
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(shellEdge.opacity(0.55), lineWidth: 1)
                    .padding(2)

                // Tape window strip at bottom — dark cut-out implying the
                // tape path between the reels. Height ~18% of screen.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tapeWindow)
                    .frame(width: w * 0.70, height: max(14, h * 0.18))
                    .overlay(
                        // Felt pad accent — a tiny red strip centered in the window
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.72, green: 0.27, blue: 0.23).opacity(0.7))
                            .frame(width: 12, height: 4)
                    )
                    .position(x: w / 2, y: h - h * 0.09)

                // 4 corner screws (all corners — matches the full cassette anatomy)
                screw.position(x: 16,     y: 16)
                screw.position(x: w - 16, y: 16)
                screw.position(x: 16,     y: h - 16)
                screw.position(x: w - 16, y: h - 16)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var screw: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [screwRim, screwRecess],
                                     center: .topLeading, startRadius: 0, endRadius: 8))
            Rectangle()
                .fill(screwRecess)
                .frame(width: 5, height: 1)
            if !reduceDetail {
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 2)
                    .offset(x: -1.5, y: -1.5)
            }
        }
        .frame(width: 8, height: 8)
    }
}
