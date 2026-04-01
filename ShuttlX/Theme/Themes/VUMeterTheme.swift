import SwiftUI

extension AppTheme {
    static let vuMeter = AppTheme(
        id: "vumeter",
        displayName: "VU Meter",
        icon: "gauge.with.needle.fill",
        colors: ThemeColors(
            background: Color(red: 0.10, green: 0.09, blue: 0.06),       // #1A1610 dark warm
            surface: Color(red: 0.07, green: 0.05, blue: 0.03),          // #120E08 deep panel
            surfaceBorder: Color(red: 0.35, green: 0.29, blue: 0.20),    // #5A4A32 brass
            running: Color(red: 0.22, green: 1.0, blue: 0.08),           // #39FF14 green indicator
            walking: Color(red: 0.91, green: 0.63, blue: 0.19),          // #E8A030 amber
            heartRate: Color(red: 0.80, green: 0.27, blue: 0.27),        // #CC4444 warm red
            steps: Color(red: 0.91, green: 0.63, blue: 0.19),            // amber
            calories: Color(red: 0.91, green: 0.63, blue: 0.19),         // amber
            stationary: Color(red: 0.35, green: 0.29, blue: 0.20),       // #5A4A32 muted
            cycling: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            swimming: Color(red: 0.0, green: 0.70, blue: 0.70),          // teal
            hiking: Color(red: 0.91, green: 0.63, blue: 0.19),           // amber
            elliptical: Color(red: 0.22, green: 1.0, blue: 0.08),        // green
            crossTraining: Color(red: 0.91, green: 0.63, blue: 0.19),    // amber
            ctaPrimary: Color(red: 0.91, green: 0.63, blue: 0.19),       // #E8A030 amber
            ctaDestructive: Color(red: 0.80, green: 0.27, blue: 0.27),   // warm red
            ctaWarning: Color(red: 0.91, green: 0.63, blue: 0.19),       // amber
            ctaPause: Color(red: 0.91, green: 0.63, blue: 0.19),         // amber
            iconOnCTA: Color(red: 0.10, green: 0.09, blue: 0.06),        // dark background
            hrZone1: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone2: Color(red: 0.22, green: 1.0, blue: 0.08),           // green
            hrZone3: Color(red: 0.91, green: 0.63, blue: 0.19),          // amber
            hrZone4: Color(red: 0.91, green: 0.45, blue: 0.10),          // deep amber
            hrZone5: Color(red: 0.80, green: 0.27, blue: 0.27),          // warm red
            stepWork: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            stepRest: Color(red: 0.91, green: 0.63, blue: 0.19),         // amber
            stepWarmup: Color(red: 0.91, green: 0.63, blue: 0.19),       // amber
            stepCooldown: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            pace: Color(red: 0.91, green: 0.63, blue: 0.19),             // amber
            positive: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            negative: Color(red: 0.80, green: 0.27, blue: 0.27),         // warm red
            recoveryFresh: Color(red: 0.22, green: 1.0, blue: 0.08),     // green
            recoveryNormal: Color(red: 0.91, green: 0.63, blue: 0.19),   // amber
            recoveryFatigued: Color(red: 0.91, green: 0.45, blue: 0.10), // deep amber
            recoveryOverreaching: Color(red: 0.80, green: 0.27, blue: 0.27), // warm red
            paceInterval: Color(red: 0.80, green: 0.27, blue: 0.27),     // warm red
            paceThreshold: Color(red: 0.91, green: 0.45, blue: 0.10),    // deep amber
            paceTempo: Color(red: 0.91, green: 0.63, blue: 0.19),        // amber
            paceModerate: Color(red: 0.22, green: 1.0, blue: 0.08),      // green
            paceEasy: Color(red: 0.22, green: 1.0, blue: 0.08),          // green
            textPrimary: Color(red: 0.91, green: 0.63, blue: 0.19),      // #E8A030 amber text
            textSecondary: Color(red: 0.35, green: 0.29, blue: 0.20),    // #5A4A32 muted
            cardBackground: Color(red: 0.07, green: 0.05, blue: 0.03),
            watchCardBackground: Color(red: 0.07, green: 0.05, blue: 0.03),
            watchButtonBackground: Color(red: 0.14, green: 0.11, blue: 0.07)
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
            watchTimerDisplay: .system(size: 36, weight: .bold, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricSecondary: .system(size: 22, weight: .semibold, design: .monospaced),
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
            cardStyle: .meter,
            hasNeonGlow: false,
            hasScanlines: false,
            hasGridBackground: false,
            neonGlowColor: nil,
            cardCornerRadius: 8,
            buttonCornerRadius: 12,
            hasMeshBackground: false,
            hasHorizonGrid: false,
            hasLCDDotMatrix: false,
            hasCRTEffect: false,
            cardAccentBarWidth: 0
        )
    )
}
