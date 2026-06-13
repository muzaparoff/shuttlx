import SwiftUI

extension AppTheme {
    static let fmTuner = AppTheme(
        id: "fmtuner",
        displayName: "FM Tuner",
        icon: "antenna.radiowaves.left.and.right",
        colors: ThemeColors(
            // Background & surfaces
            background:        Color(red: 0.008, green: 0.063, blue: 0.094),  // #021018 deep navy LCD
            surface:           Color(red: 0.024, green: 0.125, blue: 0.161),  // #062029 panel
            surfaceBorder:     Color(red: 0.039, green: 0.294, blue: 0.361),  // #0A4B5C PCB silk

            // Activity
            running:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
            walking:           Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid cyan
            heartRate:         Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
            steps:             Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid cyan
            calories:          Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
            stationary:        Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580 dim cyan

            // Sport
            cycling:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
            swimming:          Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8
            hiking:            Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580
            elliptical:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
            crossTraining:     Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8

            // CTA
            ctaPrimary:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright cyan
            ctaDestructive:    Color(red: 1.000, green: 0.420, blue: 0.420),  // #FF6B6B (only non-cyan)
            ctaWarning:        Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
            ctaPause:          Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF
            iconOnCTA:         Color(red: 0.008, green: 0.063, blue: 0.094),  // #021018 background

            // HR Zones (dim -> bright as intensity climbs)
            hrZone1:           Color(red: 0.055, green: 0.396, blue: 0.502),  // #0E6580 dim
            hrZone2:           Color(red: 0.137, green: 0.490, blue: 0.580),  // #237CA5
            hrZone3:           Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 mid
            hrZone4:           Color(red: 0.345, green: 0.694, blue: 0.831),  // #58B1D4
            hrZone5:           Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF bright

            // Interval steps
            stepWork:          Color(red: 0.486, green: 0.847, blue: 1.000),  // bright cyan
            stepRest:          Color(red: 0.227, green: 0.561, blue: 0.659),  // mid cyan
            stepWarmup:        Color(red: 0.345, green: 0.694, blue: 0.831),  // interp
            stepCooldown:      Color(red: 0.137, green: 0.490, blue: 0.580),  // interp dim

            // Semantic
            pace:              Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
            positive:          Color(red: 0.486, green: 0.847, blue: 1.000),  // bright (no green in this theme)
            negative:          Color(red: 1.000, green: 0.420, blue: 0.420),  // #FF6B6B red

            // Recovery
            recoveryFresh:        Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
            recoveryNormal:       Color(red: 0.345, green: 0.694, blue: 0.831),
            recoveryFatigued:     Color(red: 0.227, green: 0.561, blue: 0.659),
            recoveryOverreaching: Color(red: 1.000, green: 0.420, blue: 0.420),  // red

            // Pace zones
            paceInterval:      Color(red: 0.486, green: 0.847, blue: 1.000),  // bright
            paceThreshold:     Color(red: 0.345, green: 0.694, blue: 0.831),
            paceTempo:         Color(red: 0.227, green: 0.561, blue: 0.659),
            paceModerate:      Color(red: 0.137, green: 0.490, blue: 0.580),
            paceEasy:          Color(red: 0.055, green: 0.396, blue: 0.502),  // dim

            // Text
            textPrimary:       Color(red: 0.486, green: 0.847, blue: 1.000),  // #7CD8FF (~12.5:1 on #021018)
            textSecondary:     Color(red: 0.227, green: 0.561, blue: 0.659),  // #3A8FA8 (~4.8:1 — AA)

            // Card backgrounds
            cardBackground:    Color(red: 0.024, green: 0.125, blue: 0.161),  // #062029

            // Watch surfaces (slightly darker for OLED)
            watchCardBackground:   Color(red: 0.016, green: 0.094, blue: 0.125),  // #04181F
            watchButtonBackground: Color(red: 0.039, green: 0.196, blue: 0.251)   // #0A3240
        ),
        fonts: ThemeFonts(
            timerDisplay:     .system(size: 56, weight: .heavy, design: .monospaced),
            metricLarge:      .system(size: 44, weight: .heavy, design: .monospaced),
            metricMedium:     .system(size: 28, weight: .heavy, design: .monospaced),
            metricSmall:      .system(size: 16, weight: .bold,  design: .monospaced),
            cardTitle:        .system(size: 16, weight: .heavy, design: .monospaced),
            cardSubtitle:     .system(size: 12, weight: .bold,  design: .monospaced),
            cardCaption:      .system(size: 10, weight: .bold,  design: .monospaced),
            sectionHeader:    .system(size: 13, weight: .heavy, design: .monospaced),
            heroIcon:         .system(size: 48, weight: .heavy),
            onboardingIcon:   .system(size: 72, weight: .heavy),
            prValue:          .system(size: 22, weight: .heavy, design: .monospaced),
            microLabel:       .system(size: 9,  weight: .bold,  design: .monospaced),
            debugMono:        .system(size: 10, weight: .regular, design: .monospaced),
            watchTimerDisplay:    .system(size: 40, weight: .heavy, design: .monospaced),
            watchMetricDisplay:   .system(size: 36, weight: .heavy, design: .monospaced),
            watchMetricSecondary: .system(size: 22, weight: .heavy, design: .monospaced),
            watchStepLabel:       .system(size: 13, weight: .heavy, design: .monospaced),
            watchControlIcon:     .system(size: 26, weight: .heavy),
            watchControlLabel:    .system(size: 11, weight: .heavy, design: .monospaced),
            watchStatusBadge:     .system(size: 13, weight: .heavy, design: .monospaced),
            watchSummaryTimer:    .system(size: 28, weight: .heavy, design: .monospaced),
            watchSummaryMetric:   .system(size: 16, weight: .heavy, design: .monospaced),
            watchHeroIcon:        .system(size: 32, weight: .heavy),
            watchHeroTitle:       .system(size: 18, weight: .heavy, design: .monospaced),
            watchTemplateTitle:   .system(size: 14, weight: .heavy, design: .monospaced)
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
        ),
        chartStyle: ThemeChartStyle(
            gridStyle: .segments,
            gridColor: Color(red: 0.486, green: 0.847, blue: 1.000),  // ctaPrimary cyan
            gridOpacity: 0.15,
            barShape: .lcdSegments,
            barFill: .stepped,
            lineStyle: .stepped,
            lineGlow: false,
            pointMarker: .none,
            axisLabelStyle: .lcdSubtitle,
            axisLabelColor: Color(red: 0.227, green: 0.561, blue: 0.659),  // textSecondary
            axisLabelTracking: 1.5,
            accentColor: Color(red: 0.486, green: 0.847, blue: 1.000),     // ctaPrimary cyan
            highlightPeak: true,
            signatureAccent: false
        )
    )
}
