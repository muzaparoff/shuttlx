import SwiftUI
import ShuttlXShared

// MARK: - ComparisonSplitCard
//
// "Dynamic Analytics Timeline" Track A / Concept 4 (docs/plans/2026-08-analytics-dynamic-timeline-plan.md).
// A period-pair toggle ("This vs Last Week" / "This vs Last Month") drives four
// metric rows (Distance, Duration, Avg HR, Calories), each with a diverging
// delta bar anchored at a center zero-line. Blue = decrease, red = increase —
// the validated `AnalyticsDataVizPalette` pair defined in
// ScrubTimelineHeroCard.swift, deliberately distinct from the app's run/walk
// categorical colors so "more/less" is never confused with "run/walk."
//
// Self-contained: buckets `[TrainingSession]` into "this period" / "last
// period" windows itself — no AnalyticsEngine changes required. Metrics are
// limited to what's directly computable from TrainingSession (distance,
// duration, averageHeartRate, caloriesBurned) rather than requiring new
// WeeklySummary fields.

// MARK: - Period pair

private enum ComparisonPeriodPair: String, CaseIterable, Identifiable {
    case week = "This vs Last Week"
    case month = "This vs Last Month"

    var id: String { rawValue }

    var windowDays: Int { self == .week ? 7 : 30 }

    /// Used inside per-row accessibility labels: "this week" / "last month".
    var periodNoun: String { self == .week ? "week" : "month" }
}

// MARK: - Metric row (computed)

private struct ComparisonMetricRow: Identifiable {
    var id: String { title }
    let title: String
    let thisValue: Double
    let lastValue: Double
    let thisDisplay: String
    let lastDisplay: String
    /// nil when there's no prior-period baseline to compare against (lastValue == 0).
    let percentDelta: Double?
    /// How to phrase `thisValue`/`lastValue` for VoiceOver, e.g. "18.2 kilometers".
    let accessibleUnit: (Double) -> String
}

// MARK: - ComparisonSplitCard

struct ComparisonSplitCard: View {
    let sessions: [TrainingSession]

    @State private var selectedPair: ComparisonPeriodPair = .week

    private var rows: [ComparisonMetricRow] {
        let thisSessions = sessionsInWindow(offset: 0)
        let lastSessions = sessionsInWindow(offset: 1)
        return [
            distanceRow(this: thisSessions, last: lastSessions),
            durationRow(this: thisSessions, last: lastSessions),
            avgHRRow(this: thisSessions, last: lastSessions),
            caloriesRow(this: thisSessions, last: lastSessions)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare")
                .font(ShuttlXFont.cardTitle)

            periodToggle

            VStack(spacing: 16) {
                ForEach(rows) { row in
                    ComparisonRow(row: row, accessibilityLabel: rowAccessibilityLabel(row))
                }
            }
        }
        .padding(16)
        .themedCard(accent: AnalyticsDataVizPalette.seriesBlue, headerLabel: "COMPARE")
    }

    // MARK: - Period toggle

    private var periodToggle: some View {
        HStack(spacing: 6) {
            ForEach(ComparisonPeriodPair.allCases) { pair in
                Button {
                    selectedPair = pair
                } label: {
                    Text(pair.rawValue)
                        .font(ShuttlXFont.cardCaption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPair == pair ? AnalyticsDataVizPalette.seriesBlue : ShuttlXColor.surface)
                        )
                        .foregroundStyle(selectedPair == pair ? .white : ShuttlXColor.textSecondary)
                }
                .accessibilityLabel(pair.rawValue)
                .accessibilityAddTraits(selectedPair == pair ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Windowing

    /// offset 0 = current window (e.g. last 7 days), offset 1 = the window
    /// immediately before that (e.g. the 7 days before that) — rolling windows
    /// anchored to "now", matching AnalyticsEngine.weeklyTrend's own convention
    /// rather than calendar Sun-Sat weeks.
    private func sessionsInWindow(offset: Int) -> [TrainingSession] {
        let calendar = Calendar.current
        let now = Date()
        let days = selectedPair.windowDays
        guard let windowEnd = calendar.date(byAdding: .day, value: -(offset * days), to: now),
              let windowStart = calendar.date(byAdding: .day, value: -days, to: windowEnd) else {
            return []
        }
        return sessions.filter { $0.startDate >= windowStart && $0.startDate < windowEnd }
    }

    // MARK: - Metric rows

    private func distanceRow(this: [TrainingSession], last: [TrainingSession]) -> ComparisonMetricRow {
        let thisKm = this.compactMap(\.distance).reduce(0, +)
        let lastKm = last.compactMap(\.distance).reduce(0, +)
        return ComparisonMetricRow(
            title: "Distance",
            thisValue: thisKm,
            lastValue: lastKm,
            thisDisplay: FormattingUtils.formatDistance(thisKm),
            lastDisplay: FormattingUtils.formatDistance(lastKm),
            percentDelta: percentDelta(this: thisKm, last: lastKm),
            accessibleUnit: { "\(String(format: "%.1f", $0)) kilometers" }
        )
    }

    private func durationRow(this: [TrainingSession], last: [TrainingSession]) -> ComparisonMetricRow {
        let thisDuration = this.reduce(0.0) { $0 + $1.duration }
        let lastDuration = last.reduce(0.0) { $0 + $1.duration }
        return ComparisonMetricRow(
            title: "Duration",
            thisValue: thisDuration,
            lastValue: lastDuration,
            thisDisplay: FormattingUtils.formatDuration(thisDuration),
            lastDisplay: FormattingUtils.formatDuration(lastDuration),
            percentDelta: percentDelta(this: thisDuration, last: lastDuration),
            accessibleUnit: { FormattingUtils.formatTimeAccessible($0) }
        )
    }

    private func avgHRRow(this: [TrainingSession], last: [TrainingSession]) -> ComparisonMetricRow {
        let thisHRs = this.compactMap(\.averageHeartRate)
        let lastHRs = last.compactMap(\.averageHeartRate)
        let thisAvg = thisHRs.isEmpty ? 0 : thisHRs.reduce(0, +) / Double(thisHRs.count)
        let lastAvg = lastHRs.isEmpty ? 0 : lastHRs.reduce(0, +) / Double(lastHRs.count)
        return ComparisonMetricRow(
            title: "Avg HR",
            thisValue: thisAvg,
            lastValue: lastAvg,
            thisDisplay: thisHRs.isEmpty ? "—" : "\(Int(thisAvg.rounded())) bpm",
            lastDisplay: lastHRs.isEmpty ? "—" : "\(Int(lastAvg.rounded())) bpm",
            percentDelta: (thisHRs.isEmpty || lastHRs.isEmpty) ? nil : percentDelta(this: thisAvg, last: lastAvg),
            accessibleUnit: { $0 == 0 ? "no data" : "\(Int($0.rounded())) beats per minute" }
        )
    }

    private func caloriesRow(this: [TrainingSession], last: [TrainingSession]) -> ComparisonMetricRow {
        let thisCal = this.compactMap(\.caloriesBurned).reduce(0, +)
        let lastCal = last.compactMap(\.caloriesBurned).reduce(0, +)
        return ComparisonMetricRow(
            title: "Calories",
            thisValue: thisCal,
            lastValue: lastCal,
            thisDisplay: "\(Int(thisCal.rounded()))",
            lastDisplay: "\(Int(lastCal.rounded()))",
            percentDelta: percentDelta(this: thisCal, last: lastCal),
            accessibleUnit: { "\(Int($0.rounded())) calories" }
        )
    }

    private func percentDelta(this: Double, last: Double) -> Double? {
        guard last > 0 else { return nil }
        return ((this - last) / last) * 100
    }

    // MARK: - Accessibility

    private func rowAccessibilityLabel(_ row: ComparisonMetricRow) -> String {
        let thisText = row.accessibleUnit(row.thisValue)
        let lastText = row.accessibleUnit(row.lastValue)
        let deltaText: String
        if let pct = row.percentDelta {
            deltaText = pct >= 0
                ? "up \(Int(abs(pct).rounded())) percent"
                : "down \(Int(abs(pct).rounded())) percent"
        } else {
            deltaText = "no prior data to compare"
        }
        return "\(row.title), this \(selectedPair.periodNoun) \(thisText), last \(selectedPair.periodNoun) \(lastText), \(deltaText)"
    }
}

// MARK: - Comparison Row

private struct ComparisonRow: View {
    let row: ComparisonMetricRow
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(row.title)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                Spacer()
                Text(row.thisDisplay)
                    .font(ShuttlXFont.cardSubtitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text("vs \(row.lastDisplay)")
                    .font(ShuttlXFont.cardCaption)
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textSecondary)
                deltaBadge
            }
            DivergingDeltaBar(
                percentDelta: row.percentDelta,
                increaseColor: AnalyticsDataVizPalette.deltaIncrease,
                decreaseColor: AnalyticsDataVizPalette.seriesBlue
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var deltaBadge: some View {
        if let pct = row.percentDelta {
            Text("\(pct >= 0 ? "+" : "")\(Int(pct.rounded()))%")
                .font(ShuttlXFont.cardCaption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(pct >= 0 ? AnalyticsDataVizPalette.deltaIncrease : AnalyticsDataVizPalette.seriesBlue)
        } else {
            Text("New")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
    }
}

// MARK: - Diverging Delta Bar

private struct DivergingDeltaBar: View {
    /// nil => no prior-period baseline; renders an empty track.
    let percentDelta: Double?
    let increaseColor: Color
    let decreaseColor: Color

    /// A delta at or beyond this magnitude fills the entire half-bar.
    private let scaleCapPercent: Double = 50

    private var isIncrease: Bool { (percentDelta ?? 0) >= 0 }
    private var magnitudeFraction: CGFloat {
        guard let pct = percentDelta else { return 0 }
        return CGFloat(min(1.0, abs(pct) / scaleCapPercent))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let half = width / 2
            let barWidth = max(percentDelta == nil ? 0 : 3, half * magnitudeFraction)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ShuttlXColor.surfaceBorder.opacity(0.5))
                    .frame(height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)

                Rectangle()
                    .fill(ShuttlXColor.textSecondary.opacity(0.5))
                    .frame(width: 2, height: 14)
                    .position(x: half, y: geo.size.height / 2)

                if percentDelta != nil {
                    Capsule()
                        .fill(isIncrease ? increaseColor : decreaseColor)
                        .frame(width: barWidth, height: 6)
                        .position(
                            x: isIncrease ? half + barWidth / 2 : half - barWidth / 2,
                            y: geo.size.height / 2
                        )
                }
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)   // the row already carries a full accessible label
    }
}

// MARK: - Preview

private enum ComparisonPreviewData {
    /// ~70 days of synthetic sessions with a recent upward trend, so this-vs-last
    /// comparisons show a mix of increase (red) and decrease (blue) deltas.
    static let sessions: [TrainingSession] = {
        let calendar = Calendar.current
        let now = Date()
        var result: [TrainingSession] = []
        for offset in stride(from: 0, through: 70, by: 2) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            // Recent weeks trend up in distance/calories, down in avg HR (fitter = lower HR).
            let recencyBoost = max(0, 1 - Double(offset) / 70)
            let distance = 3.5 + recencyBoost * 5.5 + Double.random(in: -0.4...0.4)
            let duration = distance * TimeInterval.random(in: 330...370)
            let hr = 158 - recencyBoost * 14 + Double.random(in: -3...3)
            result.append(TrainingSession(
                startDate: date,
                endDate: date.addingTimeInterval(duration),
                duration: duration,
                averageHeartRate: hr,
                maxHeartRate: hr + 20,
                caloriesBurned: distance * 60,
                distance: distance
            ))
        }
        return result
    }()
}

#Preview("Clean") {
    ScrollView {
        ComparisonSplitCard(sessions: ComparisonPreviewData.sessions)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("clean") }
}

#Preview("Mixtape") {
    ScrollView {
        ComparisonSplitCard(sessions: ComparisonPreviewData.sessions)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("mixtape") }
}

#Preview("No prior data") {
    ScrollView {
        ComparisonSplitCard(sessions: Array(ComparisonPreviewData.sessions.prefix(3)))
            .padding()
    }
    .environment(ThemeManager.shared)
}
