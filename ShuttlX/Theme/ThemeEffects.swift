import SwiftUI

struct ThemeEffects: Equatable {
    let cardStyle: CardStyle
    let hasNeonGlow: Bool
    let hasScanlines: Bool
    let hasGridBackground: Bool
    let neonGlowColor: Color?
    let cardCornerRadius: CGFloat
    let buttonCornerRadius: CGFloat

    enum CardStyle: String, Equatable {
        case glass
        case neon
        case lcd
        case pixel
    }

    static func == (lhs: ThemeEffects, rhs: ThemeEffects) -> Bool {
        lhs.cardStyle == rhs.cardStyle
            && lhs.hasNeonGlow == rhs.hasNeonGlow
            && lhs.hasScanlines == rhs.hasScanlines
            && lhs.hasGridBackground == rhs.hasGridBackground
            && lhs.cardCornerRadius == rhs.cardCornerRadius
            && lhs.buttonCornerRadius == rhs.buttonCornerRadius
    }
}
