import Foundation
import SwiftUI

enum DetectedActivity: String, Codable, CaseIterable {
    case running
    case walking
    case stationary
    case unknown

    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .stationary, .unknown: return "Stationary"
        }
    }

    var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .stationary, .unknown: return "figure.stand"
        }
    }

    var color: Color { themeColor }

    var themeColor: Color {
        switch self {
        case .running: return ShuttlXColor.running
        case .walking: return ShuttlXColor.walking
        case .stationary, .unknown: return ShuttlXColor.stationary
        }
    }
}

struct ActivitySegment: Identifiable, Codable, Hashable {
    let id: UUID
    var activityType: DetectedActivity
    var startDate: Date
    var endDate: Date?
    var steps: Int?
    var distance: Double?

    var duration: TimeInterval {
        guard let end = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return end.timeIntervalSince(startDate)
    }

    init(id: UUID = UUID(), activityType: DetectedActivity, startDate: Date, endDate: Date? = nil, steps: Int? = nil, distance: Double? = nil) {
        self.id = id
        self.activityType = activityType
        self.startDate = startDate
        self.endDate = endDate
        self.steps = steps
        self.distance = distance
    }
}
