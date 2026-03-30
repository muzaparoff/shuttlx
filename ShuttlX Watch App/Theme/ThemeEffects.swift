import SwiftUI

struct ThemeEffects: Equatable {
    let cardStyle: CardStyle
    let hasNeonGlow: Bool
    let hasScanlines: Bool
    let hasGridBackground: Bool
    let neonGlowColor: Color?
    let cardCornerRadius: CGFloat
    let buttonCornerRadius: CGFloat
    let hasMeshBackground: Bool
    let hasHorizonGrid: Bool
    let hasLCDDotMatrix: Bool
    let hasCRTEffect: Bool

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
    }
}
