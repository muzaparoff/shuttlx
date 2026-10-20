import SwiftUI
import Charts

// MARK: - ThemedBarChart
//
// Parameterised vertical bar chart.
// `.roundedSwiftCharts` (Clean) — Swift Charts BarMark.
//
// Callers must provide `.accessibilityLabel` with a numeric summary.

struct ThemedBarChart: View {
    let values: [Double]
    let labels: [String]
    let yUnit: String
    let chartHeight: CGFloat
    let chartStyle: ThemeChartStyle
    @Environment(ThemeManager.self) private var themeManager

    private var maxValue: Double { values.max() ?? 1 }
    private var maxIndex: Int { values.indices.max(by: { values[$0] < values[$1] }) ?? 0 }

    var body: some View {
        swiftChartsBar
    }

    // MARK: - Swift Charts (Clean)

    private var swiftChartsBar: some View {
        let pairs = zip(labels, values).map { ($0, $1) }
        return Chart {
            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                BarMark(
                    x: .value("Label", pair.0),
                    y: .value("Value", pair.1)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            chartStyle.accentColor.opacity(0.8),
                            chartStyle.accentColor.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
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
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
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

    // MARK: - Empty state factory

    static func emptyState(chartStyle: ThemeChartStyle, height: CGFloat) -> some View {
        ThemedBarChartEmpty(chartStyle: chartStyle, height: height)
    }
}

// MARK: - Empty State View

private struct ThemedBarChartEmpty: View {
    let chartStyle: ThemeChartStyle
    let height: CGFloat

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                skeletonBars
                Text("Not enough data")
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(chartStyle.axisLabelColor.opacity(0.60))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private var skeletonBars: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                let h = CGFloat([0.3, 0.5, 0.4, 0.7, 0.6, 0.4][i]) * (height - 30)
                RoundedRectangle(cornerRadius: 3)
                    .fill(chartStyle.accentColor.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: h)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height - 30)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(chartStyle.accentColor.opacity(0.08))
                .frame(height: 1)
        }
    }
}
