import SwiftUI
import Charts

// MARK: - ThemedLineChart
//
// Parameterised line / area chart using Swift Charts LineMark + AreaMark.
//
// Accessibility: callers own a card-level `.accessibilityLabel` with numeric summary.

struct ThemedLineChart: View {
    /// Parallel arrays of (x-label, y-value).
    let labels: [String]
    let values: [Double]
    let yUnit: String          // e.g. "'", "km"
    let chartHeight: CGFloat
    let chartStyle: ThemeChartStyle
    @Environment(ThemeManager.self) private var themeManager

    private var maxValue: Double { values.max() ?? 1 }
    private var minValue: Double { values.min() ?? 0 }

    var body: some View {
        swiftChartsLine
    }

    // MARK: - Swift Charts

    private var swiftChartsLine: some View {
        let pairs = zip(labels, values).map { ($0, $1) }
        return Chart {
            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                LineMark(
                    x: .value("Label", pair.0),
                    y: .value("Value", pair.1)
                )
                .foregroundStyle(chartStyle.accentColor)
                .interpolationMethod(.catmullRom)
                .symbol(symbolForMarker(chartStyle.pointMarker))
                .symbolSize(chartStyle.pointMarker == .none ? 0 : 30)

                AreaMark(
                    x: .value("Label", pair.0),
                    y: .value("Value", pair.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            chartStyle.accentColor.opacity(0.3),
                            chartStyle.accentColor.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))\(yUnit)")
                            .font(ShuttlXFont.microLabel)
                            .minimumScaleFactor(0.8)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: chartStyle.gridStyle == .dotted ? [1, 4] : [4]))
                    .foregroundStyle(chartStyle.gridColor.opacity(chartStyle.gridOpacity))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(ShuttlXFont.microLabel)
            }
        }
        .frame(height: chartHeight)
    }

    // MARK: - Helpers

    private func symbolForMarker(_ marker: ThemeChartStyle.PointMarker) -> some ChartSymbolShape {
        switch marker {
        case .circle: return BasicChartSymbolShape.circle
        case .none:   return BasicChartSymbolShape.circle  // hidden via symbolSize 0
        }
    }
}
