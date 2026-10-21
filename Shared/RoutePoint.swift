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
}
