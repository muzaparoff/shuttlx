import Foundation

/// What list screens need from a route without loading its points (plan 2026-10 part B, 4.1).
/// Elevation uses raw altitude differences, no smoothing: the loop of `AnalyticsEngine.elevationSummary`.
public struct RouteSummary: Codable, Hashable, Sendable {
    public var pointCount: Int
    /// Points that carry an altitude. `elevationSummary` counts a route only from 2; `latestElevationRoute` from 1.
    public var altitudeCount: Int
    public var startLatitude: Double
    public var startLongitude: Double
    /// Sums over consecutive altitudes (points without one are skipped); 0 with fewer than 2.
    public var ascent: Double
    public var descent: Double
    /// nil when no point has an altitude.
    public var maxAltitude: Double?

    /// nil for an empty route.
    public init?(points: [RoutePoint]) {
        guard let first = points.first else { return nil }
        let altitudes = points.compactMap(\.altitude)
        var ascent = 0.0
        var descent = 0.0
        for i in altitudes.indices.dropFirst() {
            let diff = altitudes[i] - altitudes[i - 1]
            if diff > 0 { ascent += diff } else { descent += abs(diff) }
        }
        self.pointCount = points.count
        self.altitudeCount = altitudes.count
        self.startLatitude = first.latitude
        self.startLongitude = first.longitude
        self.ascent = ascent
        self.descent = descent
        self.maxAltitude = altitudes.max()
    }
}
