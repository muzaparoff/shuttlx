import SwiftUI
import Charts
import UIKit
import ShuttlXShared

// MARK: - ScrubTimelineHeroCard
//
// "Dynamic Analytics Timeline" Track A / Concept 1 (docs/plans/2026-08-analytics-dynamic-timeline-plan.md).
// A hero distance number sits above a draggable timeline scrubber — dragging the
// track (or using VoiceOver's adjustable action) recomputes the hero number, the
// selected date, and the "avg pace at selected point" sub-row live, no debounce.
//
// Self-contained: derives everything from the raw `[TrainingSession]` array passed
// in — no AnalyticsEngine changes required. The lead wires this into AnalyticsView's
// scroll stack.
//
// Data bucketing (deviates from the HTML mockup, which used fake/random data at a
// fixed "14 points" regardless of range): 7D/30D bucket by day, 90D buckets by week
// (13 points), 1Y buckets by month (12 points) — otherwise a 365-point daily line
// would be unreadable and wildly denser than the other three ranges.

// MARK: - Data-viz palette (validated — NOT the app's running/walking colors)
//
// The design review found the existing ShuttlXColor.running/.walking pair
// (green/orange) fails colorblind validation for arbitrary data-viz use
// (ΔE 2.7-3.2, under the safety floor) — that's a separate pre-existing finding,
// out of scope here. New analytics charts in this plan use this dedicated,
// validated pair instead: a blue for single-series trend lines and the
// "decrease" side of comparison deltas, and a red for the "increase" side.
// Values match the approved mockup (`analytics-concepts.html`) exactly.
//
// TODO: promote to a proper ShuttlXColor token (e.g. `.dataVizSeries` /
// `.deltaIncrease`) if more analytics surfaces need this pair — currently only
// Track A's two cards (ScrubTimelineHeroCard, ComparisonSplitCard) use it.
enum AnalyticsDataVizPalette {
    /// Validated blue — scrub-timeline series, comparison "decrease" bars/pills.
    static var seriesBlue: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x39 / 255.0, green: 0x87 / 255.0, blue: 0xe5 / 255.0, alpha: 1)
                : UIColor(red: 0x2a / 255.0, green: 0x78 / 255.0, blue: 0xd6 / 255.0, alpha: 1)
        })
    }

    /// Validated diverging red — comparison "increase" bars/pills. Deliberately
    /// distinct from the run/walk categorical colors so "more/less" never reads
    /// as "run/walk."
    static var deltaIncrease: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0xe6 / 255.0, green: 0x74 / 255.0, blue: 0x6e / 255.0, alpha: 1)
                : UIColor(red: 0xc2 / 255.0, green: 0x3b / 255.0, blue: 0x3b / 255.0, alpha: 1)
        })
    }
}

// MARK: - Range preset

private enum ScrubRangePreset: String, CaseIterable, Identifiable {
    case sevenDay = "7D"
    case thirtyDay = "30D"
    case ninetyDay = "90D"
    case oneYear = "1Y"

    var id: String { rawValue }

    var accessibleLabel: String {
        switch self {
        case .sevenDay: return "7 days"
        case .thirtyDay: return "30 days"
        case .ninetyDay: return "90 days"
        case .oneYear: return "1 year"
        }
    }

    /// Caption above the hero number — reflects the bucket granularity so
    /// "SELECTED DAY" doesn't lie when 90D/1Y are actually week/month buckets.
    var selectionCaption: String {
        switch self {
        case .sevenDay, .thirtyDay: return "SELECTED DAY"
        case .ninetyDay: return "SELECTED WEEK"
        case .oneYear: return "SELECTED MONTH"
        }
    }
}

// MARK: - Timeline point (one bucket)

private struct TimelinePoint {
    let bucketStart: Date
    let distanceKm: Double
    let avgPaceSecondsPerKm: Double?
    let chartLabel: String      // short x-axis label, e.g. "Aug 3" / "Jan"
    let fullDateLabel: String   // e.g. "Wednesday, Aug 13" / "Week of Jun 2" / "January 2026"
}

// MARK: - ScrubTimelineHeroCard

struct ScrubTimelineHeroCard: View {
    let sessions: [TrainingSession]

    @State private var preset: ScrubRangePreset = .sevenDay
    @State private var manualIndex: Int?
    @Environment(ThemeManager.self) private var themeManager

    private var chartStyle: ThemeChartStyle { themeManager.current.chartStyle }

    var body: some View {
        // Materialized once per body pass — `points` is filtered/reduced from
        // `sessions` and must not be recomputed (with fresh identity) multiple
        // times in the same render, or the chart's "selected point" highlight
        // and the scrub track's position could disagree.
        let points = Self.buildPoints(preset: preset, sessions: sessions)
        let index = clampedIndex(count: points.count)
        let selected: TimelinePoint? = points.indices.contains(index) ? points[index] : nil

        VStack(alignment: .leading, spacing: 8) {
            Text("Distance")
                .font(ShuttlXFont.cardTitle)

            heroHeader(selected: selected)

            if points.isEmpty {
                emptyState
            } else {
                chart(points: points, selectedIndex: index)
                scrubTrack(count: points.count, selectedIndex: index, selected: selected)
            }

            presetRow

            if let pace = selected?.avgPaceSecondsPerKm {
                paceSubcard(pace)
            }
        }
        .padding(16)
        .themedCard(accent: AnalyticsDataVizPalette.seriesBlue, headerLabel: "TIMELINE")
    }

    // MARK: - Selection

    private func clampedIndex(count: Int) -> Int {
        let maxIndex = max(0, count - 1)
        guard let manual = manualIndex else { return maxIndex }
        return min(max(0, manual), maxIndex)
    }

    // MARK: - Hero header

    private func heroHeader(selected: TimelinePoint?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(preset.selectionCaption)
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(ShuttlXColor.textSecondary)
                .tracking(0.5)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", selected?.distanceKm ?? 0))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text("KM")
                    .font(ShuttlXFont.cardCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }

            Text(selected?.fullDateLabel ?? "No data")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            guard let selected else { return "Distance, no data" }
            return "Distance, \(String(format: "%.1f", selected.distanceKm)) kilometers, \(selected.fullDateLabel)"
        }())
    }

    // MARK: - Chart

    private func chart(points: [TimelinePoint], selectedIndex: Int) -> some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                LineMark(
                    x: .value("Period", point.chartLabel),
                    y: .value("Distance", point.distanceKm)
                )
                .foregroundStyle(AnalyticsDataVizPalette.seriesBlue)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Period", point.chartLabel),
                    y: .value("Distance", point.distanceKm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AnalyticsDataVizPalette.seriesBlue.opacity(0.28),
                            AnalyticsDataVizPalette.seriesBlue.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                if idx == selectedIndex {
                    PointMark(
                        x: .value("Period", point.chartLabel),
                        y: .value("Distance", point.distanceKm)
                    )
                    .foregroundStyle(AnalyticsDataVizPalette.seriesBlue)
                    .symbolSize(70)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: sampledLabels(points)) { _ in
                AxisValueLabel()
                    .font(.system(size: 8, design: chartStyle.axisLabelStyle == .system ? .default : .monospaced))
                    .foregroundStyle(chartStyle.axisLabelColor)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: chartStyle.gridStyle == .dotted ? [1, 4] : [4]))
                    .foregroundStyle(chartStyle.gridColor.opacity(chartStyle.gridOpacity))
            }
        }
        .frame(height: 130)
        // Hero header + scrub track already carry the live accessible summary;
        // the chart itself is a visual echo, not an independent VoiceOver stop.
        .accessibilityHidden(true)
    }

    /// Thins x-axis labels for wider ranges so 30 daily labels don't collide.
    private func sampledLabels(_ points: [TimelinePoint]) -> [String] {
        guard points.count > 6 else { return points.map(\.chartLabel) }
        let step = max(1, points.count / 5)
        var labels: [String] = []
        for (idx, point) in points.enumerated() where idx % step == 0 || idx == points.count - 1 {
            labels.append(point.chartLabel)
        }
        return labels
    }

    // MARK: - Scrub track

    private func scrubTrack(count: Int, selectedIndex: Int, selected: TimelinePoint?) -> some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let pct: CGFloat = count > 1 ? CGFloat(selectedIndex) / CGFloat(count - 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ShuttlXColor.surfaceBorder.opacity(0.6))
                    .frame(height: 4)
                    .frame(maxHeight: .infinity, alignment: .center)

                Circle()
                    .fill(AnalyticsDataVizPalette.seriesBlue)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(ShuttlXColor.cardBackground, lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .position(x: width * pct, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 1 else { return }
                        let clampedX = min(max(0, value.location.x), width)
                        let fraction = clampedX / width
                        let idx = Int((fraction * CGFloat(count - 1)).rounded())
                        if idx != manualIndex { manualIndex = idx }
                    }
            )
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel("Timeline scrubber")
        .accessibilityValue(
            selected.map { "\($0.fullDateLabel), \(String(format: "%.1f", $0.distanceKm)) kilometers" } ?? "No data"
        )
        .accessibilityAdjustableAction { direction in
            guard count > 1 else { return }
            switch direction {
            case .increment:
                manualIndex = min(selectedIndex + 1, count - 1)
            case .decrement:
                manualIndex = max(selectedIndex - 1, 0)
            @unknown default:
                break
            }
        }
    }

    // MARK: - Range presets

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(ScrubRangePreset.allCases) { candidate in
                Button {
                    preset = candidate
                    manualIndex = nil   // reset to the most recent point on range change
                } label: {
                    Text(candidate.rawValue)
                        .font(ShuttlXFont.cardCaption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(preset == candidate ? AnalyticsDataVizPalette.seriesBlue : ShuttlXColor.surface)
                        )
                        .foregroundStyle(preset == candidate ? .white : ShuttlXColor.textSecondary)
                }
                .accessibilityLabel("\(candidate.accessibleLabel) range")
                .accessibilityAddTraits(preset == candidate ? [.isSelected] : [])
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Pace sub-row

    private func paceSubcard(_ paceSecondsPerKm: TimeInterval) -> some View {
        HStack {
            Text("AVG PACE AT SELECTED POINT")
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(ShuttlXColor.textSecondary)
                .tracking(0.5)
            Spacer()
            Text("\(FormattingUtils.formatPace(paceSecondsPerKm))/km")
                .font(ShuttlXFont.cardSubtitle)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.textPrimary)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Average pace at selected point: \(FormattingUtils.formatPace(paceSecondsPerKm)) per kilometer")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(ShuttlXFont.heroIcon)
                .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.4))
            Text("No workouts yet")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No workout data available")
    }

    // MARK: - Bucketing

    private static func buildPoints(preset: ScrubRangePreset, sessions: [TrainingSession]) -> [TimelinePoint] {
        let calendar = Calendar.current
        let now = Date()

        switch preset {
        case .sevenDay, .thirtyDay:
            let days = preset == .sevenDay ? 7 : 30
            let today = calendar.startOfDay(for: now)
            return (0..<days).reversed().compactMap { offset -> TimelinePoint? in
                guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: today),
                      let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
                let bucket = sessions.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                return makePoint(
                    bucketStart: dayStart,
                    sessions: bucket,
                    chartLabel: dailyChartFormatter.string(from: dayStart),
                    fullDateLabel: fullDayFormatter.string(from: dayStart)
                )
            }

        case .ninetyDay:
            let weeks = 13
            return (0..<weeks).reversed().compactMap { offset -> TimelinePoint? in
                guard let weekEnd = calendar.date(byAdding: .day, value: -(offset * 7), to: now),
                      let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else { return nil }
                let bucket = sessions.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
                let label = weeklyChartFormatter.string(from: weekStart)
                return makePoint(
                    bucketStart: weekStart,
                    sessions: bucket,
                    chartLabel: label,
                    fullDateLabel: "Week of \(label)"
                )
            }

        case .oneYear:
            let months = 12
            return (0..<months).reversed().compactMap { offset -> TimelinePoint? in
                guard let monthAnchor = calendar.date(byAdding: .month, value: -offset, to: now),
                      let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return nil }
                let bucket = sessions.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
                return makePoint(
                    bucketStart: interval.start,
                    sessions: bucket,
                    chartLabel: monthChartFormatter.string(from: interval.start),
                    fullDateLabel: monthFullFormatter.string(from: interval.start)
                )
            }
        }
    }

    private static func makePoint(
        bucketStart: Date,
        sessions: [TrainingSession],
        chartLabel: String,
        fullDateLabel: String
    ) -> TimelinePoint {
        let totalDistance = sessions.compactMap(\.distance).reduce(0, +)
        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        let avgPace: TimeInterval? = totalDistance > 0 ? totalDuration / totalDistance : nil
        return TimelinePoint(
            bucketStart: bucketStart,
            distanceKm: totalDistance,
            avgPaceSecondsPerKm: avgPace,
            chartLabel: chartLabel,
            fullDateLabel: fullDateLabel
        )
    }

    private static let dailyChartFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let fullDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let weeklyChartFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let monthChartFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let monthFullFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

// MARK: - Preview

private enum ScrubPreviewData {
    /// ~380 days of synthetic sessions (every ~2 days) so 7D/30D/90D/1Y all have
    /// realistic, non-empty data to scrub through.
    static let sessions: [TrainingSession] = {
        let calendar = Calendar.current
        let now = Date()
        var result: [TrainingSession] = []
        for offset in stride(from: 0, through: 380, by: 2) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let wave = sin(Double(offset) / 9.0)
            let distance = max(1.0, 6.5 + wave * 3.2 + Double.random(in: -0.6...0.6))
            let duration = distance * TimeInterval.random(in: 320...380)
            let hr = Double.random(in: 128...162)
            result.append(TrainingSession(
                startDate: date,
                endDate: date.addingTimeInterval(duration),
                duration: duration,
                averageHeartRate: hr,
                maxHeartRate: hr + 18,
                caloriesBurned: distance * 62,
                distance: distance
            ))
        }
        return result
    }()
}

#Preview("Clean") {
    ScrollView {
        ScrubTimelineHeroCard(sessions: ScrubPreviewData.sessions)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("clean") }
}

#Preview("Mixtape") {
    ScrollView {
        ScrubTimelineHeroCard(sessions: ScrubPreviewData.sessions)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("mixtape") }
}

#Preview("Empty") {
    ScrollView {
        ScrubTimelineHeroCard(sessions: [])
            .padding()
    }
    .environment(ThemeManager.shared)
}
