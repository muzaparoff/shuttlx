import SwiftUI
import Charts

struct PaceTrendChart: View {
    let summaries: [DailyWorkoutSummary]
    @Environment(ThemeManager.self) private var themeManager

    private var chartStyle: ThemeChartStyle { themeManager.current.chartStyle }

    private var paceData: [DailyWorkoutSummary] {
        summaries.filter { ($0.averagePace ?? 0) > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace Trend")
                .font(ShuttlXFont.cardTitle)

            if paceData.isEmpty {
                ThemedBarChart.emptyState(chartStyle: chartStyle, height: 140)
            } else {
                ThemedLineChart(
                    labels: paceData.map { $0.dayLabel },
                    values: paceData.map { ($0.averagePace ?? 0) / 60.0 },
                    yUnit: "'",
                    chartHeight: 140,
                    chartStyle: chartStyle
                )

            }
        }
        .padding(16)
        .themedCard(accent: ShuttlXColor.pace, headerLabel: "PACE TREND")
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let summary = paceData.map {
                "\($0.dayLabel) \(String(format: "%.1f", ($0.averagePace ?? 0) / 60)) min per km"
            }.joined(separator: ", ")
            return "Pace trend: \(summary.isEmpty ? "no data" : summary)"
        }())
    }
}

#Preview {
    PaceTrendChart(summaries: [
        DailyWorkoutSummary(date: Date().addingTimeInterval(-4*86400), totalDuration: 2400, totalDistance: 4.5, totalCalories: 350, averageHeartRate: 152, averagePace: 533, sessionCount: 1),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-2*86400), totalDuration: 1500, totalDistance: 2.8, totalCalories: 200, averageHeartRate: 138, averagePace: 535, sessionCount: 1),
        DailyWorkoutSummary(date: Date(), totalDuration: 1200, totalDistance: 2.0, totalCalories: 180, averageHeartRate: 140, averagePace: 600, sessionCount: 1)
    ])
    .padding()
    .environment(ThemeManager.shared)
}
