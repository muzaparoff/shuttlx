import SwiftUI
import ShuttlXShared

// Theme-coupled surface of DetectedActivity — stays per target because
// ShuttlXColor bridges to this target's ThemeManager.
extension DetectedActivity {
    var color: Color { themeColor }

    var themeColor: Color {
        switch self {
        case .running: return ShuttlXColor.running
        case .walking: return ShuttlXColor.walking
        case .stationary, .unknown: return ShuttlXColor.stationary
        }
    }
}
