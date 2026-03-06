import SwiftUI

extension AppTheme {
    static let casio = AppTheme(
        id: "casio",
        displayName: "Casio LCD",
        icon: "clock.fill",
        colors: ThemeColors(
            background: Color(red: 0.05, green: 0.05, blue: 0.05),       // #0D0D0D
            surface: Color(red: 0.10, green: 0.10, blue: 0.10),          // #1A1A1A
            surfaceBorder: Color(red: 0.20, green: 0.20, blue: 0.20),    // #333333 inset
            running: Color(red: 0.22, green: 1.0, blue: 0.08),           // #39FF14 phosphor green
            walking: Color(red: 1.0, green: 0.72, blue: 0.0),            // #FFB800 amber
            heartRate: Color(red: 1.0, green: 0.20, blue: 0.20),         // #FF3333 LED red
            steps: Color(red: 0.22, green: 1.0, blue: 0.08),             // phosphor green
            calories: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            stationary: Color(red: 0.40, green: 0.40, blue: 0.40),       // #666666
            cycling: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            swimming: Color(red: 0.0, green: 0.80, blue: 0.80),          // teal
            hiking: Color(red: 1.0, green: 0.72, blue: 0.0),             // amber
            elliptical: Color(red: 0.22, green: 1.0, blue: 0.08),        // green
            crossTraining: Color(red: 1.0, green: 0.72, blue: 0.0),      // amber
            ctaPrimary: Color(red: 0.22, green: 1.0, blue: 0.08),        // #39FF14 green LCD
            ctaDestructive: Color(red: 1.0, green: 0.20, blue: 0.20),    // LED red
            ctaWarning: Color(red: 1.0, green: 0.72, blue: 0.0),         // amber
            ctaPause: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            iconOnCTA: Color(red: 0.05, green: 0.05, blue: 0.05),        // near-black
            hrZone1: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone2: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone3: Color(red: 1.0, green: 0.72, blue: 0.0),            // amber
            hrZone4: Color(red: 1.0, green: 0.50, blue: 0.0),            // orange-amber
            hrZone5: Color(red: 1.0, green: 0.20, blue: 0.20),           // LED red
            stepWork: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            stepRest: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            stepWarmup: Color(red: 0.22, green: 1.0, blue: 0.08),        // green
            stepCooldown: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            pace: Color(red: 1.0, green: 0.72, blue: 0.0),               // amber
            positive: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            negative: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            recoveryFresh: Color(red: 0.22, green: 1.0, blue: 0.08),     // green
            recoveryNormal: Color(red: 0.22, green: 1.0, blue: 0.08),    // green
            recoveryFatigued: Color(red: 1.0, green: 0.72, blue: 0.0),   // amber
            recoveryOverreaching: Color(red: 1.0, green: 0.20, blue: 0.20), // red
            paceInterval: Color(red: 1.0, green: 0.20, blue: 0.20),      // red
            paceThreshold: Color(red: 1.0, green: 0.72, blue: 0.0),      // amber
            paceTempo: Color(red: 1.0, green: 0.72, blue: 0.0),          // amber
            paceModerate: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            paceEasy: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            textPrimary: Color(red: 0.67, green: 0.67, blue: 0.67),      // #AAAAAA
            textSecondary: Color(red: 0.40, green: 0.40, blue: 0.40),    // #666666
            cardBackground: Color(red: 0.10, green: 0.10, blue: 0.10),
            watchCardBackground: Color(red: 0.10, green: 0.10, blue: 0.10),
            watchButtonBackground: Color(red: 0.15, green: 0.15, blue: 0.15)
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
            watchTimerDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchStepLabel: .system(size: 13, weight: .bold, design: .monospaced),
            watchControlIcon: .system(size: 26, weight: .semibold),
            watchControlLabel: .system(size: 11, design: .monospaced),
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
            hasCRTEffect: false
        )
    )
}
