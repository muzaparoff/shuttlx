import SwiftUI
import Charts

struct PaceTrendChart: View {
    let summaries: [DailyWorkoutSummary]

    private var paceData: [DailyWorkoutSummary] {
        summaries.filter { $0.averagePace != nil && $0.averagePace! > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace Trend")
                .font(ShuttlXFont.cardTitle)

            if paceData.isEmpty {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(paceData) { day in
                    LineMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Pace", (day.averagePace ?? 0) / 60.0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.purple)

                    PointMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Pace", (day.averagePace ?? 0) / 60.0)
                    )
                    .foregroundStyle(.purple)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text(String(format: "%.0f'", mins))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pace trend chart")
    }
}

#Preview {
    PaceTrendChart(summaries: [
        DailyWorkoutSummary(date: Date().addingTimeInterval(-4*86400), totalDuration: 2400, totalDistance: 4.5, totalCalories: 350, averageHeartRate: 152, averagePace: 533, sessionCount: 1),
        DailyWorkoutSummary(date: Date().addingTimeInterval(-2*86400), totalDuration: 1500, totalDistance: 2.8, totalCalories: 200, averageHeartRate: 138, averagePace: 535, sessionCount: 1),
        DailyWorkoutSummary(date: Date(), totalDuration: 1200, totalDistance: 2.0, totalCalories: 180, averageHeartRate: 140, averagePace: 600, sessionCount: 1)
    ])
    .padding()
}
