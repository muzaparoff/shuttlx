import Foundation

struct RoutePoint: Identifiable, Codable, Hashable {
    var id: Date { timestamp }
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date
    let speed: Double?
    let horizontalAccuracy: Double?

    init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date = Date(), speed: Double? = nil, horizontalAccuracy: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }
}
