import SwiftUI
import Charts
import ShuttlXShared

struct AnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(ThemeManager.self) private var themeManager

    // Cached analytics results — updated only when session count changes via .task(id:)
    @State private var weeklyTrend: [WeeklySummary] = []
    @State private var records: PersonalRecords = PersonalRecords()
    @State private var recovery: RecoveryStatus = .normal
    @State private var vo2max: Double? = nil
    @State private var previousVO2max: Double? = nil
    @State private var healthVO2: VO2MaxReading? = nil
    @State private var paceZones: [PaceZoneDistribution] = []
    @State private var elevationSummary: AnalyticsEngine.ElevationSummary? = nil
    @State private var latestElevationRoute: [RoutePoint]? = nil
    @State private var fitnessScore: Double = 0
    @State private var fatigueScore: Double = 0
    @State private var formScore: Double = 0

    private var sessions: [TrainingSession] { dataManager.effectiveSessions }
    #if DEBUG
    @State private var seamDetail = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sessions.isEmpty {
                        emptyStateView
                    } else {
                        TrendsOverview(sessions: sessions)
                        detailRows
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Trends")
            .timelineScreenBackground()
            #if DEBUG
            // Screenshot seam: SHUTTLX_TRENDS_DETAIL=hr|records|more pushes that detail screen.
            .navigationDestination(isPresented: $seamDetail) {
                switch ProcessInfo.processInfo.environment["SHUTTLX_TRENDS_DETAIL"] {
                case "records": detailScreen("Records") { recordsCards }
                case "more": detailScreen("More") { moreCards }
                default: detailScreen("Heart rate zones") { hrZonesCards }
                }
            }
            .onAppear { seamDetail = ProcessInfo.processInfo.environment["SHUTTLX_TRENDS_DETAIL"] != nil }
            #endif
        }
        .task(id: dataManager.effectiveVersion) {
            recomputeAnalytics()
            healthVO2 = await VO2MaxLoader.latest()
        }
    }

    // MARK: - Rows that push the detail cards (everything the old single page showed)

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow("Heart rate zones", hint: nil) { detailScreen("Heart rate zones") { hrZonesCards } }
            Divider().padding(.leading, 14)
            detailRow("Records", hint: records.fastestKmPace.map { FormattingUtils.formatPaceWithUnit($0, unit: .current) + " best" }) {
                detailScreen("Records") { recordsCards }
            }
            Divider().padding(.leading, 14)
            detailRow("More", hint: nil) { detailScreen("More") { moreCards } }
        }
        .timelineCard()
    }

    private func detailRow<D: View>(_ title: String, hint: String?, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Text(title)
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Spacer()
                if let hint {
                    Text(hint)
                        .font(ShuttlXFont.cardCaption.monospacedDigit())
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(ShuttlXFont.cardCaption.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title + (hint.map { ", \($0)" } ?? ""))
    }

    private func detailScreen<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        ScrollView {
            VStack(spacing: 16) { content() }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .timelineScreenBackground()
    }

    @ViewBuilder private var hrZonesCards: some View {
        HRZoneChart(zones: dataManager.heartRateZones(for: sessions))
        paceZoneChart
    }

    @ViewBuilder private var recordsCards: some View {
        personalRecordsSection
        vo2maxCard
        elevationSection
    }

    @ViewBuilder private var moreCards: some View {
        recoveryStatusCard
        fitnessOverviewRow
        ScrubTimelineHeroCard(sessions: sessions)
        ComparisonSplitCard(sessions: sessions)
        CalendarHeatmapCard(sessions: sessions)
        runWalkSplitCard
        WeeklyCarouselCard(sessions: sessions)
    }

    // MARK: - Analytics Cache

    private func recomputeAnalytics() {
        let currentSessions = dataManager.effectiveSessions
        weeklyTrend = AnalyticsEngine.weeklyTrend(sessions: currentSessions, weeks: 6)
        records = AnalyticsEngine.personalRecords(sessions: currentSessions)
        recovery = AnalyticsEngine.recoveryStatus(sessions: currentSessions)
        vo2max = AnalyticsEngine.estimatedVO2Max(sessions: currentSessions)
        previousVO2max = estimatePreviousVO2Max(sessions: currentSessions)
        paceZones = AnalyticsEngine.paceZones(sessions: currentSessions)
        elevationSummary = AnalyticsEngine.elevationSummary(sessions: currentSessions)
        latestElevationRoute = AnalyticsEngine.latestElevationRoute(sessions: currentSessions)
        fitnessScore = AnalyticsEngine.fitnessScore(sessions: currentSessions)
        fatigueScore = AnalyticsEngine.fatigue(sessions: currentSessions)
        formScore = AnalyticsEngine.form(sessions: currentSessions)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(ShuttlXFont.heroIcon)
                .foregroundStyle(.secondary)

            Text("No Data Yet")
                .font(ShuttlXFont.metricMedium)

            Text("Complete your first workout to see training analytics.")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .timelineCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No analytics data available. Complete a workout to begin.")
    }

    // MARK: - Recovery Status

    private var recoveryStatusCard: some View {
        VStack(spacing: 12) {
            Text("Recovery Status")
                .font(ShuttlXFont.sectionHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Text(recovery.rawValue)
                    .font(ShuttlXFont.metricLarge)
                    .foregroundStyle(ShuttlXColor.forRecovery(recovery))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Form")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(.secondary)
                    Text(formScore >= 0 ? "+\(String(format: "%.0f", formScore))" : String(format: "%.0f", formScore))
                        .font(ShuttlXFont.metricMedium)
                        .foregroundStyle(formScore >= 0 ? ShuttlXColor.positive : ShuttlXColor.negative)
                }
            }
        }
        .padding(16)
        .timelineCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery status: \(recovery.rawValue). Form score: \(String(format: "%.0f", formScore))")
    }

    // MARK: - Fitness Overview Row

    private var fitnessOverviewRow: some View {
        HStack(spacing: 12) {
            MetricCard(
                icon: "heart.fill",
                value: String(format: "%.0f", fitnessScore),
                label: "Fitness",
                color: ShuttlXColor.positive,
                compact: true
            )

            MetricCard(
                icon: "bolt.fill",
                value: String(format: "%.0f", fatigueScore),
                label: "Fatigue",
                color: ShuttlXColor.negative,
                compact: true
            )

            MetricCard(
                icon: "arrow.up.arrow.down",
                value: formScore >= 0 ? "+\(String(format: "%.0f", formScore))" : String(format: "%.0f", formScore),
                label: "Form",
                color: formScore >= 0 ? ShuttlXColor.positive : ShuttlXColor.negative,
                compact: true
            )
        }
    }

    // MARK: - Run vs Walk Split (Phase 4, 2026-08 run+walk plan)
    //
    // Aggregates ActivitySegment-derived run/walk time + calories across the same
    // 6-week window as the trend charts above. Calories use `activeEnergyCalories`
    // (Apple's segment-summed estimate) — the primary display value established in
    // `ActivitySegment.swift`. Older sessions with empty/nil segment data simply
    // contribute 0 duration and nil calories, so the card (and each weekly row)
    // hides itself gracefully instead of showing zeros.

    private var totalRunningDuration: TimeInterval {
        weeklyTrend.reduce(0) { $0 + $1.runningDuration }
    }

    private var totalWalkingDuration: TimeInterval {
        weeklyTrend.reduce(0) { $0 + $1.walkingDuration }
    }

    private var totalRunningCalories: Double? {
        let values = weeklyTrend.compactMap(\.runningCalories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    private var totalWalkingCalories: Double? {
        let values = weeklyTrend.compactMap(\.walkingCalories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    @ViewBuilder
    private var runWalkSplitCard: some View {
        if totalRunningDuration > 0 || totalWalkingDuration > 0 {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run vs Walk")
                        .font(ShuttlXFont.cardTitle)
                }

                runWalkSplitBar(running: totalRunningDuration, walking: totalWalkingDuration)
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                HStack(spacing: 20) {
                    runWalkLegendItem(activity: .running, duration: totalRunningDuration, calories: totalRunningCalories)
                    runWalkLegendItem(activity: .walking, duration: totalWalkingDuration, calories: totalWalkingCalories)
                    Spacer()
                }

                let weeksWithSplit = weeklyTrend.filter { $0.runningDuration > 0 || $0.walkingDuration > 0 }
                if weeksWithSplit.count > 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WEEKLY SPLIT")
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.8))

                        ForEach(weeksWithSplit) { week in
                            HStack(spacing: 8) {
                                Text(week.weekLabel)
                                    .font(ShuttlXFont.microLabel)
                                    .foregroundStyle(ShuttlXColor.textSecondary)
                                    .frame(width: 44, alignment: .leading)
                                runWalkSplitBar(running: week.runningDuration, walking: week.walkingDuration)
                                    .frame(height: 8)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .padding(16)
            .timelineCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(runWalkAccessibilitySummary)
        }
    }

    // Bug 2 fix (2026-08 review): the two segment widths used to be floored
    // independently (`max(4, width * ratio)`) with no renormalization, so a
    // heavily lopsided split (e.g. running=59min, walking=30sec) floored the
    // tiny segment up to 4pt while the large segment still claimed ~99% of the
    // width — the combined width exceeded the container and clipped/overflowed.
    // Now the raw proportional widths are computed first and always sum to the
    // available width; only if a segment's raw width would fall below the 4pt
    // floor is it lifted to 4pt, with the difference subtracted from the OTHER
    // segment so the total never exceeds the container.
    /// Raw proportional widths, renormalized so `running + walking` (+ the 1pt
    /// inter-segment spacing when both are present) never exceeds `totalWidth`.
    /// Pulled out of the `@ViewBuilder` closure below — plain `if`/reassignment
    /// statements inside a GeometryReader's (ViewBuilder) trailing closure don't
    /// type-check as ordinary imperative code, since the builder tries to treat
    /// every statement as View-producing.
    private func splitWidths(
        running: TimeInterval,
        walking: TimeInterval,
        totalWidth: CGFloat
    ) -> (running: CGFloat, walking: CGFloat) {
        let total = running + walking
        let floor: CGFloat = 4
        let spacing: CGFloat = (running > 0 && walking > 0) ? 1 : 0
        let available = max(0, totalWidth - spacing)

        let rawRunningWidth: CGFloat = total > 0 ? available * CGFloat(running / total) : 0
        let rawWalkingWidth: CGFloat = total > 0 ? available * CGFloat(walking / total) : 0

        var runningWidth: CGFloat = running > 0 ? max(floor, rawRunningWidth) : 0
        var walkingWidth: CGFloat = walking > 0 ? max(floor, rawWalkingWidth) : 0

        // Renormalize: if flooring one (or both) segments pushed the combined
        // width past `available`, claw the difference back out of whichever
        // segment has slack above the floor — never let the total exceed the
        // container.
        let overflow = (runningWidth + walkingWidth) - available
        if overflow > 0 {
            if running > 0 && rawRunningWidth > floor {
                runningWidth = max(floor, runningWidth - overflow)
            } else if walking > 0 && rawWalkingWidth > floor {
                walkingWidth = max(floor, walkingWidth - overflow)
            }
        }
        return (runningWidth, walkingWidth)
    }

    // Bug 2 fix (2026-08 review): the two segment widths used to be floored
    // independently (`max(4, width * ratio)`) with no renormalization, so a
    // heavily lopsided split (e.g. running=59min, walking=30sec) floored the
    // tiny segment up to 4pt while the large segment still claimed ~99% of the
    // width — the combined width exceeded the container and clipped/overflowed.
    // `splitWidths` above computes the raw proportional widths first and always
    // sums them to the available width, only lifting a segment to the 4pt floor
    // and subtracting the difference from the OTHER segment when needed.
    @ViewBuilder
    private func runWalkSplitBar(running: TimeInterval, walking: TimeInterval) -> some View {
        GeometryReader { geometry in
            let widths = splitWidths(running: running, walking: walking, totalWidth: geometry.size.width)
            let spacing: CGFloat = (running > 0 && walking > 0) ? 1 : 0

            HStack(spacing: spacing) {
                if running > 0 {
                    Rectangle()
                        .fill(ShuttlXColor.running)
                        .frame(width: widths.running)
                }
                if walking > 0 {
                    Rectangle()
                        .fill(ShuttlXColor.walking)
                        .frame(width: widths.walking)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func runWalkLegendItem(activity: DetectedActivity, duration: TimeInterval, calories: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: activity.systemImage)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(activity.themeColor)
                Text(activity.displayName)
                    .font(ShuttlXFont.cardCaption)
            }
            Text(FormattingUtils.formatDuration(duration))
                .font(ShuttlXFont.cardSubtitle.monospacedDigit())

            if let calories {
                Text("\(Int(calories.rounded())) cal")
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityHidden(true)
    }

    private var runWalkAccessibilitySummary: String {
        var summary = "Run versus walk breakdown, last 6 weeks. Running \(FormattingUtils.formatDuration(totalRunningDuration))"
        if let cal = totalRunningCalories {
            summary += ", \(Int(cal.rounded())) calories"
        }
        summary += ". Walking \(FormattingUtils.formatDuration(totalWalkingDuration))"
        if let cal = totalWalkingCalories {
            summary += ", \(Int(cal.rounded())) calories"
        }
        summary += "."
        return summary
    }

    // MARK: - VO2max Card

    @ViewBuilder
    private var vo2maxCard: some View {
        // Apple's measured value wins; the in-app estimate (running sessions only) is the fallback.
        let measured = healthVO2
        let value = measured?.value ?? vo2max
        let previous = measured != nil ? measured?.previous : previousVO2max
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(measured != nil ? "Cardio fitness (VO2max)" : value != nil ? "Estimated VO2max" : "Cardio fitness (VO2max)")
                        .font(ShuttlXFont.sectionHeader)
                }
                Spacer()
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", value))
                            .font(ShuttlXFont.metricLarge)
                            .foregroundStyle(ShuttlXColor.accentText)
                        if let previous, previous != value {
                            Image(systemName: value > previous ? "arrow.up.right" : "arrow.down.right")
                                .font(ShuttlXFont.sectionHeader)
                                .foregroundStyle(value > previous ? ShuttlXColor.positive : ShuttlXColor.negative)
                        }
                    }
                }
            }
            if value != nil {
                Text(vo2Caption(measured))
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("Apple Watch measures this on outdoor walks and runs.")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .timelineCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(value.map {
            "\(measured != nil ? "Cardio fitness, VO2 max" : "Estimated VO2 max"): \(String(format: "%.1f", $0)) milliliters per kilogram per minute. \(vo2Caption(measured))"
        } ?? "Cardio fitness, VO2 max: no reading yet. Apple Watch measures this on outdoor walks and runs.")
    }

    /// "ml/kg/min · From Apple Watch, 21 Oct" or "ml/kg/min · estimate".
    private func vo2Caption(_ measured: VO2MaxReading?) -> String {
        guard let measured else { return "ml/kg/min \u{00B7} estimate" }
        return "ml/kg/min \u{00B7} from Apple Health, \(measured.date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func estimatePreviousVO2Max(sessions: [TrainingSession]) -> Double? {
        let calendar = Calendar.current
        guard let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date()) else { return nil }
        let olderSessions = sessions.filter { $0.startDate < fourWeeksAgo }
        return AnalyticsEngine.estimatedVO2Max(sessions: olderSessions)
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(ShuttlXFont.sectionHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let pace = records.fastestKmPace {
                    PRCard(
                        title: DistanceUnit.current == .km ? "Fastest km" : "Best pace (/mi)",
                        value: FormattingUtils.formatPace(pace, unit: .current),
                        date: records.fastestKmDate,
                        icon: "hare.fill",
                        color: ShuttlXColor.running
                    )
                }

                if let dist = records.mostDistance {
                    PRCard(
                        title: "Longest Run",
                        value: FormattingUtils.formatDistance(dist, unit: .current),
                        date: records.mostDistanceDate,
                        icon: "road.lanes",
                        color: ShuttlXColor.steps
                    )
                }

                if let dur = records.longestDuration {
                    PRCard(
                        title: "Longest Time",
                        value: FormattingUtils.formatDuration(dur),
                        date: records.longestDurationDate,
                        icon: "clock.fill",
                        color: ShuttlXColor.pace
                    )
                }

                if let hr = records.highestAvgHR {
                    PRCard(
                        title: "Highest Avg HR",
                        value: "\(Int(hr)) bpm",
                        date: records.highestAvgHRDate,
                        icon: "heart.fill",
                        color: ShuttlXColor.heartRate
                    )
                }
            }
        }
        .padding(16)
        .timelineCard()
    }

    // MARK: - Pace Zones Chart

    @ViewBuilder
    private var paceZoneChart: some View {
        if !paceZones.isEmpty {
            let chartStyle = themeManager.current.chartStyle
            let a11yLabel = paceZones.map { "\($0.zone) \(String(format: "%.0f", $0.percentage)) percent" }.joined(separator: ", ")

            VStack(alignment: .leading, spacing: 12) {
                Text("Pace Zones")
                    .font(ShuttlXFont.cardTitle)

                ForEach(paceZones) { zone in
                    HStack(spacing: 8) {
                        Text(zone.zone)
                            .font(ShuttlXFont.cardCaption)
                            .frame(width: 70, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(paceZoneBarColor(zone: zone.zone, chartStyle: chartStyle))
                                .frame(width: max(geo.size.width * zone.percentage / 100, 4))
                        }
                        .frame(height: 20)

                        Text(String(format: "%.0f%%", zone.percentage))
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                            .monospacedDigit()
                    }
                    .accessibilityHidden(true)
                }

                // Legend for pace ranges
                HStack(spacing: 0) {
                    ForEach(["<4:00", "4-4:45", "4:45-5:30", "5:30-6:30", ">6:30"], id: \.self) { label in
                        Text(label)
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
                .accessibilityHidden(true)
            }
            .padding(16)
            .timelineCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pace zone distribution: \(a11yLabel)")
        }
    }

    private func paceZoneBarColor(zone: String, chartStyle: ThemeChartStyle) -> Color {
        // The live chart style keeps the stock pace zone colors
        switch chartStyle.barShape {
        case .roundedSwiftCharts:
            return ShuttlXColor.forPaceZone(zone)
        }
    }

    // MARK: - Elevation Section

    @ViewBuilder
    private var elevationSection: some View {
        if let summary = elevationSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Elevation")
                    .font(ShuttlXFont.sectionHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricCard(
                        icon: "arrow.up.right",
                        value: "\(Int(summary.totalAscent)) m",
                        label: "Total Ascent",
                        color: ShuttlXColor.running,
                        compact: true
                    )

                    MetricCard(
                        icon: "arrow.down.right",
                        value: "\(Int(summary.totalDescent)) m",
                        label: "Total Descent",
                        color: ShuttlXColor.negative,
                        compact: true
                    )

                    MetricCard(
                        icon: "mountain.2.fill",
                        value: "\(Int(summary.highestPoint)) m",
                        label: "Highest Point",
                        color: ShuttlXColor.steps,
                        compact: true
                    )

                    MetricCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: "\(Int(summary.averageAscent)) m",
                        label: "Avg Ascent",
                        color: ShuttlXColor.pace,
                        compact: true
                    )
                }

                if let route = latestElevationRoute {
                    ElevationProfileView(route: route)
                }
            }
            .padding(16)
            .timelineCard()
            .accessibilityElement(children: .contain)
        }
    }

}

// MARK: - PR Card Component

private struct PRCard: View {
    let title: String
    let value: String
    let date: Date?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(color)

                Text(title)
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(ShuttlXFont.prValue)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let date = date {
                Text(FormattingUtils.formatShortDate(date))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .timelineCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(DataManager())
}
