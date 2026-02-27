import SwiftUI
import Charts

struct WeeklyDistanceChart: View {
    let summaries: [DailyWorkoutSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distance")
                .font(ShuttlXFont.cardTitle)

            Chart(summaries) { day in
                BarMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Distance", day.totalDistance)
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
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let km = value.as(Double.self) {
                            Text(String(format: "%.1f", km))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly distance chart")
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
}
