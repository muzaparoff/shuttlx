import SwiftUI

// MARK: - Themed Transport Button (watchOS)
//
// Mirror of the iOS `Theme/Components/ThemedTransportButton.swift` per the
// dual-target theme rule. The ONLY differences from the iOS copy are inside the
// Mixtape `spec(for:)`:
//   * `travel: 2`  (vs iOS 3) — smaller screen, shallower mechanical throw reads
//     better at 41mm and avoids the cap clipping into the channel edge.
//   * `haptic: .impact(weight: .medium)` (vs iOS .heavy) — a heavy Taptic pulse
//     feels muddy on the watch motor; medium gives a crisp cassette-key "clunk".
//
// A `ButtonStyle` that reads the active theme and renders a hardware control with
// real pressed state via `configuration.isPressed`. The theme supplies geometry +
// materials through `TransportButtonSpec`, so each theme can draw its own
// key/switch/knob without forking the press physics.
//
// Cassette chrome colors here are explicit hex (the cassette IS the theme — see
// the watch hand-off spec §3 / §1). Non-Mixtape themes route through the `default`
// flat spec (no travel, theme CTA colors) so they render unchanged.

/// Geometry + materials a theme provides for its hardware transport control.
struct TransportButtonSpec: Equatable {
    var cornerRadius: CGFloat
    var travel: CGFloat                // how far the cap sinks when pressed/latched (pt)
    var capTop: Color                  // keycap gradient top
    var capBottom: Color               // keycap gradient bottom
    var channel: Color                 // recessed channel / well color
    var glyph: Color                   // embossed symbol color
    var highlight: Color               // top-edge specular
    var depressLatches: Bool           // PLAY-style latch (stays down while role active)
    var haptic: SensoryFeedback        // press feedback (cassette-key "clunk")
}

enum TransportRole: Equatable {
    case play, pause, stop, rewind, fastForward, skip

    var sfSymbol: String {
        switch self {
        case .play:        return "play.fill"
        case .pause:       return "pause.fill"
        case .stop:        return "stop.fill"
        case .rewind:      return "backward.end.fill"
        case .fastForward: return "forward.fill"
        case .skip:        return "forward.end.fill"
        }
    }
}

struct ThemedTransportButtonStyle: ButtonStyle {
    let role: TransportRole
    var isLatched: Bool = false
    /// When the PLAY key is latched in paused state we want the cap amber, not green.
    var latchedAmber: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spec: TransportButtonSpec { Self.spec(for: ThemeManager.shared.current.id) }

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed || (spec.depressLatches && isLatched)
        let travel = reduceMotion ? 0 : (down ? spec.travel : 0)
        let isMixtape = ThemeManager.shared.current.id == "mixtape"

        // PLAY keycap tints: green (running/up) vs amber (latched-paused).
        let capTop: Color = {
            guard isMixtape, role == .play else { return spec.capTop }
            return latchedAmber ? ShuttlXColor.ctaPause : ShuttlXColor.running
        }()
        let capBottom: Color = {
            guard isMixtape, role == .play else { return spec.capBottom }
            return (latchedAmber ? ShuttlXColor.ctaPause : ShuttlXColor.running).opacity(0.78)
        }()

        return ZStack {
            // Recessed channel / well
            RoundedRectangle(cornerRadius: spec.cornerRadius)
                .fill(spec.channel)

            // Keycap
            configuration.label
                .foregroundStyle(spec.glyph)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: spec.cornerRadius)
                        .fill(LinearGradient(colors: [capTop, capBottom],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: spec.cornerRadius)
                                .fill(spec.highlight.opacity(down ? 0 : 0.6))
                                .frame(height: 2)
                                .padding(.horizontal, 4)
                                .padding(.top, 1)
                        }
                )
                .padding(down ? 2 : 0)        // cap recesses into channel
                .offset(y: travel)
                .shadow(color: .black.opacity(down ? 0.15 : 0.45),
                        radius: down ? 1 : 4, y: down ? 1 : 3)
        }
        .contentShape(Rectangle())
        .frame(minWidth: 48, minHeight: 48)   // watch keycap min, clears 44pt comfortably
        .sensoryFeedback(spec.haptic, trigger: configuration.isPressed)
    }

    static func spec(for themeID: String) -> TransportButtonSpec {
        switch themeID {
        case "mixtape":
            return .init(
                cornerRadius: 8,
                travel: 2,                                                   // watch: shallower than iOS 3
                capTop: Color(red: 0.780, green: 0.800, blue: 0.831),        // keyCapTop  #C7CCD4
                capBottom: Color(red: 0.604, green: 0.631, blue: 0.675),     // keyCapBottom #9AA1AC
                channel: Color(red: 0.055, green: 0.078, blue: 0.125),       // keyChannel #0E1420
                glyph: Color(red: 0.165, green: 0.188, blue: 0.220),         // keyGlyph   #2A3038
                highlight: .white,
                depressLatches: true,
                haptic: .impact(weight: .medium))                            // watch: medium, not heavy
        default: // Clean / fallback: flat, no travel
            return .init(
                cornerRadius: ThemeManager.shared.effects.buttonCornerRadius,
                travel: 0,
                capTop: ThemeManager.shared.colors.ctaPrimary,
                capBottom: ThemeManager.shared.colors.ctaPrimary,
                channel: .clear,
                glyph: ThemeManager.shared.colors.iconOnCTA,
                highlight: .clear,
                depressLatches: false,
                haptic: .selection)
        }
    }
}
