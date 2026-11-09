import SwiftUI
import WatchKit
import ShuttlXShared

/// Mockup px -> points. The timeline mockup draws a 238pt-tall screen (~45mm);
/// every size is that px value scaled by this watch's own height, so 40mm and
/// 46mm keep the mockup's proportions. Sizes are solved up front, never
/// `minimumScaleFactor`-ed (see .claude/rules/watchos.md).
enum WatchScale {
    static let height = WKInterfaceDevice.current().screenBounds.height
    static let width = WKInterfaceDevice.current().screenBounds.width
    static func pt(_ mockupPx: CGFloat) -> CGFloat { (mockupPx / 238 * height).rounded() }
    /// Readable floor for text on the smallest watch (40mm scales mockup 11px to 9pt).
    static let minTextSize: CGFloat = 10
    /// `pt` for a text size, never below `minTextSize`.
    static func text(_ mockupPx: CGFloat) -> CGFloat { max(minTextSize, pt(mockupPx)) }
}

/// Full-width rounded pill used by every watch prompt (Continue, End & Save,
/// Resume, Done, OK, Pause). Never below the 44pt touch target.
struct WatchPillButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color
    /// Liquid Glass on watchOS 26+ (`secondaryGlass`); secondary actions only.
    var glass = false

    static var primary: WatchPillButtonStyle { .init(fill: ShuttlXColor.ctaPrimary, text: ShuttlXColor.iconOnCTA) }
    /// Dark-red fill + red text: destructive but calm (mockup #3a1512 / #FF6961).
    static var endAndSave: WatchPillButtonStyle { .init(fill: ShuttlXColor.ctaDestructive.opacity(0.24), text: ShuttlXColor.ctaDestructive) }
    static var neutral: WatchPillButtonStyle { .init(fill: ShuttlXColor.watchCardBackground, text: ShuttlXColor.textPrimary) }
    /// D5: "Keep going", "Skip". Safety actions keep the solid styles above.
    static var secondary: WatchPillButtonStyle { .init(fill: ShuttlXColor.watchCardBackground, text: ShuttlXColor.textPrimary, glass: true) }
    static var warning: WatchPillButtonStyle { .init(fill: ShuttlXColor.ctaWarning, text: ShuttlXColor.iconOnCTA) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: WatchScale.pt(14), weight: .heavy))
            .foregroundStyle(text)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 44)
            .secondaryGlass(fill, in: RoundedRectangle(cornerRadius: 12), enabled: glass)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// D5: list rows in Home ("Mixed") and Mixed (Heart Recovery, programs). Same shape
/// and press feedback as `ShuttlXCardButtonStyle`, with Liquid Glass on watchOS 26+.
struct WatchGlassRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .secondaryGlass(ShuttlXColor.watchCardBackground,
                            in: RoundedRectangle(cornerRadius: ShuttlXSize.cardCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// D5: Liquid Glass on secondary controls on watchOS 26+, the solid `fill` before
    /// (the look they had). Never on safety cards' primary or End & Save actions.
    @ViewBuilder
    func secondaryGlass<S: Shape>(_ fill: Color, in shape: S, enabled: Bool = true) -> some View {
        #if compiler(>=6.2)
        if enabled, #available(watchOS 26, *) {
            // Glass on an empty layer behind the label: on the label itself the system
            // tinted the grey subtitles to about 3:1 (Mixed rows, simulator 2026-11-09).
            self.background { Color.clear.glassEffect(.regular, in: shape) }
        } else {
            self.background(fill, in: shape)
        }
        #else
        self.background(fill, in: shape)
        #endif
    }
}

/// Thin capsule bar filled to `fraction` (zone bar, heart-limit bar).
struct WatchFillBar<Fill: ShapeStyle>: View {
    let fraction: Double
    let fill: Fill
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule().fill(fill)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Ribbon of the session's parts, widths by duration (watch twin of the iOS
/// `ActivityRibbon` in ShuttlX/Components/DayRibbon.swift).
struct ActivityRibbon: View {
    let segments: [ActivitySegment]
    var height: CGFloat = 8

    private var total: TimeInterval { segments.reduce(0) { $0 + max(0, $1.duration) } }

    var body: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(0, segments.count - 1)) * 2
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    Capsule()
                        .fill(segment.activityType.themeColor)
                        .frame(width: max(4, (geo.size.width - gaps) * (total > 0 ? max(0, segment.duration) / total : 0)))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Parts: " + segments.map { "\($0.activityType.displayName) \(FormattingUtils.formatDuration($0.duration))" }.joined(separator: ", "))
    }
}

extension DetectedActivity {
    /// Tag word on the running screen ("● RUN").
    var watchTag: String {
        switch self {
        case .running: return "RUN"
        case .walking: return "WALK"
        case .cycling: return "CYCLE"
        case .stationary: return "STILL"
        case .unknown: return "RUN/WALK"
        }
    }

    /// Toast text after an auto-switch.
    var nowText: String {
        switch self {
        case .running: return "Now running"
        case .walking: return "Now walking"
        case .cycling: return "Now cycling"
        case .stationary, .unknown: return "Stopped"
        }
    }
}
