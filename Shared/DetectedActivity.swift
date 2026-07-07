import Foundation

/// Motion-classified activity for a workout segment. Single source of truth —
/// theme-coupled color lives in each app target's DetectedActivity+Theme.swift.
public enum DetectedActivity: String, Codable, CaseIterable, Sendable {
    case running
    case walking
    case stationary
    case unknown

    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .stationary, .unknown: return "Stationary"
        }
    }

    public var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .stationary, .unknown: return "figure.stand"
        }
    }
}
