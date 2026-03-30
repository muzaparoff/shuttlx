import SwiftUI

extension AppTheme {
    static let synthwave = AppTheme(
        id: "synthwave",
        displayName: "Synthwave",
        icon: "sun.horizon.fill",
        colors: ThemeColors(
            background: Color(red: 0.04, green: 0.04, blue: 0.10),      // #0A0A1A
            surface: Color(red: 0.08, green: 0.08, blue: 0.16),          // #141428
            surfaceBorder: Color(red: 0.0, green: 0.96, blue: 1.0).opacity(0.3), // cyan border
            running: Color(red: 0.22, green: 1.0, blue: 0.08),           // #39FF14 phosphor green
            walking: Color(red: 1.0, green: 0.72, blue: 0.0),            // #FFB800 amber
            heartRate: Color(red: 1.0, green: 0.18, blue: 0.58),         // #FF2D95 neon magenta
            steps: Color(red: 0.0, green: 0.96, blue: 1.0),              // #00F5FF neon cyan
            calories: Color(red: 1.0, green: 0.42, blue: 0.61),          // #FF6B9D chrome pink
            stationary: Color(red: 0.48, green: 0.48, blue: 0.60),       // muted
            cycling: Color(red: 0.0, green: 0.96, blue: 1.0),            // cyan
            swimming: Color(red: 0.29, green: 0.57, blue: 1.0),          // #4A92FF
            hiking: Color(red: 1.0, green: 0.72, blue: 0.0),             // amber
            elliptical: Color(red: 0.71, green: 0.30, blue: 1.0),        // #B44DFF neon purple
            crossTraining: Color(red: 1.0, green: 0.42, blue: 0.61),     // chrome pink
            ctaPrimary: Color(red: 0.0, green: 0.96, blue: 1.0),         // #00F5FF neon cyan
            ctaDestructive: Color(red: 1.0, green: 0.18, blue: 0.58),    // neon magenta
            ctaWarning: Color(red: 1.0, green: 0.72, blue: 0.0),         // amber
            ctaPause: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            iconOnCTA: Color(red: 0.04, green: 0.04, blue: 0.10),        // dark background
            hrZone1: Color(red: 0.29, green: 0.57, blue: 1.0),           // blue
            hrZone2: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone3: Color(red: 1.0, green: 0.72, blue: 0.0),            // amber
            hrZone4: Color(red: 1.0, green: 0.42, blue: 0.0),            // orange
            hrZone5: Color(red: 1.0, green: 0.18, blue: 0.58),           // magenta
            stepWork: Color(red: 0.22, green: 1.0, blue: 0.08),          // phosphor green
            stepRest: Color(red: 1.0, green: 0.72, blue: 0.0),           // amber
            stepWarmup: Color(red: 0.0, green: 0.96, blue: 1.0),         // cyan
            stepCooldown: Color(red: 0.71, green: 0.30, blue: 1.0),      // purple
            pace: Color(red: 0.71, green: 0.30, blue: 1.0),              // neon purple
            positive: Color(red: 0.22, green: 1.0, blue: 0.08),          // phosphor green
            negative: Color(red: 1.0, green: 0.42, blue: 0.0),           // orange
            recoveryFresh: Color(red: 0.22, green: 1.0, blue: 0.08),     // green
            recoveryNormal: Color(red: 0.0, green: 0.96, blue: 1.0),     // cyan
            recoveryFatigued: Color(red: 1.0, green: 0.72, blue: 0.0),   // amber
            recoveryOverreaching: Color(red: 1.0, green: 0.18, blue: 0.58), // magenta
            paceInterval: Color(red: 1.0, green: 0.18, blue: 0.58),      // magenta
            paceThreshold: Color(red: 1.0, green: 0.42, blue: 0.0),      // orange
            paceTempo: Color(red: 1.0, green: 0.72, blue: 0.0),          // amber
            paceModerate: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            paceEasy: Color(red: 0.0, green: 0.96, blue: 1.0),           // cyan
            textPrimary: Color(red: 0.88, green: 0.88, blue: 0.88),      // #E0E0E0
            textSecondary: Color(red: 0.48, green: 0.48, blue: 0.60),    // #7A7A9A
            cardBackground: Color(red: 0.08, green: 0.08, blue: 0.16),
            watchCardBackground: Color(red: 0.08, green: 0.08, blue: 0.16),
            watchButtonBackground: Color(red: 0.12, green: 0.12, blue: 0.22)
        ),
        fonts: ThemeFonts(
            timerDisplay: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricLarge: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricMedium: .system(.title2, design: .monospaced).weight(.semibold),
            metricSmall: .system(.body, design: .monospaced).weight(.medium),
            cardTitle: .system(.headline, design: .default).weight(.bold),
            cardSubtitle: .subheadline,
            cardCaption: .caption,
            sectionHeader: .system(.headline, design: .default).weight(.bold),
            heroIcon: .system(size: 48),
            onboardingIcon: .system(size: 72),
            prValue: .system(.title3, design: .monospaced).weight(.bold),
            microLabel: .system(size: 9, design: .monospaced),
            debugMono: .system(.caption, design: .monospaced),
            watchTimerDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricSecondary: .system(size: 24, weight: .semibold, design: .monospaced),
            watchStepLabel: .system(size: 13, weight: .bold),
            watchControlIcon: .system(size: 26, weight: .semibold),
            watchControlLabel: .system(size: 11),
            watchStatusBadge: .system(size: 13, weight: .bold),
            watchSummaryTimer: .system(.title, design: .monospaced).weight(.bold),
            watchSummaryMetric: .system(.body, design: .monospaced).weight(.semibold),
            watchHeroIcon: .system(size: 32, weight: .medium),
            watchHeroTitle: .system(.title3, design: .default).weight(.semibold),
            watchTemplateTitle: .system(.body, design: .default).weight(.semibold)
        ),
        effects: ThemeEffects(
            cardStyle: .neon,
            hasNeonGlow: true,
            hasScanlines: false,
            hasGridBackground: true,
            neonGlowColor: Color(red: 0.0, green: 0.96, blue: 1.0),  // cyan
            cardCornerRadius: 16,
            buttonCornerRadius: 14,
            hasMeshBackground: false,
            hasHorizonGrid: true,
            hasLCDDotMatrix: false,
            hasCRTEffect: false,
            cardAccentBarWidth: 0
        )
    )
}
