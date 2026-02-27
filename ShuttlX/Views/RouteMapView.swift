import SwiftUI
import MapKit

struct RouteMapView: View {
    let route: [RoutePoint]
    let segments: [ActivitySegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Route")
                .font(ShuttlXFont.sectionHeader)

            Map {
                // Color-coded polylines per segment
                ForEach(coloredPolylines, id: \.activityType) { polyline in
                    MapPolyline(coordinates: polyline.coordinates)
                        .stroke(polyline.color, lineWidth: 4)
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

    // MARK: - Color-coded polylines

    private struct ColoredPolyline {
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
