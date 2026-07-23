import SwiftUI

// MARK: - ThemeEffects
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. Existing themes pass all values explicitly — no behaviour change.
// Use `var e = ThemeEffects(); e.cardStyle = .neon` to build from a preset.

struct ThemeEffects: Equatable {
    var cardStyle: CardStyle         = .glass
    var hasScanlines: Bool           = false
    var neonGlowColor: Color?        = nil
    var cardCornerRadius: CGFloat    = 12
    var buttonCornerRadius: CGFloat  = 12
    var hasMeshBackground: Bool      = false
    var hasLCDDotMatrix: Bool        = false

    enum CardStyle: String, Equatable {
        case glass
        case lcd
    }

    static func == (lhs: ThemeEffects, rhs: ThemeEffects) -> Bool {
        lhs.cardStyle == rhs.cardStyle
            && lhs.hasScanlines == rhs.hasScanlines
            && lhs.cardCornerRadius == rhs.cardCornerRadius
            && lhs.buttonCornerRadius == rhs.buttonCornerRadius
            && lhs.hasMeshBackground == rhs.hasMeshBackground
            && lhs.hasLCDDotMatrix == rhs.hasLCDDotMatrix
    }
}
