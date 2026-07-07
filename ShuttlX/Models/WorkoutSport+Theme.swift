import SwiftUI
import ShuttlXShared

// Theme-coupled surface of WorkoutSport — stays per target because
// ShuttlXColor bridges to this target's ThemeManager.
extension WorkoutSport {
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
