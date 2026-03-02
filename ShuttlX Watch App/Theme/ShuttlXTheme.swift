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

    // Sport colors
    static let cycling = Color.blue
    static let swimming = Color.cyan
    static let hiking = Color.brown
    static let elliptical = Color.purple
    static let crossTraining = Color.indigo

    // UI element colors
    static let ctaPrimary = Color.green
    static let ctaDestructive = Color.red
    static let ctaWarning = Color.orange

    // HR Zone colors
    static let hrZone1 = Color.blue
    static let hrZone2 = Color.green
    static let hrZone3 = Color.yellow
    static let hrZone4 = Color.orange
    static let hrZone5 = Color.red

    // Interval step type colors
    static let stepWork = Color.green
    static let stepRest = Color.orange
    static let stepWarmup = Color.blue
    static let stepCooldown = Color.blue

    // watchOS surfaces
    static let watchCardBackground = Color.white.opacity(0.12)
    static let watchButtonBackground = Color.white.opacity(0.15)

    // Semantic
    static let ctaPause = Color.yellow
    static let iconOnCTA = Color.black
    static let pace = Color.purple

    // MARK: - Helpers

    static func forStepType(_ type: IntervalType) -> Color {
        switch type {
        case .work: return stepWork
        case .rest: return stepRest
        case .warmup: return stepWarmup
        case .cooldown: return stepCooldown
        }
    }

    static func forHRZone(_ heartRate: Int) -> Color {
        if heartRate <= 0 { return ShuttlXColor.heartRate }
        if heartRate < 104 { return hrZone1 }
        if heartRate < 125 { return hrZone2 }
        if heartRate < 146 { return hrZone3 }
        if heartRate < 167 { return hrZone4 }
        return hrZone5
    }
}

// MARK: - Typography (Dynamic Type safe, watchOS-optimized)

enum ShuttlXFont {
    static let metricLarge = Font.system(.title2, design: .rounded).weight(.bold)
    static let metricMedium = Font.system(.body, design: .rounded).weight(.semibold)
    static let metricSmall = Font.system(.callout, design: .rounded).weight(.medium)
    static let timerDisplay = Font.system(.largeTitle, design: .monospaced).weight(.semibold)
    static let cardTitle = Font.headline
    static let cardCaption = Font.caption

    // Timer screen — all 4 values same 40pt
    static let watchMetricDisplay = Font.system(size: 40, weight: .bold, design: .rounded)
    static let watchTimerDisplay = Font.system(size: 40, weight: .bold, design: .monospaced)

    // Supporting labels
    static let watchStepLabel = Font.system(size: 13, weight: .bold)
    static let watchControlIcon = Font.system(size: 26, weight: .semibold)
    static let watchControlLabel = Font.system(size: 11)
    static let watchStatusBadge = Font.system(size: 13, weight: .bold)

    // Summary screen
    static let watchSummaryTimer = Font.system(.title, design: .monospaced).weight(.bold)
    static let watchSummaryMetric = Font.system(.body, design: .rounded).weight(.semibold)

    // Program selection
    static let watchHeroIcon = Font.system(size: 32, weight: .medium)
    static let watchHeroTitle = Font.system(.title3, design: .rounded).weight(.semibold)
    static let watchTemplateTitle = Font.system(.body, design: .rounded).weight(.semibold)
}

// MARK: - Spacing

enum ShuttlXSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
}

// MARK: - Sizes

enum ShuttlXSize {
    static let controlButtonDiameter: CGFloat = 64
    static let cardCornerRadius: CGFloat = 12
    static let heroCornerRadius: CGFloat = 16
    static let stepDotSize: CGFloat = 8
}

// MARK: - Button Styles

struct ShuttlXControlButtonStyle: ButtonStyle {
    var iconColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: ShuttlXSize.controlButtonDiameter, height: ShuttlXSize.controlButtonDiameter)
            .background(
                Circle()
                    .fill(ShuttlXColor.watchButtonBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ShuttlXPrimaryCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: ShuttlXSize.heroCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ShuttlXCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(ShuttlXColor.watchCardBackground, in: RoundedRectangle(cornerRadius: ShuttlXSize.cardCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
