import Foundation

public struct ActivitySegment: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var activityType: DetectedActivity
    public var startDate: Date
    public var endDate: Date?
    public var steps: Int?
    public var distance: Double?

    public var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    public init(id: UUID = UUID(), activityType: DetectedActivity, startDate: Date, endDate: Date? = nil, steps: Int? = nil, distance: Double? = nil) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
        self.distance = distance
    }
}
