import Foundation

public struct RoutePoint: Identifiable, Codable, Hashable, Sendable {
    public var id: Date { timestamp }
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let timestamp: Date
    public let speed: Double?
    public let horizontalAccuracy: Double?

    public init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date = Date(), speed: Double? = nil, horizontalAccuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }
}

extension Array where Element == RoutePoint {
    /// Keeps every other point (the last one always stays) once the array holds more than `limit`:
    /// the route keeps its shape while memory and checkpoints stay bounded.
    public mutating func thinIfOver(_ limit: Int) {
        guard count > limit, let last else { return }
        self = enumerated().compactMap { $0.offset % 2 == 0 ? $0.element : nil }
        if self.last?.timestamp != last.timestamp { append(last) }
    }

    /// Once the array holds more than `limit`, keeps the first point of each of `target` equal time slices
    /// of the whole route, every point of the last `tail` seconds (the activity classifier reads them) and
    /// the last point. Unlike calling `thinIfOver` on every append (which re-halves old points each time, so
    /// the start of a long route decays to a few points), the density stays even from start to end.
    /// Runs only on overflow: about once per `limit - target` appended fixes.
    public mutating func thinEvenlyIfOver(_ limit: Int, to target: Int, keepingLast tail: TimeInterval = 60) {
        guard count > limit, target > 1, let first, let last else { return }
        let slice = Swift.max(last.timestamp.timeIntervalSince(first.timestamp), 1) / Double(target - 1)
        let tailStart = last.timestamp.addingTimeInterval(-tail)
        var kept: [RoutePoint] = []
        kept.reserveCapacity(target + 64)
        var bucket = -1
        for p in self {
            let b = Int(p.timestamp.timeIntervalSince(first.timestamp) / slice)
            if b > bucket || p.timestamp >= tailStart {
                kept.append(p)
                bucket = Swift.max(bucket, b)
            }
        }
        self = kept   // the last point is always in the tail
    }
}
