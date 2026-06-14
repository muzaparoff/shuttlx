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
    /// Reduce Motion / Low Power: omit screw specular highlight (no other effect —
    /// the frame is already static).
    var reduceDetail: Bool = false

    var contentSafeInsets: EdgeInsets { .init(top: 26, leading: 6, bottom: 6, trailing: 6) }

    // Cassette chrome palette (matches the watch hero + iOS §1 tokens).
    private var shellTop: Color { Color(red: 0.149, green: 0.188, blue: 0.247) }    // #26303F
    private var shellBottom: Color { Color(red: 0.086, green: 0.118, blue: 0.161) } // #161E29
    private var screwRim: Color { Color(red: 0.541, green: 0.576, blue: 0.627) }    // #8A93A0
    private var screwRecess: Color { Color(red: 0.227, green: 0.259, blue: 0.314) } // #3A4250
    private var shellEdge: Color { Color(red: 0.29, green: 0.42, blue: 0.60) }      // #4A6A9A deckBorder

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base plastic fill — kept dark so the timer/HR text stays high-contrast.
                LinearGradient(colors: [shellTop, shellBottom],
                               startPoint: .top, endPoint: .bottom)

                // Static shell-edge stroke, inset 2pt — implies the cassette shell rim.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(shellEdge.opacity(0.55), lineWidth: 1)
                    .padding(2)

                // 2 corner screws, top-left + top-right only (save vertical space).
                screw.position(x: 16, y: 16)
                screw.position(x: geo.size.width - 16, y: 16)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// A single recessed screw — radial rim→recess + a slot stroke. Static.
    private var screw: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [screwRim, screwRecess],
                                     center: .topLeading, startRadius: 0, endRadius: 8))
            // Slot
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
