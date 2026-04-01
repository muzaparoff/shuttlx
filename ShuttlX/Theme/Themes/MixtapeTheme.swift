import SwiftUI

extension AppTheme {
    static let mixtape = AppTheme(
        id: "mixtape",
        displayName: "Mixtape",
        icon: "cassette.fill",
        colors: ThemeColors(
            background: Color(red: 0.05, green: 0.08, blue: 0.13),       // #0E1420 dark blue body
            surface: Color(red: 0.10, green: 0.19, blue: 0.38),          // #1A3060 blue panel
            surfaceBorder: Color(red: 0.29, green: 0.42, blue: 0.60),    // #4A6A9A blue-steel border
            running: Color(red: 0.22, green: 1.0, blue: 0.08),           // #39FF14 green LCD
            walking: Color(red: 0.29, green: 0.54, blue: 0.79),          // #4A8ACA blue accent
            heartRate: Color(red: 1.0, green: 0.20, blue: 0.20),         // #FF3333 LED red
            steps: Color(red: 0.22, green: 1.0, blue: 0.08),             // green LCD
            calories: Color(red: 0.29, green: 0.54, blue: 0.79),         // blue accent
            stationary: Color(red: 0.42, green: 0.54, blue: 0.67),       // #6A8AAA muted blue
            cycling: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            swimming: Color(red: 0.0, green: 0.80, blue: 0.80),          // teal
            hiking: Color(red: 0.29, green: 0.54, blue: 0.79),           // blue accent
            elliptical: Color(red: 0.22, green: 1.0, blue: 0.08),        // green
            crossTraining: Color(red: 0.29, green: 0.54, blue: 0.79),    // blue accent
            ctaPrimary: Color(red: 0.29, green: 0.54, blue: 0.79),       // #4A8ACA blue
            ctaDestructive: Color(red: 1.0, green: 0.20, blue: 0.20),    // LED red
            ctaWarning: Color(red: 0.29, green: 0.54, blue: 0.79),       // blue
            ctaPause: Color(red: 0.29, green: 0.54, blue: 0.79),         // blue
            iconOnCTA: Color(red: 0.05, green: 0.08, blue: 0.13),        // dark blue
            hrZone1: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone2: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone3: Color(red: 0.29, green: 0.54, blue: 0.79),          // blue
            hrZone4: Color(red: 0.54, green: 0.40, blue: 0.79),          // purple-blue
            hrZone5: Color(red: 1.0, green: 0.20, blue: 0.20),           // LED red
            stepWork: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            stepRest: Color(red: 0.29, green: 0.54, blue: 0.79),         // blue
            stepWarmup: Color(red: 0.29, green: 0.54, blue: 0.79),       // blue
            stepCooldown: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            pace: Color(red: 0.29, green: 0.54, blue: 0.79),             // blue
            positive: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            negative: Color(red: 1.0, green: 0.20, blue: 0.20),          // red
            recoveryFresh: Color(red: 0.22, green: 1.0, blue: 0.08),     // green
            recoveryNormal: Color(red: 0.29, green: 0.54, blue: 0.79),   // blue
            recoveryFatigued: Color(red: 0.54, green: 0.40, blue: 0.79), // purple-blue
            recoveryOverreaching: Color(red: 1.0, green: 0.20, blue: 0.20), // red
            paceInterval: Color(red: 1.0, green: 0.20, blue: 0.20),      // red
            paceThreshold: Color(red: 0.54, green: 0.40, blue: 0.79),    // purple-blue
            paceTempo: Color(red: 0.29, green: 0.54, blue: 0.79),        // blue
            paceModerate: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            paceEasy: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            textPrimary: Color(red: 0.54, green: 0.67, blue: 0.79),      // #8AAACA cool blue-gray
            textSecondary: Color(red: 0.42, green: 0.54, blue: 0.67),    // #6A8AAA muted blue
            cardBackground: Color(red: 0.10, green: 0.19, blue: 0.38),
            watchCardBackground: Color(red: 0.10, green: 0.19, blue: 0.38),
            watchButtonBackground: Color(red: 0.15, green: 0.24, blue: 0.43)
        ),
        fonts: ThemeFonts(
            timerDisplay: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricLarge: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricMedium: .system(.title2, design: .monospaced).weight(.semibold),
            metricSmall: .system(.body, design: .monospaced).weight(.medium),
            cardTitle: .system(.headline, design: .monospaced).weight(.bold),
            cardSubtitle: .system(.subheadline, design: .monospaced),
            cardCaption: .system(.caption, design: .monospaced),
            sectionHeader: .system(.headline, design: .monospaced).weight(.bold),
            heroIcon: .system(size: 48),
            onboardingIcon: .system(size: 72),
            prValue: .system(.title3, design: .monospaced).weight(.bold),
            microLabel: .system(size: 9, design: .monospaced),
            debugMono: .system(.caption, design: .monospaced),
            watchTimerDisplay: .system(size: 52, weight: .bold, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricSecondary: .system(size: 28, weight: .semibold, design: .monospaced),
            watchStepLabel: .system(size: 13, weight: .bold, design: .monospaced),
            watchControlIcon: .system(size: 26, weight: .semibold),
            watchControlLabel: .system(size: 13, design: .monospaced),
            watchStatusBadge: .system(size: 13, weight: .bold, design: .monospaced),
            watchSummaryTimer: .system(.title, design: .monospaced).weight(.bold),
            watchSummaryMetric: .system(.body, design: .monospaced).weight(.semibold),
            watchHeroIcon: .system(size: 32, weight: .medium),
            watchHeroTitle: .system(.title3, design: .monospaced).weight(.semibold),
            watchTemplateTitle: .system(.body, design: .monospaced).weight(.semibold)
        ),
        effects: ThemeEffects(
            cardStyle: .lcd,
            hasNeonGlow: false,
            hasScanlines: true,
            hasGridBackground: false,
            neonGlowColor: nil,
            cardCornerRadius: 8,
            buttonCornerRadius: 8,
            hasMeshBackground: false,
            hasHorizonGrid: false,
            hasLCDDotMatrix: true,
            hasCRTEffect: false,
            cardAccentBarWidth: 0
        )
    )
}
