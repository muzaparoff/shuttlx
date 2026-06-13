import SwiftUI
import Charts

// MARK: - ThemedLineChart
//
// Parameterised line / area chart. For `lineStyle == .smoothArea` (Clean) the
// existing Swift Charts LineMark + AreaMark catmullRom path is used unchanged.
// Other themes dispatch to a Canvas renderer or a styled Swift Charts variant.
//
// Accessibility: canvas layers are `.accessibilityHidden(true)` — callers own
// a card-level `.accessibilityLabel` with numeric summary.

struct ThemedLineChart: View {
    /// Parallel arrays of (x-label, y-value).
    let labels: [String]
    let values: [Double]
    let yUnit: String          // e.g. "'", "km"
    let chartHeight: CGFloat
    let chartStyle: ThemeChartStyle
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxValue: Double { values.max() ?? 1 }
    private var minValue: Double { values.min() ?? 0 }
    private var maxIndex: Int { values.indices.max(by: { values[$0] < values[$1] }) ?? 0 }

    var body: some View {
        if chartStyle.lineStyle == .smoothArea {
            swiftChartsLine
        } else {
            canvasLine
        }
    }

    // MARK: - Swift Charts (Clean + Mixtape + Classic Radio)

    private var swiftChartsLine: some View {
        let pairs = zip(labels, values).map { ($0, $1) }
        return ZStack {
            Chart {
                ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                    LineMark(
                        x: .value("Label", pair.0),
                        y: .value("Value", pair.1)
                    )
                    .foregroundStyle(chartStyle.accentColor)
                    .interpolationMethod(.catmullRom)
                    .symbol(symbolForMarker(chartStyle.pointMarker))
                    .symbolSize(30)

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

            // Classic Radio: needle pointer overlay at latest value
            if chartStyle.lineStyle == .smoothArea
                && chartStyle.pointMarker == .brassDot
                && !values.isEmpty {
                let safeRange = maxValue - minValue > 0 ? maxValue - minValue : 1
                let lastNorm = (values.last ?? 0 - minValue) / safeRange
                ClassicRadioNeedlePointer(
                    normalizedValue: lastNorm,
                    brassColor: chartStyle.accentColor,
                    chartHeight: chartHeight
                )
            }
        }
    }

    // MARK: - Canvas (Synthwave glowSmooth / Arcade / Neovim / FM Tuner stepped)

    private var canvasLine: some View {
        ZStack {
            // Synthwave perspective grid behind the line
            if chartStyle.lineStyle == .glowSmooth && chartStyle.signatureAccent {
                SynthwavePerspectiveGrid(
                    gridColor: chartStyle.gridColor,
                    opacity: chartStyle.gridOpacity
                )
                .frame(height: chartHeight)
            }

            Canvas { ctx, size in
                drawGrid(ctx: ctx, size: size)
                drawLine(ctx: ctx, size: size)
            }
            .frame(height: chartHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            // Axis labels
            axisLabels
                .frame(height: chartHeight)
        }
    }

    // MARK: - Canvas: Grid

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        guard chartStyle.gridStyle != .none, chartStyle.gridStyle != .perspective else { return }
        let gridLines = 4
        let color = chartStyle.gridColor.opacity(chartStyle.gridOpacity)

        switch chartStyle.gridStyle {
        case .gutter:
            let gutterX: CGFloat = 28
            var path = Path()
            path.move(to: CGPoint(x: gutterX, y: 0))
            path.addLine(to: CGPoint(x: gutterX, y: size.height))
            ctx.stroke(path, with: .color(color), lineWidth: 1.0)
        case .scanline:
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), lineWidth: 0.4)
                y += 8
            }
        case .segments:
            for i in 1...gridLines {
                let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.5, dash: [2, 6]))
            }
        default:
            for i in 1...gridLines {
                let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Canvas: Line

    private func drawLine(ctx: GraphicsContext, size: CGSize) {
        guard values.count >= 2 else { return }

        let safeRange = maxValue - minValue > 0 ? maxValue - minValue : 1
        let gutterOffset: CGFloat = chartStyle.gridStyle == .gutter ? 30 : 0
        let usableW = size.width - gutterOffset
        let points = values.enumerated().map { (i, v) -> CGPoint in
            let x = gutterOffset + CGFloat(i) / CGFloat(values.count - 1) * usableW
            let y = size.height * (1.0 - CGFloat((v - minValue) / safeRange)) * 0.90 + size.height * 0.05
            return CGPoint(x: x, y: y)
        }

        // Area fill
        var areaPath = Path()
        areaPath.move(to: CGPoint(x: points[0].x, y: size.height))
        for p in points { areaPath.addLine(to: p) }
        areaPath.addLine(to: CGPoint(x: points.last!.x, y: size.height))
        areaPath.closeSubpath()
        ctx.fill(areaPath, with: .color(chartStyle.accentColor.opacity(0.15)))

        // Line stroke (glow = extra pass with blur simulated by wider stroke)
        if chartStyle.lineGlow {
            // Glow halo (wider, dimmer)
            var glowPath = buildLinePath(points: points)
            ctx.stroke(glowPath, with: .color(chartStyle.accentColor.opacity(0.25)), lineWidth: 6)
        }

        let linePath = buildLinePath(points: points)
        ctx.stroke(linePath, with: .color(chartStyle.accentColor.opacity(0.90)), lineWidth: 2)

        // Point markers
        for (i, p) in points.enumerated() {
            drawPointMarker(ctx: ctx, at: p, isPeak: i == maxIndex)
        }
    }

    private func buildLinePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        switch chartStyle.lineStyle {
        case .stepped:
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: CGPoint(x: points[i].x, y: points[i - 1].y))
                path.addLine(to: points[i])
            }
        default:
            // Catmull-Rom approximation: simple cubic Bezier
            path.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
                let cp2 = CGPoint(x: curr.x - (curr.x - prev.x) * 0.5, y: curr.y)
                path.addCurve(to: curr, control1: cp1, control2: cp2)
            }
        }
        return path
    }

    private func drawPointMarker(ctx: GraphicsContext, at point: CGPoint, isPeak: Bool) {
        let r: CGFloat = isPeak ? 5 : 3.5
        switch chartStyle.pointMarker {
        case .circle, .brassDot:
            ctx.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .color(chartStyle.accentColor.opacity(isPeak ? 1.0 : 0.80))
            )
        case .diamond:
            var d = Path()
            d.move(to: CGPoint(x: point.x, y: point.y - r))
            d.addLine(to: CGPoint(x: point.x + r, y: point.y))
            d.addLine(to: CGPoint(x: point.x, y: point.y + r))
            d.addLine(to: CGPoint(x: point.x - r, y: point.y))
            d.closeSubpath()
            ctx.fill(d, with: .color(chartStyle.accentColor.opacity(isPeak ? 1.0 : 0.85)))
        case .square:
            ctx.fill(
                Path(CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                with: .color(chartStyle.accentColor.opacity(isPeak ? 1.0 : 0.80))
            )
        case .none:
            break
        }
    }

    // MARK: - Axis Labels

    private var axisLabels: some View {
        GeometryReader { geo in
            let gutterOffset: CGFloat = chartStyle.gridStyle == .gutter ? 30 : 0
            let usableW = geo.size.width - gutterOffset
            let count = max(labels.count, 1)

            ZStack(alignment: .bottomLeading) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    let x = gutterOffset + CGFloat(idx) / CGFloat(count - 1) * usableW
                    Text(label)
                        .font(.system(size: 8, weight: .regular, design:
                            chartStyle.axisLabelStyle == .system ? .default : .monospaced
                        ))
                        .tracking(chartStyle.axisLabelTracking)
                        .foregroundStyle(chartStyle.axisLabelColor)
                        .minimumScaleFactor(0.8)
                        .accessibilityHidden(chartStyle.axisLabelStyle == .lineNumber)
                        .position(x: x, y: geo.size.height - 6)
                }

                if chartStyle.axisLabelStyle == .lineNumber {
                    let lineCount = 6
                    ForEach(0..<lineCount, id: \.self) { row in
                        let y = geo.size.height * CGFloat(row) / CGFloat(lineCount)
                        Text(String(format: "%2d", lineCount - row))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(chartStyle.axisLabelColor)
                            .accessibilityHidden(true)
                            .position(x: 12, y: y + 6)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func symbolForMarker(_ marker: ThemeChartStyle.PointMarker) -> some ChartSymbolShape {
        switch marker {
        case .circle, .brassDot: return BasicChartSymbolShape.circle
        case .diamond: return BasicChartSymbolShape.diamond
        case .square: return BasicChartSymbolShape.square
        case .none: return BasicChartSymbolShape.circle  // hidden via symbolSize 0
        }
    }
}
