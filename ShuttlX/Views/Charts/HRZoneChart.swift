import SwiftUI
import Charts

struct HRZoneChart: View {
    let zones: [HRZoneDistribution]
    @Environment(ThemeManager.self) private var themeManager

    private var chartStyle: ThemeChartStyle { themeManager.current.chartStyle }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Zones")
                .font(ShuttlXFont.cardTitle)

            if zones.isEmpty {
                Text("No heart rate data")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else if chartStyle.barShape == .dbMeter {
                // VU Meter: horizontal segmented dB strips
                vuMeterZoneLayout
            } else {
                // All other themes: Swift Charts horizontal bar
                swiftChartsZones
            }
        }
        .padding(16)
        .themedCard(accent: ShuttlXColor.heartRate, headerLabel: "HR ZONES")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let summary = zones.map { "\($0.zone): \(String(format: "%.0f", $0.percentage)) percent" }.joined(separator: ", ")
            return "Heart rate zone distribution. \(summary)"
        }())
    }

    // MARK: - Swift Charts (Clean + Mixtape + stock themes)

    private var swiftChartsZones: some View {
        Chart(zones) { zone in
            BarMark(
                x: .value("Percentage", zone.percentage),
                y: .value("Zone", zone.zone)
            )
            .foregroundStyle(zoneBarColor(zone))
            .cornerRadius(4)
            .annotation(position: .trailing) {
                Text(String(format: "%.0f%%", zone.percentage))
                    .font(ShuttlXFont.microLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(ShuttlXFont.microLabel)
            }
        }
        .frame(height: CGFloat(zones.count) * 32 + 20)
        .accessibilityHidden(true)
    }

    // MARK: - VU Meter: dB segment strips

    private var vuMeterZoneLayout: some View {
        let maxPercent = zones.map { $0.percentage }.max() ?? 100
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(zones) { zone in
                HStack(spacing: 8) {
                    Text(zone.zone)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(chartStyle.axisLabelColor)
                        .frame(width: 44, alignment: .trailing)
                        .accessibilityHidden(true)

                    VUMeterDBStrip(
                        fillFraction: maxPercent > 0 ? zone.percentage / maxPercent : 0,
                        amberColor: chartStyle.accentColor,
                        redZoneColor: chartStyle.accentColor,
                        height: 18
                    )

                    Text(String(format: "%.0f%%", zone.percentage))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(chartStyle.axisLabelColor)
                        .frame(width: 28, alignment: .trailing)
                        .monospacedDigit()
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Helpers

    private func zoneBarColor(_ zone: HRZoneDistribution) -> Color {
        // Clean and Mixtape keep stock zone colours; others use accent
        switch chartStyle.barShape {
        case .roundedSwiftCharts, .tapeStrip:
            return zone.color
        default:
            return chartStyle.accentColor.opacity(0.75)
        }
    }
}

#Preview {
    HRZoneChart(zones: [
        HRZoneDistribution(zone: "Zone 2", percentage: 30, color: .green),
        HRZoneDistribution(zone: "Zone 3", percentage: 45, color: .yellow),
        HRZoneDistribution(zone: "Zone 4", percentage: 25, color: .orange)
    ])
    .padding()
    .environment(ThemeManager.shared)
}
