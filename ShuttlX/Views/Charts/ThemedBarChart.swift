import SwiftUI
import Charts

// MARK: - ThemedBarChart
//
// Parameterised vertical bar chart. For `barShape == .roundedSwiftCharts` (Clean),
// the existing Swift Charts BarMark path is used with no change to cardiac baseline.
// For all other themes a Canvas-based renderer reads ThemeChartStyle to draw the bars.
//
// Data contract:
//   - `values`: parallel array of Double, one per bar
//   - `labels`: parallel array of String (X-axis labels)
//   - `yLabel`: formatter closure for Y-axis labels
//   - `chartHeight`: explicit height for the chart area
//
// Accessibility: the canvas layer is `.accessibilityHidden(true)` — callers
// must wrap the entire card in `.accessibilityElement(children: .combine)` with
// a numeric summary `.accessibilityLabel`.

struct ThemedBarChart: View {
    let values: [Double]
    let labels: [String]
    let yUnit: String          // e.g. "m" for minutes, "km" for distance
    let chartHeight: CGFloat
    let chartStyle: ThemeChartStyle
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Computed helpers
    private var maxValue: Double { values.max() ?? 1 }
    private var maxIndex: Int { values.indices.max(by: { values[$0] < values[$1] }) ?? 0 }

    var body: some View {
        if chartStyle.barShape == .roundedSwiftCharts {
            swiftChartsBar
        } else {
            canvasBar
        }
    }

    // MARK: - Swift Charts (Clean theme only)

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

    // MARK: - Canvas Renderer (all non-Clean themes)

    private var canvasBar: some View {
        ZStack(alignment: .bottomLeading) {
            // Signature accent backdrop (Synthwave perspective grid)
            if chartStyle.barShape == .neonStroke && chartStyle.signatureAccent {
                SynthwavePerspectiveGrid(
                    gridColor: chartStyle.gridColor,
                    opacity: chartStyle.gridOpacity
                )
                .frame(height: chartHeight)
            }

            Canvas { ctx, size in
                // 1. Grid layer
                drawGrid(ctx: ctx, size: size)
                // 2. Bars
                drawBars(ctx: ctx, size: size)
            }
            .frame(height: chartHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            // Axis labels — rendered as SwiftUI Text for Dynamic Type
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
        case .dashed:
            for i in 1...gridLines {
                let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
        case .solid:
            for i in 1...gridLines {
                let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), lineWidth: 0.6)
            }
        case .dotted:
            for i in 1...gridLines {
                let y = size.height * CGFloat(1 - Double(i) / Double(gridLines))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
            }
        case .scanline:
            // Denser horizontal lines (every 8pt)
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color), lineWidth: 0.4)
                y += 8
            }
        case .gutter:
            // Left vertical line only (gutter boundary)
            let gutterX: CGFloat = 28
            var path = Path()
            path.move(to: CGPoint(x: gutterX, y: 0))
            path.addLine(to: CGPoint(x: gutterX, y: size.height))
            ctx.stroke(path, with: .color(color), lineWidth: 1.0)
        case .segments:
            // Faint LCD hash marks — one per bar column
            let barCount = max(values.count, 1)
            let barSlot = size.width / CGFloat(barCount)
            for i in 0..<barCount {
                let x = CGFloat(i) * barSlot + barSlot * 0.5
                for j in stride(from: CGFloat(2), to: size.height, by: 8) {
                    let rect = CGRect(x: x - 1, y: j, width: 2, height: 3)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        default:
            break
        }
    }

    // MARK: - Canvas: Bars

    private func drawBars(ctx: GraphicsContext, size: CGSize) {
        guard !values.isEmpty else { return }
        let barCount = values.count
        let barSlot = size.width / CGFloat(barCount)
        let barW: CGFloat = barSlot * 0.60
        let gutterOffset: CGFloat = chartStyle.gridStyle == .gutter ? 30 : 0
        let usableWidth = size.width - gutterOffset
        let slotW = usableWidth / CGFloat(barCount)
        let bW: CGFloat = slotW * 0.60
        let safeMax = maxValue > 0 ? maxValue : 1

        for (i, value) in values.enumerated() {
            let barH = CGFloat(value / safeMax) * size.height
            let x = gutterOffset + CGFloat(i) * slotW + (slotW - bW) / 2
            let y = size.height - barH
            let rect = CGRect(x: x, y: y, width: bW, height: barH)
            let isPeak = i == maxIndex && chartStyle.highlightPeak

            switch chartStyle.barShape {
            case .roundedSwiftCharts:
                break // handled by Swift Charts path

            case .neonStroke:
                drawNeonStrokeBar(ctx: ctx, rect: rect, isPeak: isPeak)

            case .pixelBlocks:
                drawPixelBlockBar(ctx: ctx, rect: rect, isPeak: isPeak, barW: bW)

            case .lcdSegments:
                drawLCDSegmentBar(ctx: ctx, rect: rect, isPeak: isPeak)

            case .tapeStrip:
                drawTapeStripBar(ctx: ctx, rect: rect, isPeak: isPeak)

            case .dbMeter:
                // dbMeter: draw a minimal filled rect using accent color
                let fillColor = chartStyle.accentColor.opacity(0.70)
                ctx.fill(Path(rect), with: .color(fillColor))

            case .blockChars:
                drawBlockCharBar(ctx: ctx, rect: rect, size: size, value: value, safeMax: safeMax, gutterOffset: gutterOffset, slotW: slotW, index: i)

            case .needle:
                drawNeedleBar(ctx: ctx, rect: rect, size: size, value: value, safeMax: safeMax, isPeak: isPeak)
            }
        }

        // Peak marker (for themes with highlightPeak)
        if chartStyle.highlightPeak && !values.isEmpty {
            let peakValue = values[maxIndex]
            let barH = CGFloat(peakValue / safeMax) * size.height
            let x = gutterOffset + CGFloat(maxIndex) * (usableWidth / CGFloat(barCount)) + ((usableWidth / CGFloat(barCount)) * 0.20)
            let y = size.height - barH - 12
            drawPeakMarker(ctx: ctx, at: CGPoint(x: x + bW / 2, y: y))
        }
    }

    // MARK: - Per-shape Draw Routines

    private func drawNeonStrokeBar(ctx: GraphicsContext, rect: CGRect, isPeak: Bool) {
        let fillColor = chartStyle.accentColor.opacity(0.30)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(fillColor))
        // Glow blur overlay
        ctx.fill(
            Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 5),
            with: .color(chartStyle.accentColor.opacity(0.12))
        )
        // Crisp neon stroke
        ctx.stroke(
            Path(roundedRect: rect, cornerRadius: 3),
            with: .color(chartStyle.accentColor.opacity(0.90)),
            lineWidth: 1.5
        )
        if isPeak {
            // Diamond at top center
            let cx = rect.midX
            let cy = rect.minY - 6
            var diamond = Path()
            diamond.move(to: CGPoint(x: cx, y: cy - 5))
            diamond.addLine(to: CGPoint(x: cx + 4, y: cy))
            diamond.addLine(to: CGPoint(x: cx, y: cy + 5))
            diamond.addLine(to: CGPoint(x: cx - 4, y: cy))
            diamond.closeSubpath()
            ctx.fill(diamond, with: .color(chartStyle.accentColor))
        }
    }

    private func drawPixelBlockBar(ctx: GraphicsContext, rect: CGRect, isPeak: Bool, barW: CGFloat) {
        let blockSize: CGFloat = 6
        let gap: CGFloat = 1
        let step = blockSize + gap
        let blockCount = Int(rect.height / step)
        let phosphorGreen = chartStyle.accentColor  // green (running)
        let peakRed = Color(red: 1.0, green: 0.0, blue: 0.0)  // player-red for peak

        for b in 0..<blockCount {
            let blockY = rect.maxY - CGFloat(b + 1) * step
            if blockY < rect.minY { break }
            let isTopBlock = b == blockCount - 1
            let color: Color = (isTopBlock && isPeak) ? peakRed : phosphorGreen
            let alpha: Double = (isTopBlock && isPeak) ? 1.0 : 0.85
            let blockRect = CGRect(x: rect.minX, y: blockY, width: barW, height: blockSize)
            ctx.fill(Path(blockRect), with: .color(color.opacity(alpha)))
        }
    }

    private func drawLCDSegmentBar(ctx: GraphicsContext, rect: CGRect, isPeak: Bool) {
        let segH: CGFloat = 4
        let segGap: CGFloat = 2
        let step = segH + segGap
        var segY = rect.maxY - segH

        while segY >= rect.minY {
            let alpha: Double = isPeak && (segY < rect.minY + step * 2) ? 1.0 : 0.75
            let segRect = CGRect(x: rect.minX, y: segY, width: rect.width, height: segH)
            ctx.fill(Path(segRect), with: .color(chartStyle.accentColor.opacity(alpha)))
            segY -= step
        }
    }

    private func drawTapeStripBar(ctx: GraphicsContext, rect: CGRect, isPeak: Bool) {
        // Solid fill
        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(chartStyle.accentColor.opacity(0.70)))

        // Horizontal tape-edge stripes every 6pt
        var stripeY = rect.minY + 3
        while stripeY < rect.maxY {
            let stripeRect = CGRect(x: rect.minX, y: stripeY, width: rect.width, height: 1)
            ctx.fill(Path(stripeRect), with: .color(chartStyle.accentColor.opacity(0.30)))
            stripeY += 6
        }
    }

    private func drawBlockCharBar(ctx: GraphicsContext, rect: CGRect, size: CGSize, value: Double, safeMax: Double, gutterOffset: CGFloat, slotW: CGFloat, index: Int) {
        // Unicode block characters ▁▂▃▄▅▆▇█ as proxy – draw solid fill with
        // stepped quantisation (8 levels)
        let level = Int((value / safeMax) * 8.0)
        let blockChars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let char = level > 0 ? blockChars[min(level - 1, 7)] : " "

        // Fill the bar rect
        ctx.fill(Path(rect), with: .color(chartStyle.accentColor.opacity(0.70)))

        // Draw block character label above the bar using a resolved text
        let textRect = CGRect(x: rect.minX - 2, y: rect.minY - 18, width: rect.width + 4, height: 16)
        ctx.draw(
            Text(char)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(chartStyle.accentColor),
            in: textRect
        )
    }

    private func drawNeedleBar(ctx: GraphicsContext, rect: CGRect, size: CGSize, value: Double, safeMax: Double, isPeak: Bool) {
        // Thin vertical line (not a filled bar) + brass dot at top
        let brassColor = chartStyle.accentColor
        var line = Path()
        line.move(to: CGPoint(x: rect.midX, y: size.height))
        line.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        ctx.stroke(line, with: .color(brassColor.opacity(0.70)), lineWidth: 1.5)

        // Dot at peak
        let dotR: CGFloat = 4
        let dotRect = CGRect(x: rect.midX - dotR, y: rect.minY - dotR, width: dotR * 2, height: dotR * 2)
        ctx.fill(Path(ellipseIn: dotRect), with: .color(brassColor))

        // Horizontal dash at value height
        let dashY = rect.minY
        var dash = Path()
        dash.move(to: CGPoint(x: rect.minX - 3, y: dashY))
        dash.addLine(to: CGPoint(x: rect.maxX + 3, y: dashY))
        ctx.stroke(dash, with: .color(brassColor.opacity(0.50)), lineWidth: 0.8)
    }

    private func drawPeakMarker(ctx: GraphicsContext, at point: CGPoint) {
        switch chartStyle.barShape {
        case .pixelBlocks:
            // "★ HI ★" text marker — draw small star dot above peak bar
            let markerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            ctx.fill(Path(ellipseIn: markerRect), with: .color(chartStyle.accentColor))
        case .neonStroke:
            // Already drawn as part of bar
            break
        case .lcdSegments:
            // Dot above
            let r: CGFloat = 3
            ctx.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y, width: r * 2, height: r * 2)),
                with: .color(chartStyle.accentColor)
            )
        default:
            // Generic: small filled circle
            let r: CGFloat = 3
            ctx.fill(
                Path(ellipseIn: CGRect(x: point.x - r, y: point.y, width: r * 2, height: r * 2)),
                with: .color(chartStyle.accentColor)
            )
        }
    }

    // MARK: - Axis Labels (SwiftUI Text for Dynamic Type)

    private var axisLabels: some View {
        GeometryReader { geo in
            let safeMax = maxValue > 0 ? maxValue : 1
            let barCount = max(values.count, 1)
            let gutterOffset: CGFloat = chartStyle.gridStyle == .gutter ? 30 : 0
            let usableW = geo.size.width - gutterOffset

            ZStack(alignment: .bottomLeading) {
                // X-axis labels
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    let slotW = usableW / CGFloat(barCount)
                    let x = gutterOffset + CGFloat(idx) * slotW + slotW * 0.5
                    let text = chartStyle.axisLabelStyle == .sevenSegment
                        ? label.uppercased()
                        : label

                    Text(text)
                        .font(.system(size: 8, weight: .regular, design:
                            (chartStyle.axisLabelStyle == .system) ? .default : .monospaced
                        ))
                        .tracking(chartStyle.axisLabelTracking)
                        .foregroundStyle(chartStyle.axisLabelColor)
                        .minimumScaleFactor(0.8)
                        .accessibilityHidden(chartStyle.axisLabelStyle == .sevenSegment
                            || chartStyle.axisLabelStyle == .lineNumber)
                        .position(x: x, y: geo.size.height - 6)
                }

                // Y-axis / gutter line numbers for Neovim
                if chartStyle.axisLabelStyle == .lineNumber {
                    let lineCount = 8
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

    // MARK: - Per-chart empty state

    /// Call this when `values.isEmpty` to render a themed placeholder.
    static func emptyState(chartStyle: ThemeChartStyle, height: CGFloat) -> some View {
        ThemedBarChartEmpty(chartStyle: chartStyle, height: height)
    }
}

// MARK: - Empty State View

private struct ThemedBarChartEmpty: View {
    let chartStyle: ThemeChartStyle
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch chartStyle.barShape {
            case .pixelBlocks:
                // "PRESS START" blinking text
                if reduceMotion {
                    staticArcadeEmpty
                } else {
                    TimelineView(.animation(minimumInterval: 0.8)) { timeline in
                        let show = Int(timeline.date.timeIntervalSinceReferenceDate / 0.8).isMultiple(of: 2)
                        if show { staticArcadeEmpty } else { Color.clear }
                    }
                }
            case .dbMeter:
                VStack(spacing: 4) {
                    Text("NO SIGNAL")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(chartStyle.accentColor.opacity(0.60))
                        .tracking(1.0)
                    Text("-20 dB")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(chartStyle.accentColor.opacity(0.35))
                }
            case .blockChars:
                Text("-- INSERT --")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(chartStyle.accentColor.opacity(0.60))
                    .tracking(1.0)
            case .lcdSegments:
                Text("─ NO STATION ─")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(chartStyle.accentColor.opacity(0.55))
                    .tracking(1.5)
            case .tapeStrip:
                Text("▶ SIDE B UNREC ▶")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(chartStyle.accentColor.opacity(0.55))
            case .needle:
                VStack(spacing: 4) {
                    Text("TUNE IN")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(chartStyle.accentColor.opacity(0.60))
                    Text("record a workout")
                        .font(.system(size: 8))
                        .foregroundStyle(chartStyle.accentColor.opacity(0.40))
                }
            default:
                // Clean + neon: grey skeleton + text
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

    private var staticArcadeEmpty: some View {
        Text("PRESS START ► RECORD 1 RUN")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(2.0)
            .foregroundStyle(chartStyle.accentColor.opacity(0.80))
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
