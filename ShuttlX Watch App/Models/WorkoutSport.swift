import Foundation
import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif

enum WorkoutSport: String, Codable, CaseIterable, Identifiable {
    case running
    case walking
    case cycling
    case swimming
    case hiking
    case elliptical
    case crossTraining
    case other

    var id: String { rawValue }

    var displayName: String {
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

    var systemImage: String {
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

    #if canImport(HealthKit)
    var hkActivityType: HKWorkoutActivityType {
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

    var hkLocationType: HKWorkoutSessionLocationType {
        switch self {
        case .running, .walking, .cycling, .hiking: return .outdoor
        case .swimming: return .unknown
        case .elliptical, .crossTraining: return .indoor
        case .other: return .unknown
        }
    }
    #endif

    var supportsAutoDetection: Bool {
        switch self {
        case .running, .walking: return true
        default: return false
        }
    }

    var themeColor: Color {
        switch self {
        case .running: return ShuttlXColor.running
        case .walking: return ShuttlXColor.walking
        case .cycling: return ShuttlXColor.cycling
        case .swimming: return ShuttlXColor.swimming
        case .hiking: return ShuttlXColor.hiking
        case .elliptical: return ShuttlXColor.elliptical
        case .crossTraining: return ShuttlXColor.crossTraining
        case .other: return .secondary
        }
    }
}
