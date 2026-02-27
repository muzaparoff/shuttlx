import SwiftUI
import Charts

struct HRZoneChart: View {
    let zones: [HRZoneDistribution]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Zones")
                .font(ShuttlXFont.cardTitle)

            if zones.isEmpty {
                Text("No heart rate data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(zones) { zone in
                    BarMark(
                        x: .value("Percentage", zone.percentage),
                        y: .value("Zone", zone.zone)
                    )
                    .foregroundStyle(zone.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.0f%%", zone.percentage))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: CGFloat(zones.count) * 32 + 20)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate zone distribution")
    }
}

#Preview {
    HRZoneChart(zones: [
        HRZoneDistribution(zone: "Zone 2", percentage: 30, color: .green),
        HRZoneDistribution(zone: "Zone 3", percentage: 45, color: .yellow),
        HRZoneDistribution(zone: "Zone 4", percentage: 25, color: .orange)
    ])
    .padding()
}
