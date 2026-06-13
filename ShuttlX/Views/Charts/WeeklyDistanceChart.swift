import SwiftUI
import Charts

struct WeeklyDistanceChart: View {
    let summaries: [DailyWorkoutSummary]
    @Environment(ThemeManager.self) private var themeManager

    private var chartStyle: ThemeChartStyle { themeManager.current.chartStyle }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distance")
                .font(ShuttlXFont.cardTitle)

            if summaries.isEmpty {
                ThemedBarChart.emptyState(chartStyle: chartStyle, height: 160)
            } else {
                ThemedBarChart(
                    values: summaries.map { $0.totalDistance },
                    labels: summaries.map { $0.dayLabel },
                    yUnit: "",
                    chartHeight: 160,
                    chartStyle: chartStyle
                )
            }
        }
        .padding(16)
        .themedCard(accent: ShuttlXColor.running, headerLabel: "DISTANCE")
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let summary = summaries.map {
                "\($0.dayLabel) \(String(format: "%.1f", $0.totalDistance)) km"
            }.joined(separator: ", ")
            return "Weekly distance: \(summary.isEmpty ? "no data" : summary)"
        }())
    }
}

#Preview {
    WeeklyDistanceChart(summaries: [
        DailyWorkoutSummary(date: Date().addingTimeInterval(-6*86400), totalDuration: 1800, totalDistance: 3.2, totalCalories: 280, averageHeartRate: 145, averagePace: 562, sessionCount: 1),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-5*86400), totalDuration: 0, totalDistance: 0, totalCalories: 0, averageHeartRate: nil, averagePace: nil, sessionCount: 0),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-4*86400), totalDuration: 2400, totalDistance: 4.5, totalCalories: 350, averageHeartRate: 152, averagePace: 533, sessionCount: 1),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-3*86400), totalDuration: 0, totalDistance: 0, totalCalories: 0, averageHeartRate: nil, averagePace: nil, sessionCount: 0),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-2*86400), totalDuration: 1500, totalDistance: 2.8, totalCalories: 200, averageHeartRate: 138, averagePace: 535, sessionCount: 1),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-1*86400), totalDuration: 3000, totalDistance: 5.1, totalCalories: 420, averageHeartRate: 155, averagePace: 588, sessionCount: 2),
        DailyWorkoutSummary(date: Date(), totalDuration: 1200, totalDistance: 2.0, totalCalories: 180, averageHeartRate: 140, averagePace: 600, sessionCount: 1)
    ])
    .padding()
    .environment(ThemeManager.shared)
}
