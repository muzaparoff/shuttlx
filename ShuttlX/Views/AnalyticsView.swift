import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(ThemeManager.self) private var themeManager

    // Cached analytics results — updated only when session count changes via .task(id:)
    @State private var weeklyTrend: [WeeklySummary] = []
    @State private var records: PersonalRecords = PersonalRecords()
    @State private var recovery: RecoveryStatus = .normal
    @State private var vo2max: Double? = nil
    @State private var previousVO2max: Double? = nil
    @State private var paceZones: [PaceZoneDistribution] = []
    @State private var elevationSummary: AnalyticsEngine.ElevationSummary? = nil
    @State private var latestElevationRoute: [RoutePoint]? = nil
    @State private var fitnessScore: Double = 0
    @State private var fatigueScore: Double = 0
    @State private var formScore: Double = 0

    private var sessions: [TrainingSession] { dataManager.sessions }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sessions.isEmpty {
                        emptyStateView
                    } else {
                        recoveryStatusCard
                        fitnessOverviewRow
                        fitnessTrendChart
                        weeklyVolumeChart
                        vo2maxCard
                        personalRecordsSection
                        paceZoneChart
                        elevationSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Analytics")
            .themedScreenBackground()
        }
        .task(id: dataManager.sessions.count) {
            recomputeAnalytics()
        }
    }

    // MARK: - Analytics Cache

    private func recomputeAnalytics() {
        let currentSessions = dataManager.sessions
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
        .themedCard()
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
        .themedCard(accent: ShuttlXColor.forRecovery(recovery), headerLabel: "RECOVERY")
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

    // MARK: - Fitness Trend Chart

    private var fitnessTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training Load Trend")
                .font(ShuttlXFont.cardTitle)

            let chartStyle = themeManager.current.chartStyle
            if weeklyTrend.isEmpty {
                ThemedBarChart.emptyState(chartStyle: chartStyle, height: 180)
            } else {
                ThemedLineChart(
                    labels: weeklyTrend.map { $0.weekLabel },
                    values: weeklyTrend.map { $0.trainingLoad },
                    yUnit: "",
                    chartHeight: 180,
                    chartStyle: chartStyle
                )
            }
        }
        .padding(16)
        .themedCard(
            accent: ShuttlXColor.running,
            statusLine: (mode: "LOAD", file: "trend.json", position: "6w"),
            headerLabel: "TRAINING LOAD"
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let summary = weeklyTrend.map { "\($0.weekLabel) load \(String(format: "%.0f", $0.trainingLoad))" }.joined(separator: ", ")
            return "Training load trend: \(summary.isEmpty ? "no data" : summary)"
        }())
    }

    // MARK: - Weekly Volume Chart

    private var weeklyVolumeChart: some View {
        let chartStyle = themeManager.current.chartStyle
        let volumeValues = weeklyTrend.map { $0.totalDuration / 60.0 }
        let volumeLabels = weeklyTrend.map { $0.weekLabel }
        let a11yLabel = weeklyTrend.map {
            "\($0.weekLabel) \(Int($0.totalDuration / 60)) minutes"
        }.joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Volume")
                .font(ShuttlXFont.cardTitle)

            if weeklyTrend.isEmpty {
                ThemedBarChart.emptyState(chartStyle: chartStyle, height: 160)
            } else {
                ThemedBarChart(
                    values: volumeValues,
                    labels: volumeLabels,
                    yUnit: "m",
                    chartHeight: 200,
                    chartStyle: chartStyle
                )
            }

            // Distance sub-row (keep for all themes)
            if !weeklyTrend.isEmpty {
                HStack {
                    ForEach(weeklyTrend) { week in
                        VStack(spacing: 2) {
                            Text(FormattingUtils.formatDistance(week.totalDistance))
                                .font(ShuttlXFont.microLabel)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text("\(week.sessionCount)")
                                .font(ShuttlXFont.microLabel)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .themedCard(accent: ShuttlXColor.calories, headerLabel: "WEEKLY VOLUME")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly training volume: \(a11yLabel.isEmpty ? "no data" : a11yLabel)")
    }

    // MARK: - VO2max Card

    @ViewBuilder
    private var vo2maxCard: some View {
        if let vo2 = vo2max {
            let trending = previousVO2max.map { vo2 > $0 }

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Est. VO2max")
                            .font(ShuttlXFont.sectionHeader)

                        Text(vo2maxCategory(vo2))
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", vo2))
                            .font(ShuttlXFont.metricLarge)
                            .foregroundStyle(ShuttlXColor.running)

                        if let isUp = trending {
                            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                                .font(ShuttlXFont.sectionHeader)
                                .foregroundStyle(isUp ? ShuttlXColor.positive : ShuttlXColor.negative)
                        }
                    }
                }

                Text("ml/kg/min")
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .themedCard(
                accent: ShuttlXColor.pace,
                statusLine: (mode: "VO2", file: "fitness.json", position: "1:1"),
                headerLabel: "VO2MAX"
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estimated VO2 max: \(String(format: "%.1f", vo2)) milliliters per kilogram per minute. \(vo2maxCategory(vo2))")
        }
    }

    private func estimatePreviousVO2Max(sessions: [TrainingSession]) -> Double? {
        let calendar = Calendar.current
        guard let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date()) else { return nil }
        let olderSessions = sessions.filter { $0.startDate < fourWeeksAgo }
        return AnalyticsEngine.estimatedVO2Max(sessions: olderSessions)
    }

    private func vo2maxCategory(_ value: Double) -> String {
        switch value {
        case ..<30: return "Below Average"
        case 30..<37: return "Average"
        case 37..<42: return "Above Average"
        case 42..<50: return "Good"
        case 50..<55: return "Excellent"
        default: return "Elite"
        }
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
                        title: "Fastest km",
                        value: FormattingUtils.formatPace(pace),
                        date: records.fastestKmDate,
                        icon: "hare.fill",
                        color: ShuttlXColor.running
                    )
                }

                if let dist = records.mostDistance {
                    PRCard(
                        title: "Longest Run",
                        value: FormattingUtils.formatDistance(dist),
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
        .themedCard(
            accent: ShuttlXColor.positive,
            statusLine: (mode: "PR", file: "records.json", position: "4:1"),
            headerLabel: "PERSONAL RECORDS"
        )
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
            .themedCard(
                accent: ShuttlXColor.pace,
                statusLine: (mode: "PACE", file: "zones.json", position: "5:1"),
                headerLabel: "PACE ZONES"
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pace zone distribution: \(a11yLabel)")
        }
    }

    private func paceZoneBarColor(zone: String, chartStyle: ThemeChartStyle) -> Color {
        // Keep stock pace zone colors for Clean / Mixtape / Classic Radio;
        // for other themes use the chart accent tinted by zone intensity
        switch chartStyle.barShape {
        case .roundedSwiftCharts, .tapeStrip, .needle:
            return ShuttlXColor.forPaceZone(zone)
        default:
            return chartStyle.accentColor.opacity(0.70)
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
            .themedCard(accent: ShuttlXColor.hiking, headerLabel: "ELEVATION")
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
        .themedCard(accent: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(DataManager())
}
