import SwiftUI

// MARK: - ThemeChartStyle
//
// Parameterises how analytics charts are rendered for each of the 8 themes.
// Sits alongside ThemeColors / ThemeFonts / ThemeEffects inside AppTheme.
// iOS-only — the watch target has no analytics charts.

struct ThemeChartStyle: Equatable {

    // ── Grid ─────────────────────────────────────────────────────────────────
    enum GridStyle: String, Equatable {
        case dashed       // Clean — stock AxisGridLine
        case solid        // Classic Radio
        case dotted       // Mixtape
        case scanline     // Arcade — denser horizontal lines
        case perspective  // Synthwave — converging lines under the chart
        case gutter       // Neovim — vertical left gutter, no horizontal grid
        case segments     // FM Tuner — faint LCD segment hash marks
        case none         // VU Meter — meter face IS the chart
    }
    let gridStyle: GridStyle
    let gridColor: Color
    let gridOpacity: Double

    // ── Bars ─────────────────────────────────────────────────────────────────
    enum BarShape: String, Equatable {
        case roundedSwiftCharts   // Clean — stock BarMark with cornerRadius
        case neonStroke           // Synthwave — Canvas fill + 2px glowing stroke
        case pixelBlocks          // Arcade — Canvas stacked 6×6 pixel blocks
        case lcdSegments          // FM Tuner — Canvas stacked 4px horizontal segs
        case tapeStrip            // Mixtape — Canvas bar with tape-edge stripes
        case dbMeter              // VU Meter — Canvas horizontal segmented amber bars
        case blockChars           // Neovim — Canvas bars of ▁▂▃▄▅▆▇█ rows
        case needle               // Classic Radio — Canvas line + needle at value
    }
    let barShape: BarShape

    enum BarFill: String, Equatable {
        case solid
        case gradientVertical     // default — 0.8 → 0.4
        case glow                 // solid + outer blur (Synthwave / Arcade peak)
        case stepped              // VU Meter segments
    }
    let barFill: BarFill

    // ── Lines / area ─────────────────────────────────────────────────────────
    enum LineStyle: String, Equatable {
        case smoothArea      // Clean — LineMark + AreaMark catmullRom
        case glowSmooth      // Synthwave — same shape + glow halo
        case stepped         // Neovim, FM Tuner — stepCenter interpolation
        case needleTip       // Classic Radio — line + needle pointer at latest value
    }
    let lineStyle: LineStyle

    /// When true the line chart renders a second LineMark with .blur for a glow halo.
    let lineGlow: Bool

    // ── Point markers (line chart) ────────────────────────────────────────────
    enum PointMarker: String, Equatable {
        case circle           // Clean default
        case diamond          // Synthwave
        case square           // Arcade
        case none             // FM Tuner, Neovim, VU Meter
        case brassDot         // Classic Radio
    }
    let pointMarker: PointMarker

    // ── Axis labels ──────────────────────────────────────────────────────────
    enum AxisLabelStyle: String, Equatable {
        case system           // Clean — current microLabel
        case monospaced       // Synthwave, FM Tuner, Arcade
        case sevenSegment     // Arcade — monospaced + wide letter-spacing
        case lineNumber       // Neovim — right-aligned grey gutter numbers
        case lcdSubtitle      // FM Tuner — cyan all-caps
    }
    let axisLabelStyle: AxisLabelStyle
    let axisLabelColor: Color
    let axisLabelTracking: CGFloat   // 0 = Clean / ClassicRadio; up to 2 for Arcade

    // ── Accent / highlight ────────────────────────────────────────────────────
    /// Color applied to the maximum bar / latest data point peak marker.
    let accentColor: Color
    let highlightPeak: Bool

    // ── Signature accent flag ─────────────────────────────────────────────────
    /// When true the renderer calls the theme's one signature accent decorator.
    let signatureAccent: Bool

    // ── Equatable ─────────────────────────────────────────────────────────────
    // Color is not Equatable by default; compare by RGB components is overkill
    // here — theme structs are value types and only change on theme switch.
    static func == (lhs: ThemeChartStyle, rhs: ThemeChartStyle) -> Bool {
        lhs.gridStyle == rhs.gridStyle
            && lhs.gridOpacity == rhs.gridOpacity
            && lhs.barShape == rhs.barShape
            && lhs.barFill == rhs.barFill
            && lhs.lineStyle == rhs.lineStyle
            && lhs.lineGlow == rhs.lineGlow
            && lhs.pointMarker == rhs.pointMarker
            && lhs.axisLabelStyle == rhs.axisLabelStyle
            && lhs.axisLabelTracking == rhs.axisLabelTracking
            && lhs.highlightPeak == rhs.highlightPeak
            && lhs.signatureAccent == rhs.signatureAccent
    }
}
