import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager

    private var sessions: [TrainingSession] { dataManager.sessions }
    private var weeklyTrend: [WeeklySummary] { AnalyticsEngine.weeklyTrend(sessions: sessions, weeks: 6) }
    private var records: PersonalRecords { AnalyticsEngine.personalRecords(sessions: sessions) }
    private var recovery: RecoveryStatus { AnalyticsEngine.recoveryStatus(sessions: sessions) }
    private var vo2max: Double? { AnalyticsEngine.estimatedVO2Max(sessions: sessions) }
    private var paceZones: [PaceZoneDistribution] { AnalyticsEngine.paceZones(sessions: sessions) }
    private var elevationSummary: AnalyticsEngine.ElevationSummary? { AnalyticsEngine.elevationSummary(sessions: sessions) }
    private var latestElevationRoute: [RoutePoint]? { AnalyticsEngine.latestElevationRoute(sessions: sessions) }
    private var fitnessScore: Double { AnalyticsEngine.fitnessScore(sessions: sessions) }
    private var fatigueScore: Double { AnalyticsEngine.fatigue(sessions: sessions) }
    private var formScore: Double { AnalyticsEngine.form(sessions: sessions) }

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
        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formScore >= 0 ? "+\(String(format: "%.0f", formScore))" : String(format: "%.0f", formScore))
                        .font(ShuttlXFont.metricMedium)
                        .foregroundStyle(formScore >= 0 ? ShuttlXColor.positive : ShuttlXColor.negative)
                }
            }
        }
        .padding(16)
        .background(ShuttlXColor.forRecovery(recovery).opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ShuttlXColor.forRecovery(recovery).opacity(0.3), lineWidth: 1)
        )
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

            Chart {
                ForEach(weeklyTrend) { week in
                    LineMark(
                        x: .value("Week", week.weekLabel),
                        y: .value("Load", week.trainingLoad)
                    )
                    .foregroundStyle(ShuttlXColor.running)
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)

                    AreaMark(
                        x: .value("Week", week.weekLabel),
                        y: .value("Load", week.trainingLoad)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ShuttlXColor.running.opacity(0.3), ShuttlXColor.running.opacity(0.05)],
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
                        if let load = value.as(Double.self) {
                            Text(String(format: "%.0f", load))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Training load trend over 6 weeks")
    }

    // MARK: - Weekly Volume Chart

    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Volume")
                .font(ShuttlXFont.cardTitle)

            Chart {
                ForEach(weeklyTrend) { week in
                    BarMark(
                        x: .value("Week", week.weekLabel),
                        y: .value("Duration", week.totalDuration / 60.0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ShuttlXColor.running.opacity(0.8), ShuttlXColor.running.opacity(0.4)],
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
                        if let mins = value.as(Double.self) {
                            Text("\(Int(mins))m")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 160)

            // Distance sub-row
            HStack {
                ForEach(weeklyTrend) { week in
                    VStack(spacing: 2) {
                        Text(FormattingUtils.formatDistance(week.totalDistance))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(week.sessionCount)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly training volume over 6 weeks")
    }

    // MARK: - VO2max Card

    @ViewBuilder
    private var vo2maxCard: some View {
        if let vo2 = vo2max {
            let previousVO2 = estimatePreviousVO2Max()
            let trending = previousVO2.map { vo2 > $0 }

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Est. VO2max")
                            .font(ShuttlXFont.sectionHeader)

                        Text(vo2maxCategory(vo2))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", vo2))
                            .font(ShuttlXFont.metricLarge)
                            .foregroundStyle(ShuttlXColor.running)

                        if let isUp = trending {
                            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(isUp ? ShuttlXColor.positive : ShuttlXColor.negative)
                        }
                    }
                }

                Text("ml/kg/min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Estimated VO2 max: \(String(format: "%.1f", vo2)) milliliters per kilogram per minute. \(vo2maxCategory(vo2))")
        }
    }

    private func estimatePreviousVO2Max() -> Double? {
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Pace Zones Chart

    @ViewBuilder
    private var paceZoneChart: some View {
        if !paceZones.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pace Zones")
                    .font(ShuttlXFont.cardTitle)

                ForEach(paceZones) { zone in
                    HStack(spacing: 8) {
                        Text(zone.zone)
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ShuttlXColor.forPaceZone(zone.zone))
                                .frame(width: max(geo.size.width * zone.percentage / 100, 4))
                        }
                        .frame(height: 20)

                        Text(String(format: "%.0f%%", zone.percentage))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                // Legend for pace ranges
                HStack(spacing: 0) {
                    ForEach(["<4:00", "4:00-4:45", "4:45-5:30", "5:30-6:30", ">6:30"], id: \.self) { label in
                        Text(label)
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pace zone distribution: \(paceZones.map { "\($0.zone) \(String(format: "%.0f", $0.percentage)) percent" }.joined(separator: ", "))")
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(ShuttlXFont.prValue)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let date = date {
                Text(FormattingUtils.formatShortDate(date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(DataManager())
}
