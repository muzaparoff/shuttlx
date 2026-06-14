import SwiftUI

// MARK: - TransportRole

/// The semantic role of a transport control. Used to derive the default SF Symbol.
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

// MARK: - TransportButtonSpec

/// Geometry and material description for a theme's hardware transport key.
///
/// Each theme provides its own spec via `ThemedTransportButtonStyle.spec(for:)`.
/// The press physics (travel, shadow, highlight collapse, haptic) are implemented
/// **once** in `ThemedTransportButtonStyle.makeBody` and never duplicated per theme.
///
/// - `travel`: how far the keycap sinks when pressed, in points. Set to 0
///   for reduce-motion (overridden in the style) or for themes that do not
///   animate depth (e.g. Neovim flat keys).
/// - `depressLatches`: when `true`, `isLatched: true` on the style keeps the
///   cap in the pressed position even when `configuration.isPressed` is `false`.
///   Used for the PLAY latch while tape is running.
/// - `capTopOverride`/`capBottomOverride`: optional per-role cap color overrides.
///   When set, these replace `capTop`/`capBottom` so a specific key (e.g. STOP)
///   can have a distinct cap color without duplicating the entire spec.
/// - `glyphOverride`: optional glyph color override for the same per-role use case.
/// - `proudBoost`: extra shadow radius added at rest to make this key visually lead
///   (used for the PLAY key which should appear slightly more prominent).
struct TransportButtonSpec: Equatable {
    var cornerRadius: CGFloat
    var travel: CGFloat
    var capTop: Color
    var capBottom: Color
    var channel: Color
    var glyph: Color
    var highlight: Color
    var depressLatches: Bool
    var haptic: SensoryFeedback
    var capTopOverride: Color? = nil
    var capBottomOverride: Color? = nil
    var glyphOverride: Color? = nil
    var proudBoost: CGFloat = 0
}

// MARK: - ThemedTransportButtonStyle

/// A `ButtonStyle` that renders a theme-appropriate hardware transport key.
///
/// The style reads the active theme from `ThemeManager.shared` via
/// `spec(for: themeID)` and applies:
/// - A recessed channel well
/// - A keycap with a vertical gradient and a 2-pt top highlight
/// - Press travel: the cap offsets down by `spec.travel` points when pressed
///   (or always, when `isLatched` is true and `spec.depressLatches` is true)
/// - Shadow inversion: elevated at rest, nearly flat when pressed
/// - Haptic feedback on press via `.sensoryFeedback`
///
/// Usage:
/// ```swift
/// Button { /* action */ } label: {
///     Image(systemName: "play.fill")
///         .frame(width: 56, height: 56)
/// }
/// .buttonStyle(ThemedTransportButtonStyle(role: .play, isLatched: !controller.isPaused))
/// .accessibilityLabel("Play")
/// .accessibilityHint("Play transport key")
/// ```
struct ThemedTransportButtonStyle: ButtonStyle {
    let role: TransportRole
    var isLatched: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spec: TransportButtonSpec {
        Self.spec(for: ThemeManager.shared.current.id, role: role)
    }

    func makeBody(configuration: Configuration) -> some View {
        let isDown = configuration.isPressed || (spec.depressLatches && isLatched)
        let travel: CGFloat = reduceMotion ? 0 : (isDown ? spec.travel : 0)
        let highlightOpacity: Double = isDown ? 0 : 0.6

        // Per-role cap color overrides (e.g. STOP = accentBlue cap)
        let resolvedCapTop    = spec.capTopOverride    ?? spec.capTop
        let resolvedCapBottom = spec.capBottomOverride ?? spec.capBottom
        let resolvedGlyph     = spec.glyphOverride     ?? spec.glyph

        // Proud boost for PLAY key: extra shadow radius at rest
        let restShadowRadius: CGFloat = isDown ? 1 : (4 + spec.proudBoost)

        ZStack {
            // Recessed channel / well — inner top-shadow so the keycap sits in a real well
            RoundedRectangle(cornerRadius: spec.cornerRadius)
                .fill(spec.channel)
                .overlay(alignment: .top) {
                    // Channel top-shadow: black band at inner top edge gives depth
                    if spec.channel != .clear {
                        RoundedRectangle(cornerRadius: spec.cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.5), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 4)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: spec.cornerRadius,
                                    topTrailingRadius: spec.cornerRadius
                                )
                            )
                    }
                }

            // Keycap
            configuration.label
                .foregroundStyle(resolvedGlyph)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: spec.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [resolvedCapTop, resolvedCapBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(alignment: .top) {
                            // Domed specular highlight: 4pt band narrowed to 60% width
                            // so the cap reads as convex/domed rather than flat.
                            // Collapses to zero opacity when pressed (key sinks flat).
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: spec.cornerRadius)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                spec.highlight.opacity(highlightOpacity * 0.25),
                                                spec.highlight.opacity(highlightOpacity)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * 0.6,
                                        height: 4
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 1)
                            }
                            .frame(height: 4)
                        }
                )
                // Cap recess: inset grows when pressed so the cap appears to sink
                .padding(isDown ? 2 : 0)
                // Physical travel — cap moves down into the channel
                .offset(y: travel)
                // Shadow: deep at rest (key proud), shallow when pressed (key recessed)
                .shadow(
                    color: .black.opacity(isDown ? 0.15 : 0.45),
                    radius: isDown ? 1 : restShadowRadius,
                    y: isDown ? 1 : 3
                )
        }
        .contentShape(Rectangle())
        // Enforce minimum 44pt hit area regardless of visual keycap size
        .frame(minWidth: 44, minHeight: 44)
        .sensoryFeedback(spec.haptic, trigger: configuration.isPressed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.08), value: isDown)
    }

    // MARK: - Theme Spec Dispatch

    /// Returns the `TransportButtonSpec` for a given theme ID and transport role.
    ///
    /// Currently only "mixtape" has a hardware look. All other themes fall back
    /// to a flat style (0 travel, primary-color fill, no latch depth) so that
    /// other theme screens compile and run without change. As additional themes
    /// adopt their own hardware controls, add cases here.
    ///
    /// Mixtape role variants:
    /// - `.play`: +1pt proud boost (shadow radius 5 vs 4) — PLAY visually leads.
    /// - `.stop`: accentBlue cap + white glyph — STOP is distinct from CANCEL (gray)
    ///   to prevent destructive misfire (belt-and-suspenders alongside the confirm alert).
    static func spec(for themeID: String, role: TransportRole = .play) -> TransportButtonSpec {
        switch themeID {
        case "mixtape":
            // Base Mixtape spec — physical ABS keycap material
            let accentBlue = Color(red: 0.29, green: 0.54, blue: 0.79)   // #4A8ACA
            var base = TransportButtonSpec(
                cornerRadius: 8,
                travel: 3,
                capTop:    Color(red: 0.780, green: 0.800, blue: 0.831), // keyCapTop   #C7CCD4
                capBottom: Color(red: 0.604, green: 0.631, blue: 0.675), // keyCapBottom #9AA1AC
                channel:   Color(red: 0.055, green: 0.078, blue: 0.125), // keyChannel  #0E1420
                glyph:     Color(red: 0.165, green: 0.188, blue: 0.220), // keyGlyph    #2A3038
                highlight: .white,
                depressLatches: true,
                haptic: .impact(weight: .heavy)
            )
            switch role {
            case .play:
                // PLAY latches down; extra shadow radius makes it visually prominent
                base.proudBoost = 1
            case .stop:
                // STOP = accentBlue cap with white glyph — clearly distinct from gray CANCEL.
                // Confirmation alert provides the second safety barrier.
                base.capTopOverride    = accentBlue.opacity(0.9)
                base.capBottomOverride = accentBlue.opacity(0.7)
                base.glyphOverride     = Color.white
            default:
                break
            }
            return base
        default:
            // Flat CTA button for all other themes — same visual shape, no depth
            return TransportButtonSpec(
                cornerRadius: ThemeManager.shared.effects.buttonCornerRadius,
                travel: 0,
                capTop:    ThemeManager.shared.colors.ctaPrimary,
                capBottom: ThemeManager.shared.colors.ctaPrimary,
                channel:   .clear,
                glyph:     ThemeManager.shared.colors.iconOnCTA,
                highlight: .clear,
                depressLatches: false,
                haptic: .selection
            )
        }
    }
}
