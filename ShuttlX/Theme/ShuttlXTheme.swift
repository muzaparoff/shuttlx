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

    // Card backgrounds
    static let cardBackground = Color(.secondarySystemBackground)

    // HR Zone colors
    static let hrZone1 = Color.blue       // Easy
    static let hrZone2 = Color.green      // Fat Burn
    static let hrZone3 = Color.yellow     // Cardio
    static let hrZone4 = Color.orange     // Hard
    static let hrZone5 = Color.red        // Peak

    // Interval step type colors
    static let stepWork = Color.green
    static let stepRest = Color.orange
    static let stepWarmup = Color.blue
    static let stepCooldown = Color.blue

    // Semantic
    static let pace = Color.purple
    static let positive = Color.green       // good status, upward trends
    static let negative = Color.orange      // warning status, downward trends
    static let iconOnCTA = Color.black

    // Recovery status
    static let recoveryFresh = Color.green
    static let recoveryNormal = Color.blue
    static let recoveryFatigued = Color.orange
    static let recoveryOverreaching = Color.red

    // Pace zones
    static let paceInterval = Color.red
    static let paceThreshold = Color.orange
    static let paceTempo = Color.yellow
    static let paceModerate = Color.green
    static let paceEasy = Color.blue

    // Gradients
    static let workoutGradient = LinearGradient(
        colors: [.green.opacity(0.7), .green.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Helper Functions

    static func forStepType(_ type: IntervalType) -> Color {
        switch type {
        case .work: return stepWork
        case .rest: return stepRest
        case .warmup: return stepWarmup
        case .cooldown: return stepCooldown
        }
    }

    static func forHRZone(_ heartRate: Int) -> Color {
        switch heartRate {
        case ..<100: return hrZone1
        case 100..<130: return hrZone2
        case 130..<155: return hrZone3
        case 155..<175: return hrZone4
        default: return hrZone5
        }
    }

    static func forPaceZone(_ zone: String) -> Color {
        switch zone {
        case "Interval": return paceInterval
        case "Threshold": return paceThreshold
        case "Tempo": return paceTempo
        case "Moderate": return paceModerate
        case "Easy": return paceEasy
        default: return Color.gray
        }
    }
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

    // Hero / empty state icons
    static let heroIcon = Font.system(size: 48)
    // Onboarding page icons
    static let onboardingIcon = Font.system(size: 72)
    // PR card values
    static let prValue = Font.system(.title3, design: .rounded).weight(.bold)
    // Map annotations, chart legends
    static let microLabel = Font.system(size: 9)
    // Debug views
    static let debugMono = Font.system(.caption, design: .monospaced)
}

// MARK: - Spacing & Size Tokens

enum ShuttlXSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
}

enum ShuttlXSize {
    static let cardCornerRadius: CGFloat = 12
    static let heroCornerRadius: CGFloat = 16
    static let ctaCornerRadius: CGFloat = 14
}

// MARK: - CTA Button Style

struct ShuttlXPrimaryCTAStyle: ButtonStyle {
    var maxWidth: CGFloat? = 280

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: maxWidth)
            .padding(.vertical, 14)
            .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: ShuttlXSize.ctaCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
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
