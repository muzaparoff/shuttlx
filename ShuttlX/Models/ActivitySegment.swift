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
        case .stationary: return "Stationary"
        case .unknown: return "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .stationary: return "pause.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .running: return .green
        case .walking: return .orange
        case .stationary: return .gray
        case .unknown: return .secondary
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
