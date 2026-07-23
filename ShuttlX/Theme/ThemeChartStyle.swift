import SwiftUI

// MARK: - ThemeChartStyle
//
// All properties carry Clean-theme defaults so new themes only declare what
// differs. iOS-only — the watch target has no analytics charts.

struct ThemeChartStyle: Equatable {

    // ── Grid ─────────────────────────────────────────────────────────────────
    enum GridStyle: String, Equatable {
        case dashed   // Clean — stock AxisGridLine
        case dotted   // Mixtape
    }
    var gridStyle: GridStyle   = .dashed
    var gridColor: Color       = Color(.secondarySystemFill)
    var gridOpacity: Double    = 0.30

    // ── Bars ─────────────────────────────────────────────────────────────────
    enum BarShape: String, Equatable {
        case roundedSwiftCharts   // Clean — stock BarMark with cornerRadius
        case tapeStrip            // Mixtape — Canvas bar with tape-edge stripes
    }
    var barShape: BarShape     = .roundedSwiftCharts

    enum BarFill: String, Equatable {
        case solid
        case gradientVertical     // default — 0.8 → 0.4
    }
    var barFill: BarFill       = .gradientVertical

    // ── Lines / area ─────────────────────────────────────────────────────────
    enum LineStyle: String, Equatable {
        case smoothArea   // Clean + Mixtape — LineMark + AreaMark catmullRom
    }
    var lineStyle: LineStyle   = .smoothArea

    // ── Point markers (line chart) ────────────────────────────────────────────
    enum PointMarker: String, Equatable {
        case circle   // Clean default
        case none     // Mixtape
    }
    var pointMarker: PointMarker = .circle

    // ── Axis labels ──────────────────────────────────────────────────────────
    enum AxisLabelStyle: String, Equatable {
        case system       // Clean
        case monospaced   // Mixtape
    }
    var axisLabelStyle: AxisLabelStyle  = .system
    var axisLabelColor: Color           = Color(.secondaryLabel)
    var axisLabelTracking: CGFloat      = 0

    // ── Accent / highlight ────────────────────────────────────────────────────
    var accentColor: Color     = .green
    var highlightPeak: Bool    = false

    // ── Equatable ─────────────────────────────────────────────────────────────
    static func == (lhs: ThemeChartStyle, rhs: ThemeChartStyle) -> Bool {
        lhs.gridStyle == rhs.gridStyle
            && lhs.gridOpacity == rhs.gridOpacity
            && lhs.barShape == rhs.barShape
            && lhs.barFill == rhs.barFill
            && lhs.lineStyle == rhs.lineStyle
            && lhs.pointMarker == rhs.pointMarker
            && lhs.axisLabelStyle == rhs.axisLabelStyle
            && lhs.axisLabelTracking == rhs.axisLabelTracking
            && lhs.highlightPeak == rhs.highlightPeak
    }
}
