import SwiftUI

extension AppTheme {
    static let mixtape = AppTheme(
        id: "mixtape",
        displayName: "Mixtape",
        icon: "cassette.fill",
        colors: ThemeColors(
            background: Color(red: 0.141, green: 0.153, blue: 0.169),         // #24272B gunmetal body
            surface: Color(red: 0.180, green: 0.196, blue: 0.216),             // #2E3237 body panel
            surfaceBorder: Color(red: 0.784, green: 0.804, blue: 0.827),       // #C8CDD3 brushed chrome
            running: Color(red: 1.0, green: 0.769, blue: 0.302),               // #FFC44D amber LCD
            walking: Color(red: 0.557, green: 0.584, blue: 0.616),             // #8E959D chrome-dim
            heartRate: Color(red: 1.0, green: 0.231, blue: 0.188),             // #FF3B30 LED red
            steps: Color(red: 1.0, green: 0.769, blue: 0.302),                 // #FFC44D amber LCD
            calories: Color(red: 0.557, green: 0.584, blue: 0.616),            // chrome-dim
            stationary: Color(red: 0.420, green: 0.443, blue: 0.471),          // muted chrome
            cycling: Color(red: 1.0, green: 0.769, blue: 0.302),               // amber LCD
            swimming: Color(red: 0.0, green: 0.80, blue: 0.80),                // teal (keep)
            hiking: Color(red: 0.557, green: 0.584, blue: 0.616),              // chrome-dim
            elliptical: Color(red: 1.0, green: 0.769, blue: 0.302),            // amber LCD
            crossTraining: Color(red: 0.557, green: 0.584, blue: 0.616),       // chrome-dim
            ctaPrimary: Color(red: 0.243, green: 0.812, blue: 0.427),          // #3ECF6D ctaPlay green
            ctaDestructive: Color(red: 1.0, green: 0.231, blue: 0.188),        // #FF3B30 LED red
            ctaWarning: Color(red: 1.0, green: 0.639, blue: 0.094),            // #FFA318 ledAmber
            ctaPause: Color(red: 1.0, green: 0.639, blue: 0.094),              // #FFA318 ledAmber pause
            iconOnCTA: Color(red: 0.082, green: 0.090, blue: 0.102),           // #15171A bodyDeep
            hrZone1: Color(red: 0.498, green: 0.796, blue: 0.643),             // #7FCBA4 pale green
            hrZone2: Color(red: 0.216, green: 0.769, blue: 0.388),             // #37C463 green
            hrZone3: Color(red: 1.0, green: 0.541, blue: 0.239),               // #FF8A3D orange
            hrZone4: Color(red: 1.0, green: 0.353, blue: 0.169),               // #FF5A2B deep orange
            hrZone5: Color(red: 1.0, green: 0.176, blue: 0.125),               // #FF2D20 red
            stepWork: Color(red: 1.0, green: 0.769, blue: 0.302),              // amber — work = running
            stepRest: Color(red: 0.557, green: 0.584, blue: 0.616),            // chrome-dim — rest
            stepWarmup: Color(red: 0.498, green: 0.796, blue: 0.643),          // pale green — warmup
            stepCooldown: Color(red: 0.216, green: 0.769, blue: 0.388),        // green — cooldown
            pace: Color(red: 0.557, green: 0.584, blue: 0.616),                // chrome-dim
            positive: Color(red: 0.243, green: 0.812, blue: 0.427),            // ctaPlay green
            negative: Color(red: 1.0, green: 0.231, blue: 0.188),              // LED red
            recoveryFresh: Color(red: 0.243, green: 0.812, blue: 0.427),       // ctaPlay green
            recoveryNormal: Color(red: 0.498, green: 0.796, blue: 0.643),      // pale green
            recoveryFatigued: Color(red: 1.0, green: 0.639, blue: 0.094),      // ledAmber
            recoveryOverreaching: Color(red: 1.0, green: 0.231, blue: 0.188),  // LED red
            paceInterval: Color(red: 1.0, green: 0.231, blue: 0.188),          // LED red
            paceThreshold: Color(red: 1.0, green: 0.353, blue: 0.169),         // deep orange
            paceTempo: Color(red: 1.0, green: 0.541, blue: 0.239),             // orange
            paceModerate: Color(red: 0.216, green: 0.769, blue: 0.388),        // green
            paceEasy: Color(red: 0.498, green: 0.796, blue: 0.643),            // pale green
            textPrimary: Color(red: 0.937, green: 0.906, blue: 0.824),         // #EFE7D2 cream label
            textSecondary: Color(red: 0.557, green: 0.584, blue: 0.616),       // #8E959D chrome-dim
            cardBackground: Color(red: 0.141, green: 0.153, blue: 0.169),      // #24272B
            watchCardBackground: Color(red: 0.180, green: 0.196, blue: 0.216), // #2E3237
            watchButtonBackground: Color(red: 0.212, green: 0.231, blue: 0.255)  // #363B41
        ),
        fonts: ThemeFonts(
            timerDisplay: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricLarge: .system(.largeTitle, design: .monospaced).weight(.bold),
            metricMedium: .system(.title2, design: .monospaced).weight(.semibold),
            metricSmall: .system(.body, design: .monospaced).weight(.medium),
            cardTitle: .system(.headline, design: .monospaced).weight(.semibold),
            cardSubtitle: .system(.subheadline, design: .monospaced),
            cardCaption: .system(.caption, design: .monospaced),
            sectionHeader: .system(.headline, design: .monospaced).weight(.bold),
            heroIcon: .system(size: 48),
            onboardingIcon: .system(size: 72),
            prValue: .system(.title3, design: .monospaced).weight(.bold),
            microLabel: .system(size: 9, design: .monospaced).weight(.heavy),
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
            cardStyle: .lcd,
            hasScanlines: true,
            neonGlowColor: nil,
            cardCornerRadius: 8,
            buttonCornerRadius: 8,
            hasMeshBackground: false,
            hasLCDDotMatrix: true
        ),
        chartStyle: ThemeChartStyle(
            gridStyle: .dotted,
            gridColor: Color(red: 0.557, green: 0.584, blue: 0.616),
            gridOpacity: 0.20,
            barShape: .tapeStrip,
            barFill: .solid,
            lineStyle: .smoothArea,
            pointMarker: .none,
            axisLabelStyle: .monospaced,
            axisLabelColor: Color(red: 0.557, green: 0.584, blue: 0.616),
            axisLabelTracking: 1.4,
            accentColor: Color(red: 1.0, green: 0.769, blue: 0.302),  // amber LCD
            highlightPeak: false
        )
    )
}
