import SwiftUI
import Charts

struct ElevationProfileView: View {
    let route: [RoutePoint]

    private var elevationData: [ElevationPoint] {
        guard route.count >= 2 else { return [] }

        var cumulativeDistance: Double = 0
        var points: [ElevationPoint] = []

        for i in 0..<route.count {
            let point = route[i]
            guard let altitude = point.altitude else { continue }

            if i > 0 {
                let prev = route[i - 1]
                let dx = haversineDistance(
                    lat1: prev.latitude, lon1: prev.longitude,
                    lat2: point.latitude, lon2: point.longitude
                )
                cumulativeDistance += dx
            }

            points.append(ElevationPoint(distance: cumulativeDistance, altitude: altitude))
        }

        return points
    }

    private var stats: ElevationStats {
        let altitudes = route.compactMap { $0.altitude }
        guard altitudes.count >= 2 else {
            return ElevationStats(ascent: 0, descent: 0, maxAltitude: 0, minAltitude: 0)
        }

        var ascent: Double = 0
        var descent: Double = 0

        for i in 1..<altitudes.count {
            let diff = altitudes[i] - altitudes[i - 1]
            if diff > 0 { ascent += diff }
            else { descent += abs(diff) }
        }

        return ElevationStats(
            ascent: ascent,
            descent: descent,
            maxAltitude: altitudes.max() ?? 0,
            minAltitude: altitudes.min() ?? 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation")
                .font(ShuttlXFont.sectionHeader)

            if elevationData.count >= 2 {
                Chart(elevationData) { point in
                    AreaMark(
                        x: .value("Distance (km)", point.distance),
                        y: .value("Altitude (m)", point.altitude)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ShuttlXColor.running.opacity(0.4), ShuttlXColor.running.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Distance (km)", point.distance),
                        y: .value("Altitude (m)", point.altitude)
                    )
                    .foregroundStyle(ShuttlXColor.running)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYScale(domain: (stats.minAltitude - 5)...(stats.maxAltitude + 5))
                .chartXAxisLabel("km")
                .chartYAxisLabel("m")
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Stats row
                HStack(spacing: 0) {
                    elevationStat(title: "Ascent", value: String(format: "%.0f m", stats.ascent), icon: "arrow.up.right")
                    Spacer()
                    elevationStat(title: "Descent", value: String(format: "%.0f m", stats.descent), icon: "arrow.down.right")
                    Spacer()
                    elevationStat(title: "Max", value: String(format: "%.0f m", stats.maxAltitude), icon: "mountain.2")
                    Spacer()
                    elevationStat(title: "Min", value: String(format: "%.0f m", stats.minAltitude), icon: "water.waves")
                }
            } else {
                Text("Not enough elevation data")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func elevationStat(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Haversine distance in km between two GPS points
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0 // Earth radius in km
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

private struct ElevationPoint: Identifiable {
    let id = UUID()
    let distance: Double
    let altitude: Double
}

private struct ElevationStats {
    let ascent: Double
    let descent: Double
    let maxAltitude: Double
    let minAltitude: Double
}
