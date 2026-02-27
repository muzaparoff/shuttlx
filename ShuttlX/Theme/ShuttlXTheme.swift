import SwiftUI

// MARK: - Color Theme

enum ShuttlXColor {
    // Activity colors (use system adaptive colors that work in light + dark)
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

    // Card backgrounds
    static let cardBackground = Color(.secondarySystemBackground)

    // Gradients
    static let workoutGradient = LinearGradient(
        colors: [.green.opacity(0.7), .green.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography (Dynamic Type safe)

enum ShuttlXFont {
    static let metricLarge = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let metricMedium = Font.system(.title2, design: .rounded).weight(.semibold)
    static let metricSmall = Font.system(.body, design: .rounded).weight(.medium)
    static let timerDisplay = Font.system(.largeTitle, design: .monospaced).weight(.semibold)
    static let sectionHeader = Font.headline
    static let cardTitle = Font.headline
    static let cardSubtitle = Font.subheadline
    static let cardCaption = Font.caption
}

// MARK: - Glass Background (iOS 26 Liquid Glass with fallback)

extension View {
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, watchOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
        #else
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }
}
