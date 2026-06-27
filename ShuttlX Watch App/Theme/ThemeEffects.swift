import SwiftUI

// MARK: - ThemeEffects
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. Existing themes pass all values explicitly — no behaviour change.
// Use `var e = ThemeEffects(); e.cardStyle = .neon` to build from a preset.

struct ThemeEffects: Equatable {
    var cardStyle: CardStyle         = .glass
    var hasNeonGlow: Bool            = false
    var hasScanlines: Bool           = false
    var hasGridBackground: Bool      = false
    var neonGlowColor: Color?        = nil
    var cardCornerRadius: CGFloat    = 12
    var buttonCornerRadius: CGFloat  = 12
    var hasMeshBackground: Bool      = false
    var hasHorizonGrid: Bool         = false
    var hasLCDDotMatrix: Bool        = false
    var hasCRTEffect: Bool           = false
    var cardAccentBarWidth: CGFloat  = 0

    enum CardStyle: String, Equatable {
        case glass
        case neon
        case lcd
        case pixel
        case tape
        case meter
        case terminal
    }

    static func == (lhs: ThemeEffects, rhs: ThemeEffects) -> Bool {
        lhs.cardStyle == rhs.cardStyle
            && lhs.hasNeonGlow == rhs.hasNeonGlow
            && lhs.hasScanlines == rhs.hasScanlines
            && lhs.hasGridBackground == rhs.hasGridBackground
            && lhs.cardCornerRadius == rhs.cardCornerRadius
            && lhs.buttonCornerRadius == rhs.buttonCornerRadius
            && lhs.hasMeshBackground == rhs.hasMeshBackground
            && lhs.hasHorizonGrid == rhs.hasHorizonGrid
            && lhs.hasLCDDotMatrix == rhs.hasLCDDotMatrix
            && lhs.hasCRTEffect == rhs.hasCRTEffect
            && lhs.cardAccentBarWidth == rhs.cardAccentBarWidth
    }
}
