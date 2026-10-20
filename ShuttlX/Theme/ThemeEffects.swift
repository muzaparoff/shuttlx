import SwiftUI

// MARK: - ThemeEffects
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. Existing themes pass all values explicitly — no behaviour change.
// Use `var e = ThemeEffects(); e.cardStyle = .neon` to build from a preset.

struct ThemeEffects: Equatable {
    var cardStyle: CardStyle         = .glass
    var neonGlowColor: Color?        = nil
    var cardCornerRadius: CGFloat    = 16
    var buttonCornerRadius: CGFloat  = 14
    var hasMeshBackground: Bool      = false

    enum CardStyle: String, Equatable {
        case glass
    }

    static func == (lhs: ThemeEffects, rhs: ThemeEffects) -> Bool {
        lhs.cardStyle == rhs.cardStyle
            && lhs.cardCornerRadius == rhs.cardCornerRadius
            && lhs.buttonCornerRadius == rhs.buttonCornerRadius
            && lhs.hasMeshBackground == rhs.hasMeshBackground
    }
}
