import SwiftUI

extension AppTheme {
    static let neovim = AppTheme(
        id: "neovim",
        displayName: "Neovim",
        icon: "chevron.left.forwardslash.chevron.right",
        colors: ThemeColors(
            background: Color(red: 0.114, green: 0.125, blue: 0.129),      // #1D2021 bg0_h
            surface: Color(red: 0.157, green: 0.157, blue: 0.157),         // #282828 bg0
            surfaceBorder: Color(red: 0.235, green: 0.220, blue: 0.212).opacity(0.5), // #3C3836 bg1
            running: Color(red: 0.722, green: 0.733, blue: 0.149),         // #B8BB26 green
            walking: Color(red: 0.557, green: 0.753, blue: 0.486),         // #8EC07C aqua
            heartRate: Color(red: 0.984, green: 0.286, blue: 0.204),       // #FB4934 red
            steps: Color(red: 0.980, green: 0.741, blue: 0.184),           // #FABD2F yellow
            calories: Color(red: 0.996, green: 0.502, blue: 0.098),        // #FE8019 orange
            stationary: Color(red: 0.314, green: 0.286, blue: 0.271),      // #504945 bg2
            cycling: Color(red: 0.514, green: 0.647, blue: 0.596),         // #83A598 blue
            swimming: Color(red: 0.557, green: 0.753, blue: 0.486),        // #8EC07C aqua
            hiking: Color(red: 0.996, green: 0.502, blue: 0.098),          // #FE8019 orange
            elliptical: Color(red: 0.827, green: 0.525, blue: 0.608),      // #D3869B purple
            crossTraining: Color(red: 0.980, green: 0.741, blue: 0.184),   // #FABD2F yellow
            ctaPrimary: Color(red: 0.722, green: 0.733, blue: 0.149),      // #B8BB26 green
            ctaDestructive: Color(red: 0.984, green: 0.286, blue: 0.204),  // #FB4934 red
            ctaWarning: Color(red: 0.980, green: 0.741, blue: 0.184),      // #FABD2F yellow
            ctaPause: Color(red: 0.557, green: 0.753, blue: 0.486),        // #8EC07C aqua
            iconOnCTA: Color(red: 0.114, green: 0.125, blue: 0.129),       // #1D2021 bg0_h
            hrZone1: Color(red: 0.514, green: 0.647, blue: 0.596),         // blue
            hrZone2: Color(red: 0.722, green: 0.733, blue: 0.149),         // green
            hrZone3: Color(red: 0.980, green: 0.741, blue: 0.184),         // yellow
            hrZone4: Color(red: 0.996, green: 0.502, blue: 0.098),         // orange
            hrZone5: Color(red: 0.984, green: 0.286, blue: 0.204),         // red
            stepWork: Color(red: 0.984, green: 0.286, blue: 0.204),        // #FB4934 red
            stepRest: Color(red: 0.514, green: 0.647, blue: 0.596),        // #83A598 blue
            stepWarmup: Color(red: 0.557, green: 0.753, blue: 0.486),      // #8EC07C aqua
            stepCooldown: Color(red: 0.827, green: 0.525, blue: 0.608),    // #D3869B purple
            pace: Color(red: 0.827, green: 0.525, blue: 0.608),            // #D3869B purple
            positive: Color(red: 0.722, green: 0.733, blue: 0.149),        // green
            negative: Color(red: 0.984, green: 0.286, blue: 0.204),        // red
            recoveryFresh: Color(red: 0.722, green: 0.733, blue: 0.149),   // green
            recoveryNormal: Color(red: 0.514, green: 0.647, blue: 0.596),  // blue
            recoveryFatigued: Color(red: 0.980, green: 0.741, blue: 0.184), // yellow
            recoveryOverreaching: Color(red: 0.984, green: 0.286, blue: 0.204), // red
            paceInterval: Color(red: 0.984, green: 0.286, blue: 0.204),    // red
            paceThreshold: Color(red: 0.996, green: 0.502, blue: 0.098),   // orange
            paceTempo: Color(red: 0.980, green: 0.741, blue: 0.184),       // yellow
            paceModerate: Color(red: 0.557, green: 0.753, blue: 0.486),    // aqua
            paceEasy: Color(red: 0.514, green: 0.647, blue: 0.596),        // blue
            textPrimary: Color(red: 0.922, green: 0.859, blue: 0.698),     // #EBDBB2 fg
            textSecondary: Color(red: 0.573, green: 0.514, blue: 0.455),   // #928374 gray
            cardBackground: Color(red: 0.157, green: 0.157, blue: 0.157),  // bg0
            watchCardBackground: Color(red: 0.157, green: 0.157, blue: 0.157), // bg0
            watchButtonBackground: Color(red: 0.314, green: 0.286, blue: 0.271) // #504945 bg2
        ),
        fonts: ThemeFonts(
            timerDisplay: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricLarge: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricMedium: .system(.title2, design: .monospaced).weight(.semibold),
            metricSmall: .system(.body, design: .monospaced).weight(.medium),
            cardTitle: .system(.headline, design: .monospaced).weight(.semibold),
            cardSubtitle: .system(.subheadline, design: .monospaced),
            cardCaption: .system(.caption, design: .monospaced),
            sectionHeader: .system(.headline, design: .monospaced).weight(.semibold),
            heroIcon: .system(size: 48, weight: .semibold),
            onboardingIcon: .system(size: 72, weight: .semibold),
            prValue: .system(.title3, design: .monospaced).weight(.bold),
            microLabel: .system(size: 9, design: .monospaced),
            debugMono: .system(.caption, design: .monospaced),
            watchTimerDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricDisplay: .system(size: 40, weight: .bold, design: .monospaced),
            watchMetricSecondary: .system(size: 24, weight: .semibold, design: .monospaced),
            watchStepLabel: .system(size: 13, weight: .bold, design: .monospaced),
            watchControlIcon: .system(size: 26, weight: .semibold),
            watchControlLabel: .system(size: 11, design: .monospaced),
            watchStatusBadge: .system(size: 13, weight: .bold, design: .monospaced),
            watchSummaryTimer: .system(.title, design: .monospaced).weight(.bold),
            watchSummaryMetric: .system(.body, design: .monospaced).weight(.semibold),
            watchHeroIcon: .system(size: 32, weight: .semibold),
            watchHeroTitle: .system(.title3, design: .monospaced).weight(.semibold),
            watchTemplateTitle: .system(.body, design: .monospaced).weight(.semibold)
        ),
        effects: ThemeEffects(
            cardStyle: .terminal,
            hasNeonGlow: false,
            hasScanlines: false,
            hasGridBackground: false,
            neonGlowColor: nil,
            cardCornerRadius: 4,
            buttonCornerRadius: 4,
            hasMeshBackground: false,
            hasHorizonGrid: false,
            hasLCDDotMatrix: false,
            hasCRTEffect: false
        )
    )
}
