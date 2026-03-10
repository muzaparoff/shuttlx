import SwiftUI

extension AppTheme {
    static let arcade = AppTheme(
        id: "arcade",
        displayName: "Arcade",
        icon: "gamecontroller.fill",
        colors: ThemeColors(
            background: Color(red: 0.06, green: 0.06, blue: 0.18),       // #0F0F2D deep navy
            surface: Color(red: 0.10, green: 0.10, blue: 0.24),          // #1A1A3E dark purple
            surfaceBorder: Color(red: 0.0, green: 1.0, blue: 0.0).opacity(0.5), // bright border
            running: Color(red: 0.0, green: 1.0, blue: 0.0),             // #00FF00 pure green
            walking: Color(red: 1.0, green: 0.67, blue: 0.0),            // #FFAA00 game orange
            heartRate: Color(red: 1.0, green: 0.0, blue: 0.0),           // #FF0000 pure red
            steps: Color(red: 0.0, green: 0.67, blue: 1.0),              // #00AAFF sky blue
            calories: Color(red: 1.0, green: 0.33, blue: 0.0),           // #FF5500
            stationary: Color(red: 0.53, green: 0.53, blue: 0.67),       // #8888AA
            cycling: Color(red: 0.0, green: 0.67, blue: 1.0),            // sky blue
            swimming: Color(red: 0.0, green: 1.0, blue: 1.0),            // #00FFFF cyan
            hiking: Color(red: 1.0, green: 0.67, blue: 0.0),             // game orange
            elliptical: Color(red: 1.0, green: 0.0, blue: 1.0),          // #FF00FF magenta
            crossTraining: Color(red: 1.0, green: 1.0, blue: 0.0),       // #FFFF00 yellow
            ctaPrimary: Color(red: 0.0, green: 1.0, blue: 0.0),          // pure green
            ctaDestructive: Color(red: 1.0, green: 0.0, blue: 0.0),      // pure red
            ctaWarning: Color(red: 1.0, green: 0.67, blue: 0.0),         // game orange
            ctaPause: Color(red: 1.0, green: 1.0, blue: 0.0),            // yellow
            iconOnCTA: Color(red: 0.06, green: 0.06, blue: 0.18),        // dark background
            hrZone1: Color(red: 0.0, green: 0.67, blue: 1.0),            // blue
            hrZone2: Color(red: 0.0, green: 1.0, blue: 0.0),             // green
            hrZone3: Color(red: 1.0, green: 1.0, blue: 0.0),             // yellow
            hrZone4: Color(red: 1.0, green: 0.67, blue: 0.0),            // orange
            hrZone5: Color(red: 1.0, green: 0.0, blue: 0.0),             // red
            stepWork: Color(red: 0.0, green: 1.0, blue: 0.0),            // green
            stepRest: Color(red: 1.0, green: 0.67, blue: 0.0),           // orange
            stepWarmup: Color(red: 0.0, green: 0.67, blue: 1.0),         // blue
            stepCooldown: Color(red: 0.0, green: 0.67, blue: 1.0),       // blue
            pace: Color(red: 1.0, green: 0.0, blue: 1.0),                // magenta
            positive: Color(red: 0.0, green: 1.0, blue: 0.0),            // green
            negative: Color(red: 1.0, green: 0.67, blue: 0.0),           // orange
            recoveryFresh: Color(red: 0.0, green: 1.0, blue: 0.0),       // green
            recoveryNormal: Color(red: 0.0, green: 0.67, blue: 1.0),     // blue
            recoveryFatigued: Color(red: 1.0, green: 0.67, blue: 0.0),   // orange
            recoveryOverreaching: Color(red: 1.0, green: 0.0, blue: 0.0), // red
            paceInterval: Color(red: 1.0, green: 0.0, blue: 0.0),        // red
            paceThreshold: Color(red: 1.0, green: 0.67, blue: 0.0),      // orange
            paceTempo: Color(red: 1.0, green: 1.0, blue: 0.0),           // yellow
            paceModerate: Color(red: 0.0, green: 1.0, blue: 0.0),        // green
            paceEasy: Color(red: 0.0, green: 0.67, blue: 1.0),           // blue
            textPrimary: .white,                                           // #FFFFFF
            textSecondary: Color(red: 0.53, green: 0.53, blue: 0.67),    // #8888AA
            cardBackground: Color(red: 0.10, green: 0.10, blue: 0.24),
            watchCardBackground: Color(red: 0.10, green: 0.10, blue: 0.24),
            watchButtonBackground: Color(red: 0.15, green: 0.15, blue: 0.30)
        ),
        fonts: ThemeFonts(
            timerDisplay: .system(.largeTitle, design: .monospaced).weight(.heavy),
            metricLarge: .system(.largeTitle, design: .rounded).weight(.heavy),
            metricMedium: .system(.title2, design: .rounded).weight(.bold),
            metricSmall: .system(.body, design: .rounded).weight(.bold),
            cardTitle: .system(.headline, design: .rounded).weight(.heavy),
            cardSubtitle: .system(.subheadline, design: .rounded).weight(.semibold),
            cardCaption: .system(.caption, design: .rounded).weight(.medium),
            sectionHeader: .system(.headline, design: .rounded).weight(.heavy),
            heroIcon: .system(size: 48, weight: .heavy),
            onboardingIcon: .system(size: 72, weight: .heavy),
            prValue: .system(.title3, design: .rounded).weight(.heavy),
            microLabel: .system(size: 9, weight: .bold, design: .monospaced),
            debugMono: .system(.caption, design: .monospaced),
            watchTimerDisplay: .system(size: 40, weight: .heavy, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .heavy, design: .rounded),
            watchMetricSecondary: .system(size: 24, weight: .bold, design: .rounded),
            watchStepLabel: .system(size: 13, weight: .heavy),
            watchControlIcon: .system(size: 26, weight: .bold),
            watchControlLabel: .system(size: 11, weight: .bold),
            watchStatusBadge: .system(size: 13, weight: .heavy),
            watchSummaryTimer: .system(.title, design: .monospaced).weight(.heavy),
            watchSummaryMetric: .system(.body, design: .rounded).weight(.bold),
            watchHeroIcon: .system(size: 32, weight: .heavy),
            watchHeroTitle: .system(.title3, design: .rounded).weight(.heavy),
            watchTemplateTitle: .system(.body, design: .rounded).weight(.bold)
        ),
        effects: ThemeEffects(
            cardStyle: .pixel,
            hasNeonGlow: false,
            hasScanlines: false,
            hasGridBackground: false,
            neonGlowColor: nil,
            cardCornerRadius: 4,
            buttonCornerRadius: 4,
            hasMeshBackground: false,
            hasHorizonGrid: false,
            hasLCDDotMatrix: false,
            hasCRTEffect: true
        )
    )
}
