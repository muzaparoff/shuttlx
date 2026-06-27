import SwiftUI

// MARK: - ThemePreset
//
// Six personality starting points for building new themes. Each preset
// provides sensible defaults for a visual personality — override only the
// tokens that differ.
//
// Usage:
//   var t = ThemePreset.darkLCD.makeTheme(id: "myLCD", displayName: "My LCD", icon: "display")
//   t.colors.running = .cyan
//   AppTheme.all.append(t)

struct ThemePreset {
    var colors: ThemeColors
    var fonts: ThemeFonts
    var effects: ThemeEffects
    var chartStyle: ThemeChartStyle

    func makeTheme(id: String, displayName: String, icon: String) -> AppTheme {
        AppTheme(id: id, displayName: displayName, icon: icon,
                 colors: colors, fonts: fonts, effects: effects, chartStyle: chartStyle)
    }

    // MARK: Glass — Clean personality: soft glass cards, mesh background, system fonts
    static let glass: ThemePreset = {
        var e = ThemeEffects()
        e.hasMeshBackground = true
        return ThemePreset(colors: ThemeColors(), fonts: ThemeFonts(), effects: e, chartStyle: ThemeChartStyle())
    }()

    // MARK: Dark LCD — FM Tuner / Mixtape personality: deep navy, LCD cards, monospaced
    static let darkLCD: ThemePreset = {
        var c = ThemeColors()
        c.background     = Color(red: 0.008, green: 0.063, blue: 0.094)
        c.surface        = Color.white.opacity(0.08)
        c.textPrimary    = Color.cyan
        c.textSecondary  = Color.cyan.opacity(0.6)
        c.cardBackground = Color.white.opacity(0.08)

        var f = ThemeFonts()
        f.timerDisplay = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricLarge  = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricMedium = .system(.title2, design: .monospaced).weight(.semibold)

        var e = ThemeEffects()
        e.cardStyle          = .lcd
        e.hasLCDDotMatrix    = true
        e.cardCornerRadius   = 8
        e.buttonCornerRadius = 8

        var chart = ThemeChartStyle()
        chart.gridStyle      = .segments
        chart.barShape       = .lcdSegments
        chart.axisLabelStyle = .monospaced
        chart.axisLabelColor = Color.cyan.opacity(0.7)

        return ThemePreset(colors: c, fonts: f, effects: e, chartStyle: chart)
    }()

    // MARK: Neon — Synthwave personality: dark field, neon glow, horizon grid
    static let neon: ThemePreset = {
        var c = ThemeColors()
        c.background     = Color(red: 0.04, green: 0.04, blue: 0.10)
        c.surface        = Color.white.opacity(0.06)
        c.textPrimary    = Color(red: 0.95, green: 0.95, blue: 1.0)
        c.textSecondary  = Color.purple.opacity(0.8)
        c.running        = Color(red: 0.0, green: 1.0, blue: 0.8)
        c.heartRate      = Color(red: 1.0, green: 0.2, blue: 0.5)
        c.cardBackground = Color.white.opacity(0.06)

        var e = ThemeEffects()
        e.cardStyle          = .neon
        e.hasNeonGlow        = true
        e.neonGlowColor      = Color(red: 0.0, green: 1.0, blue: 0.8)
        e.hasHorizonGrid     = true
        e.hasGridBackground  = true
        e.cardCornerRadius   = 12
        e.buttonCornerRadius = 12

        var chart = ThemeChartStyle()
        chart.gridStyle       = .perspective
        chart.barShape        = .neonStroke
        chart.barFill         = .glow
        chart.lineStyle       = .glowSmooth
        chart.lineGlow        = true
        chart.pointMarker     = .diamond
        chart.axisLabelStyle  = .monospaced
        chart.accentColor     = Color(red: 0.0, green: 1.0, blue: 0.8)
        chart.signatureAccent = true

        return ThemePreset(colors: c, fonts: ThemeFonts(), effects: e, chartStyle: chart)
    }()

    // MARK: Warm Analog — Classic Radio personality: warm browns, tuning needle, brass accents
    static let warmAnalog: ThemePreset = {
        var c = ThemeColors()
        c.background     = Color(red: 0.12, green: 0.08, blue: 0.04)
        c.surface        = Color(red: 0.18, green: 0.13, blue: 0.08)
        c.textPrimary    = Color(red: 0.95, green: 0.88, blue: 0.72)
        c.textSecondary  = Color(red: 0.72, green: 0.62, blue: 0.45)
        c.running        = Color(red: 0.95, green: 0.55, blue: 0.15)
        c.cardBackground = Color(red: 0.18, green: 0.13, blue: 0.08)

        var e = ThemeEffects()
        e.cardStyle          = .meter
        e.cardCornerRadius   = 10
        e.buttonCornerRadius = 10

        var chart = ThemeChartStyle()
        chart.gridStyle      = .solid
        chart.gridColor      = Color(red: 0.5, green: 0.4, blue: 0.25)
        chart.barShape       = .needle
        chart.lineStyle      = .needleTip
        chart.pointMarker    = .brassDot
        chart.axisLabelColor = Color(red: 0.72, green: 0.62, blue: 0.45)

        return ThemePreset(colors: c, fonts: ThemeFonts(), effects: e, chartStyle: chart)
    }()

    // MARK: Pixel — Arcade personality: phosphor black, CRT scanlines, pixel art
    static let pixel: ThemePreset = {
        var c = ThemeColors()
        c.background     = Color.black
        c.surface        = Color(red: 0.0, green: 0.15, blue: 0.0)
        c.textPrimary    = Color(red: 0.2, green: 1.0, blue: 0.2)
        c.textSecondary  = Color(red: 0.15, green: 0.75, blue: 0.15)
        c.running        = Color(red: 0.2, green: 1.0, blue: 0.2)
        c.cardBackground = Color(red: 0.0, green: 0.1, blue: 0.0)

        var f = ThemeFonts()
        f.timerDisplay = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricLarge  = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricMedium = .system(.title2, design: .monospaced).weight(.bold)

        var e = ThemeEffects()
        e.cardStyle          = .pixel
        e.hasScanlines       = true
        e.hasCRTEffect       = true
        e.cardCornerRadius   = 4
        e.buttonCornerRadius = 4

        var chart = ThemeChartStyle()
        chart.gridStyle          = .scanline
        chart.barShape           = .pixelBlocks
        chart.axisLabelStyle     = .sevenSegment
        chart.axisLabelTracking  = 2
        chart.accentColor        = Color(red: 0.2, green: 1.0, blue: 0.2)

        return ThemePreset(colors: c, fonts: f, effects: e, chartStyle: chart)
    }()

    // MARK: Terminal — Neovim personality: Gruvbox dark, block cursor, gutter stripe
    static let terminal: ThemePreset = {
        var c = ThemeColors()
        c.background     = Color(red: 0.114, green: 0.125, blue: 0.129)
        c.surface        = Color(red: 0.157, green: 0.173, blue: 0.169)
        c.textPrimary    = Color(red: 0.922, green: 0.859, blue: 0.698)
        c.textSecondary  = Color(red: 0.659, green: 0.600, blue: 0.518)
        c.running        = Color(red: 0.722, green: 0.733, blue: 0.149)
        c.cardBackground = Color(red: 0.157, green: 0.173, blue: 0.169)

        var f = ThemeFonts()
        f.timerDisplay = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricLarge  = .system(.largeTitle, design: .monospaced).weight(.bold)
        f.metricMedium = .system(.title2, design: .monospaced).weight(.semibold)
        f.microLabel   = .system(.caption2, design: .monospaced)

        var e = ThemeEffects()
        e.cardStyle           = .terminal
        e.cardAccentBarWidth  = 4
        e.cardCornerRadius    = 6
        e.buttonCornerRadius  = 4

        var chart = ThemeChartStyle()
        chart.gridStyle      = .gutter
        chart.barShape       = .blockChars
        chart.lineStyle      = .stepped
        chart.pointMarker    = .none
        chart.axisLabelStyle = .lineNumber
        chart.axisLabelColor = Color(red: 0.659, green: 0.600, blue: 0.518)

        return ThemePreset(colors: c, fonts: f, effects: e, chartStyle: chart)
    }()
}
