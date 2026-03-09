import SwiftUI

// MARK: - Color Theme (bridges to ThemeManager)

enum ShuttlXColor {
    private static var colors: ThemeColors { ThemeManager.shared.colors }

    // Activity colors
    static var running: Color { colors.running }
    static var walking: Color { colors.walking }
    static var heartRate: Color { colors.heartRate }
    static var steps: Color { colors.steps }
    static var calories: Color { colors.calories }
    static var stationary: Color { colors.stationary }

    // Sport colors
    static var cycling: Color { colors.cycling }
    static var swimming: Color { colors.swimming }
    static var hiking: Color { colors.hiking }
    static var elliptical: Color { colors.elliptical }
    static var crossTraining: Color { colors.crossTraining }

    // UI element colors
    static var ctaPrimary: Color { colors.ctaPrimary }
    static var ctaDestructive: Color { colors.ctaDestructive }
    static var ctaWarning: Color { colors.ctaWarning }

    // Background & surfaces
    static var background: Color { colors.background }
    static var surface: Color { colors.surface }
    static var surfaceBorder: Color { colors.surfaceBorder }

    // Card backgrounds
    static var cardBackground: Color { colors.cardBackground }

    // Text
    static var textPrimary: Color { colors.textPrimary }
    static var textSecondary: Color { colors.textSecondary }

    // HR Zone colors
    static var hrZone1: Color { colors.hrZone1 }
    static var hrZone2: Color { colors.hrZone2 }
    static var hrZone3: Color { colors.hrZone3 }
    static var hrZone4: Color { colors.hrZone4 }
    static var hrZone5: Color { colors.hrZone5 }

    // Interval step type colors
    static var stepWork: Color { colors.stepWork }
    static var stepRest: Color { colors.stepRest }
    static var stepWarmup: Color { colors.stepWarmup }
    static var stepCooldown: Color { colors.stepCooldown }

    // Semantic
    static var pace: Color { colors.pace }
    static var positive: Color { colors.positive }
    static var negative: Color { colors.negative }
    static var iconOnCTA: Color { colors.iconOnCTA }

    // Recovery status
    static var recoveryFresh: Color { colors.recoveryFresh }
    static var recoveryNormal: Color { colors.recoveryNormal }
    static var recoveryFatigued: Color { colors.recoveryFatigued }
    static var recoveryOverreaching: Color { colors.recoveryOverreaching }

    // Pace zones
    static var paceInterval: Color { colors.paceInterval }
    static var paceThreshold: Color { colors.paceThreshold }
    static var paceTempo: Color { colors.paceTempo }
    static var paceModerate: Color { colors.paceModerate }
    static var paceEasy: Color { colors.paceEasy }

    // Gradients
    static var workoutGradient: LinearGradient {
        LinearGradient(
            colors: [colors.running.opacity(0.7), colors.running.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Helper Functions

    static func forStepType(_ type: IntervalType) -> Color {
        colors.forStepType(type)
    }

    static func forHRZone(_ heartRate: Int) -> Color {
        colors.forHRZone(heartRate)
    }

    static func forPaceZone(_ zone: String) -> Color {
        colors.forPaceZone(zone)
    }
}

// MARK: - Typography (bridges to ThemeManager)

enum ShuttlXFont {
    private static var fonts: ThemeFonts { ThemeManager.shared.fonts }

    static var metricLarge: Font { fonts.metricLarge }
    static var metricMedium: Font { fonts.metricMedium }
    static var metricSmall: Font { fonts.metricSmall }
    static var timerDisplay: Font { fonts.timerDisplay }
    static var sectionHeader: Font { fonts.sectionHeader }
    static var cardTitle: Font { fonts.cardTitle }
    static var cardSubtitle: Font { fonts.cardSubtitle }
    static var cardCaption: Font { fonts.cardCaption }

    // Hero / empty state icons
    static var heroIcon: Font { fonts.heroIcon }
    // Onboarding page icons
    static var onboardingIcon: Font { fonts.onboardingIcon }
    // PR card values
    static var prValue: Font { fonts.prValue }
    // Map annotations, chart legends
    static var microLabel: Font { fonts.microLabel }
    // Debug views
    static var debugMono: Font { fonts.debugMono }
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
