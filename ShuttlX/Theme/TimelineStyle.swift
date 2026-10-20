import SwiftUI

// Flat "timeline" look for Today / Session detail (approved mockup, 2026-10).
// Clean: grouped-grey screen + flat grouped-white card, no border or shine.
// Other themes keep their own card and background so Mixtape still renders.

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
