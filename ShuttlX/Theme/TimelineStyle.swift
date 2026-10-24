import SwiftUI
import ShuttlXShared

// Flat "timeline" look for Today / Session detail (approved mockup, 2026-10).
// Clean: grouped-grey screen + flat grouped-white card, no border or shine.
// Any future theme keeps its own card and background.

extension View {
    @ViewBuilder
    func timelineCard(radius: CGFloat = 14) -> some View {
        if ThemeManager.shared.current.id == "clean" {
            self.background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.themedCard()
        }
    }

    @ViewBuilder
    func timelineScreenBackground() -> some View {
        if ThemeManager.shared.current.id == "clean" {
            self.background(Color(.systemGroupedBackground).ignoresSafeArea())
        } else {
            self.themedScreenBackground()
        }
    }
}

extension ShuttlXColor {
    /// Green for TEXT and thin icons on light backgrounds (system green is ~2.2:1 on white; this is ~5.3:1,
    /// darker again with Increase Contrast). Dark mode keeps system green. Fills keep `ctaPrimary`.
    static var accentText: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark { return .systemGreen }
            return trait.accessibilityContrast == .high
                ? UIColor(red: 0.07, green: 0.34, blue: 0.13, alpha: 1)
                : UIColor(red: 0.12, green: 0.48, blue: 0.20, alpha: 1)
        })
    }

    /// Amber/yellow for TEXT on light backgrounds (system yellow is ~1.5:1, orange ~2.5:1). Dark mode keeps the system hue.
    static var warningText: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark { return .systemYellow }
            return trait.accessibilityContrast == .high
                ? UIColor(red: 0.45, green: 0.26, blue: 0.0, alpha: 1)
                : UIColor(red: 0.54, green: 0.33, blue: 0.0, alpha: 1)   // #8A5300
        })
    }

    /// Orange (Walk) for TEXT on light backgrounds.
    static var walkingText: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark { return .systemOrange }
            return UIColor(red: 0.64, green: 0.28, blue: 0.0, alpha: 1)   // #A34700
        })
    }

    /// Text-safe colour for a live heart-rate number (zone colours: green and yellow fail contrast as text).
    static func hrText(_ bpm: Int) -> Color {
        switch HeartRateZoneCalculator.fromSharedDefaults().zone(for: Double(bpm)) {
        case 2: return accentText
        case 3: return warningText
        case 4: return walkingText
        default: return forHRZone(bpm)
        }
    }

    /// Text-safe colour for an activity name (Run green, Walk orange).
    static func activityText(_ a: DetectedActivity) -> Color {
        switch a {
        case .running: return accentText
        case .walking: return walkingText
        default: return textPrimary
        }
    }
}

extension Animation {
    /// nil (no animation) while Reduce Motion is on.
    static func ifAllowed(_ animation: Animation) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}
