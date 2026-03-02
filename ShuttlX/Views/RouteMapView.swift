import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: [RoutePoint]
    let segments: [ActivitySegment]
    var kmSplits: [KmSplitData]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Route")
                .font(ShuttlXFont.sectionHeader)

            Map {
                // Color-coded polylines per segment
                ForEach(coloredPolylines) { polyline in
                    MapPolyline(coordinates: polyline.coordinates)
                        .stroke(polyline.color, lineWidth: 4)
                }

                // Per-km pace markers
                ForEach(kmMarkers) { marker in
                    Annotation("", coordinate: marker.coordinate) {
                        VStack(spacing: 0) {
                            Text("km \(marker.km)")
                                .font(.system(size: 9, weight: .bold))
                            Text(marker.paceLabel)
                                .font(.system(size: 8).monospacedDigit())
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Start marker
                if let first = route.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }

                // End marker
                if let last = route.last, route.count > 1 {
                    Annotation("Finish", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(4)
                            .background(.white, in: Circle())
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Workout route map")
        }
    }

    // MARK: - Km markers from splits + route points

    private struct KmMarker: Identifiable {
        let id = UUID()
        let km: Int
        let coordinate: CLLocationCoordinate2D
        let paceLabel: String
    }

    private var kmMarkers: [KmMarker] {
        guard let splits = kmSplits, !splits.isEmpty, route.count >= 2 else { return [] }

        var markers: [KmMarker] = []
        var cumulativeDistance: Double = 0
        var routeIndex = 1

        for split in splits {
            let targetKm = Double(split.kmNumber)

            // Walk along route points until we reach this km mark
            while routeIndex < route.count && cumulativeDistance < targetKm {
                let prev = route[routeIndex - 1]
                let curr = route[routeIndex]
                let segDist = haversineDistance(
                    lat1: prev.latitude, lon1: prev.longitude,
                    lat2: curr.latitude, lon2: curr.longitude
                )
                cumulativeDistance += segDist
                routeIndex += 1
            }

            // Use the route point closest to this km mark
            let pointIndex = min(routeIndex - 1, route.count - 1)
            let point = route[pointIndex]
            let coord = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)

            let mins = Int(split.splitTime) / 60
            let secs = Int(split.splitTime) % 60
            let paceStr = String(format: "%d:%02d/km", mins, secs)

            markers.append(KmMarker(km: split.kmNumber, coordinate: coord, paceLabel: paceStr))
        }

        return markers
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    // MARK: - Color-coded polylines

    private struct ColoredPolyline: Identifiable {
        let id = UUID()
        let activityType: DetectedActivity
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    private var coloredPolylines: [ColoredPolyline] {
        guard !segments.isEmpty, route.count >= 2 else {
            // No segments — draw entire route in green
            let coords = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            return [ColoredPolyline(activityType: .running, coordinates: coords, color: ShuttlXColor.running)]
        }

        var polylines: [ColoredPolyline] = []

        for segment in segments {
            let segEnd = segment.endDate ?? Date()
            let segPoints = route.filter { $0.timestamp >= segment.startDate && $0.timestamp <= segEnd }

            guard segPoints.count >= 2 else { continue }

            let coords = segPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            polylines.append(ColoredPolyline(
                activityType: segment.activityType,
                coordinates: coords,
                color: segment.activityType.themeColor
            ))
        }

        // Fallback if no segment matched enough points
        if polylines.isEmpty {
            let coords = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            return [ColoredPolyline(activityType: .running, coordinates: coords, color: ShuttlXColor.running)]
        }

        return polylines
    }
}

#Preview {
    RouteMapView(
        route: [
            RoutePoint(latitude: 55.7558, longitude: 37.6173, timestamp: Date().addingTimeInterval(-1800)),
            RoutePoint(latitude: 55.7560, longitude: 37.6180, timestamp: Date().addingTimeInterval(-1700)),
            RoutePoint(latitude: 55.7565, longitude: 37.6190, timestamp: Date().addingTimeInterval(-1600)),
            RoutePoint(latitude: 55.7570, longitude: 37.6200, timestamp: Date().addingTimeInterval(-1500)),
            RoutePoint(latitude: 55.7575, longitude: 37.6195, timestamp: Date().addingTimeInterval(-1200)),
            RoutePoint(latitude: 55.7580, longitude: 37.6185, timestamp: Date().addingTimeInterval(-900)),
            RoutePoint(latitude: 55.7583, longitude: 37.6175, timestamp: Date().addingTimeInterval(-600)),
            RoutePoint(latitude: 55.7585, longitude: 37.6165, timestamp: Date().addingTimeInterval(-300)),
        ],
        segments: [
            ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(-1500)),
            ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1500), endDate: Date().addingTimeInterval(-600)),
            ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-600), endDate: Date()),
        ]
    )
    .padding()
}
