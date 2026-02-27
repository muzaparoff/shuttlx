import Foundation

struct RoutePoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date

    init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }
}
