import SwiftUI
import Charts

// MARK: - ThemedBarChart
//
// Parameterised vertical bar chart.
// `.roundedSwiftCharts` (Clean) — Swift Charts BarMark.
// `.tapeStrip` (Mixtape) — Canvas bars with horizontal tape-edge stripes.
//
// Accessibility: canvas layer is `.accessibilityHidden(true)` — callers must
// provide `.accessibilityLabel` with a numeric summary.

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
        if chartStyle.barShape == .roundedSwiftCharts {
            swiftChartsBar
        } else {
            canvasBar
        }
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

    // MARK: - Canvas Renderer (Mixtape tapeStrip)

    private var canvasBar: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { ctx, size in
                drawGrid(ctx: ctx, size: size)
                drawBars(ctx: ctx, size: size)
            }
            .frame(height: chartHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            axisLabels
                .frame(height: chartHeight)
        }
    }

    // MARK: - Canvas: Grid

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let gridLines = 4
        let color = chartStyle.gridColor.opacity(chartStyle.gridOpacity)
        let dash: [CGFloat] = chartStyle.gridStyle == .dotted ? [2, 4] : [4, 4]
        for i in 1...gridLines {
            let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.5, dash: dash))
        }
    }

    // MARK: - Canvas: Bars

    private func drawBars(ctx: GraphicsContext, size: CGSize) {
        guard !values.isEmpty else { return }
        let barCount = values.count
        let slotW = size.width / CGFloat(barCount)
        let bW: CGFloat = slotW * 0.60
        let safeMax = maxValue > 0 ? maxValue : 1

        for (i, value) in values.enumerated() {
            let barH = CGFloat(value / safeMax) * size.height
            let x = CGFloat(i) * slotW + (slotW - bW) / 2
            let y = size.height - barH
            let rect = CGRect(x: x, y: y, width: bW, height: barH)

            // Solid fill
            ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                     with: .color(chartStyle.accentColor.opacity(0.70)))

            // Horizontal tape-edge stripes every 6pt
            var stripeY = y + 3
            while stripeY < size.height {
                let stripeRect = CGRect(x: x, y: stripeY, width: bW, height: 1)
                ctx.fill(Path(stripeRect),
                         with: .color(chartStyle.accentColor.opacity(0.30)))
                stripeY += 6
            }
        }
    }

    // MARK: - Axis Labels

    private var axisLabels: some View {
        GeometryReader { geo in
            let barCount = max(values.count, 1)
            let slotW = geo.size.width / CGFloat(barCount)

            ZStack(alignment: .bottomLeading) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    let x = CGFloat(idx) * slotW + slotW * 0.5
                    Text(label)
                        .font(.system(size: 8, weight: .regular, design:
                            chartStyle.axisLabelStyle == .system ? .default : .monospaced
                        ))
                        .tracking(chartStyle.axisLabelTracking)
                        .foregroundStyle(chartStyle.axisLabelColor)
                        .minimumScaleFactor(0.8)
                        .position(x: x, y: geo.size.height - 6)
                }
            }
        }
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
            switch chartStyle.barShape {
            case .tapeStrip:
                Text("▶ SIDE B UNREC ▶")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(chartStyle.accentColor.opacity(0.55))
            default:
                VStack(spacing: 6) {
                    skeletonBars
                    Text("Not enough data")
                        .font(ShuttlXFont.microLabel)
                        .foregroundStyle(chartStyle.axisLabelColor.opacity(0.60))
                }
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
