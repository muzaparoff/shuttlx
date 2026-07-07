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
