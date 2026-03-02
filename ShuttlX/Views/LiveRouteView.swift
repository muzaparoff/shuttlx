import SwiftUI
import MapKit

struct LiveRouteView: View {
    let routePoints: [RoutePoint]
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !compact {
                Text("Live Route")
                    .font(ShuttlXFont.sectionHeader)
            }

            if routePoints.count >= 2 {
                Map {
                    MapPolyline(coordinates: coordinates)
                        .stroke(ShuttlXColor.running, lineWidth: 3)

                    // Current position marker
                    if let last = routePoints.last {
                        Annotation("Now", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                            Circle()
                                .fill(ShuttlXColor.running)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                )
                                .shadow(color: ShuttlXColor.running.opacity(0.5), radius: 4)
                        }
                    }

                    // Start marker
                    if let first = routePoints.first {
                        Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                            Circle()
                                .fill(ShuttlXColor.running)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: compact ? 120 : 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if routePoints.count == 1 {
                // Single point — show waiting state
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: compact ? 120 : 200)

                    VStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(ShuttlXColor.running)
                        Text("Acquiring route...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
