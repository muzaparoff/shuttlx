import SwiftUI

extension AppTheme {
    static let fmTuner = AppTheme(
        id: "fmtuner",
        displayName: "FM Tuner",
        icon: "antenna.radiowaves.left.and.right",
        colors: ThemeColors(
            // Background & surfaces
            background: Color(red: 0.008, green: 0.063, blue: 0.094),       // #021018 deep navy LCD
            surface: Color(red: 0.024, green: 0.125, blue: 0.161),          // #062029 panel
            surfaceBorder: Color(red: 0.039, green: 0.294, blue: 0.361),    // #0A4B5C PCB silk
            // Activity — all cyan-family
            running: Color(red: 0.486, green: 0.847, blue: 1.000),          // #7CD8FF bright cyan
            walking: Color(red: 0.227, green: 0.561, blue: 0.659),          // #3A8FA8 mid cyan
            heartRate: Color(red: 0.486, green: 0.847, blue: 1.000),
            steps: Color(red: 0.227, green: 0.561, blue: 0.659),
            calories: Color(red: 0.486, green: 0.847, blue: 1.000),
            stationary: Color(red: 0.055, green: 0.396, blue: 0.502),       // #0E6580 dim cyan
            // Sport — variation by brightness only
            cycling: Color(red: 0.486, green: 0.847, blue: 1.000),
            swimming: Color(red: 0.227, green: 0.561, blue: 0.659),
            hiking: Color(red: 0.055, green: 0.396, blue: 0.502),
            elliptical: Color(red: 0.486, green: 0.847, blue: 1.000),
            crossTraining: Color(red: 0.227, green: 0.561, blue: 0.659),
            // CTA
            ctaPrimary: Color(red: 0.486, green: 0.847, blue: 1.000),       // #7CD8FF bright cyan
            ctaDestructive: Color(red: 1.000, green: 0.420, blue: 0.420),   // #FF6B6B (only non-cyan)
            ctaWarning: Color(red: 0.486, green: 0.847, blue: 1.000),
            ctaPause: Color(red: 0.486, green: 0.847, blue: 1.000),
            iconOnCTA: Color(red: 0.008, green: 0.063, blue: 0.094),
            // HR Zones (1-5) — dim → bright
            hrZone1: Color(red: 0.055, green: 0.396, blue: 0.502),          // #0E6580
            hrZone2: Color(red: 0.137, green: 0.490, blue: 0.580),          // #237CA5
            hrZone3: Color(red: 0.227, green: 0.561, blue: 0.659),          // #3A8FA8
            hrZone4: Color(red: 0.345, green: 0.694, blue: 0.831),          // #58B1D4
            hrZone5: Color(red: 0.486, green: 0.847, blue: 1.000),          // #7CD8FF
            // Interval steps
            stepWork: Color(red: 0.486, green: 0.847, blue: 1.000),
            stepRest: Color(red: 0.227, green: 0.561, blue: 0.659),
            stepWarmup: Color(red: 0.345, green: 0.694, blue: 0.831),
            stepCooldown: Color(red: 0.137, green: 0.490, blue: 0.580),
            // Semantic
            pace: Color(red: 0.486, green: 0.847, blue: 1.000),
            positive: Color(red: 0.486, green: 0.847, blue: 1.000),
            negative: Color(red: 1.000, green: 0.420, blue: 0.420),
            // Recovery
            recoveryFresh: Color(red: 0.486, green: 0.847, blue: 1.000),
            recoveryNormal: Color(red: 0.345, green: 0.694, blue: 0.831),
            recoveryFatigued: Color(red: 0.227, green: 0.561, blue: 0.659),
            recoveryOverreaching: Color(red: 1.000, green: 0.420, blue: 0.420),
            // Pace zones
            paceInterval: Color(red: 0.486, green: 0.847, blue: 1.000),
            paceThreshold: Color(red: 0.345, green: 0.694, blue: 0.831),
            paceTempo: Color(red: 0.227, green: 0.561, blue: 0.659),
            paceModerate: Color(red: 0.137, green: 0.490, blue: 0.580),
            paceEasy: Color(red: 0.055, green: 0.396, blue: 0.502),
            // Text
            textPrimary: Color(red: 0.486, green: 0.847, blue: 1.000),      // #7CD8FF
            textSecondary: Color(red: 0.227, green: 0.561, blue: 0.659),    // #3A8FA8
            // Card backgrounds
            cardBackground: Color(red: 0.024, green: 0.125, blue: 0.161),   // #062029
            // Watch surfaces (slightly darker for OLED)
            watchCardBackground: Color(red: 0.016, green: 0.094, blue: 0.125),  // #04181F
            watchButtonBackground: Color(red: 0.039, green: 0.196, blue: 0.251) // #0A3240
        ),
        fonts: ThemeFonts(
            // Shared (iOS values listed for type parity — watch uses watch-specific below)
            timerDisplay:        .system(size: 40, weight: .heavy, design: .monospaced),
            metricLarge:         .system(size: 36, weight: .heavy, design: .monospaced),
            metricMedium:        .system(size: 22, weight: .heavy, design: .monospaced),
            metricSmall:         .system(size: 14, weight: .heavy, design: .monospaced),
            cardTitle:           .system(size: 14, weight: .heavy, design: .monospaced),
            cardSubtitle:        .system(size: 11, weight: .heavy, design: .monospaced),
            cardCaption:         .system(size: 9,  weight: .heavy, design: .monospaced),
            sectionHeader:       .system(size: 12, weight: .heavy, design: .monospaced),
            // iOS-specific (declared for parity; not referenced on watch)
            heroIcon:            .system(size: 32, weight: .heavy),
            onboardingIcon:      .system(size: 48, weight: .heavy),
            prValue:             .system(size: 18, weight: .heavy, design: .monospaced),
            microLabel:          .system(size: 8,  weight: .bold,  design: .monospaced),
            debugMono:           .system(size: 9,  weight: .regular, design: .monospaced),
            // watchOS-specific — the ones that matter on this target
            watchTimerDisplay:       .system(size: 40, weight: .heavy, design: .monospaced),
            watchMetricDisplay:      .system(size: 36, weight: .heavy, design: .monospaced),
            watchMetricSecondary:    .system(size: 22, weight: .heavy, design: .monospaced),
            watchStepLabel:          .system(size: 13, weight: .heavy, design: .monospaced),
            watchControlIcon:        .system(size: 22, weight: .heavy),
            watchControlLabel:       .system(size: 11, weight: .heavy, design: .monospaced),
            watchStatusBadge:        .system(size: 12, weight: .heavy, design: .monospaced),
            watchSummaryTimer:       .system(size: 26, weight: .heavy, design: .monospaced),
            watchSummaryMetric:      .system(size: 15, weight: .heavy, design: .monospaced),
            watchHeroIcon:           .system(size: 26, weight: .heavy),
            watchHeroTitle:          .system(size: 16, weight: .heavy, design: .monospaced),
            watchTemplateTitle:      .system(size: 13, weight: .heavy, design: .monospaced)
        ),
        effects: ThemeEffects(
            cardStyle: .lcd,
            hasNeonGlow: false,
            hasScanlines: false,
            hasGridBackground: false,
            neonGlowColor: nil,
            cardCornerRadius: 4,
            buttonCornerRadius: 4,
            hasMeshBackground: false,
            hasHorizonGrid: false,
            hasLCDDotMatrix: false,
            hasCRTEffect: false,
            cardAccentBarWidth: 0
        )
    )
}
