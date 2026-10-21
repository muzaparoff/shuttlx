import SwiftUI

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
}

extension Animation {
    /// nil (no animation) while Reduce Motion is on.
    static func ifAllowed(_ animation: Animation) -> Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}
