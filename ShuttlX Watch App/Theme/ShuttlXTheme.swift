import SwiftUI

// MARK: - Color Theme

enum ShuttlXColor {
    // Activity colors
    static let running = Color.green
    static let walking = Color.orange
    static let heartRate = Color.red
    static let steps = Color.blue
    static let calories = Color.orange
    static let stationary = Color.secondary

    // UI element colors
    static let ctaPrimary = Color.green
    static let ctaDestructive = Color.red
    static let ctaWarning = Color.orange
}

// MARK: - Typography (Dynamic Type safe, watchOS-optimized)

enum ShuttlXFont {
    static let metricLarge = Font.system(.title2, design: .rounded).weight(.bold)
    static let metricMedium = Font.system(.body, design: .rounded).weight(.semibold)
    static let metricSmall = Font.system(.callout, design: .rounded).weight(.medium)
    static let timerDisplay = Font.system(.largeTitle, design: .monospaced).weight(.semibold)
    static let cardTitle = Font.headline
    static let cardCaption = Font.caption
}
