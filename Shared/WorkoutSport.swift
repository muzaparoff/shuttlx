import Foundation
#if canImport(HealthKit) && !os(macOS)
import HealthKit
#endif

public enum WorkoutSport: String, Codable, CaseIterable, Identifiable, Sendable {
    case running
    case walking
    case cycling
    case swimming
    case hiking
    case elliptical
    case crossTraining
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .elliptical: return "Elliptical"
        case .crossTraining: return "Cross Training"
        case .other: return "Other"
        }
    }

    public var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .elliptical: return "figure.elliptical"
        case .crossTraining: return "figure.mixed.cardio"
        case .other: return "figure.mixed.cardio"
        }
    }

    public var supportsAutoDetection: Bool {
        switch self {
        case .running, .walking: return true
        default: return false
        }
    }

    #if canImport(HealthKit) && !os(macOS)
    public var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .hiking: return .hiking
        case .elliptical: return .elliptical
        case .crossTraining: return .crossTraining
        case .other: return .mixedCardio
        }
    }

    public var hkLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .running, .walking, .cycling, .hiking: return .outdoor
        case .swimming: return .unknown
        case .elliptical, .crossTraining: return .indoor
        case .other: return .unknown
        }
    }
    #endif
}
