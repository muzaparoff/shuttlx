import WidgetKit
import SwiftUI

// MARK: - WidgetTheme
// Provides background, surface, and accent colors per theme ID.
// Widget extensions cannot access ShuttlXColor/ThemeManager — all colors are defined locally.
//
// Only "clean" is a live theme (Synthwave, Arcade, Classic Radio, Neovim, FM Tuner,
// VU Meter and Mixtape were deleted app-wide). Unknown ids fall back to Clean.

struct WidgetTheme {
    let background: Color
    let backgroundDark: Color  // slightly darker, used as gradient end
    let surface: Color
    let accent: Color

    static func forID(_ id: String) -> WidgetTheme {
        // Single theme today; switch on `id` when another is added.
        return WidgetTheme(
            background:     Color(red: 0.08, green: 0.08, blue: 0.12),
            backgroundDark: Color(red: 0.04, green: 0.04, blue: 0.08),
            surface:        Color(red: 0.14, green: 0.14, blue: 0.20),
            accent:         Color(red: 0.25, green: 0.80, blue: 0.45)   // system green
        )
    }

    /// Reads the active theme ID from the App Group UserDefaults. Shared by
    /// every timeline provider in this target — avoids re-implementing the
    /// same UserDefaults lookup per widget file.
    static func currentThemeID() -> String {
        UserDefaults(suiteName: "group.com.shuttlx.shared")?.string(forKey: "selectedThemeID") ?? "clean"
    }

    static func fromDefaults() -> WidgetTheme {
        forID(currentThemeID())
    }
}

// MARK: - Semantic metric colors (fixed, independent of theme)

enum WidgetMetricColor {
    static let duration  = Color(red: 0.30, green: 0.65, blue: 0.85)  // blue
    static let distance  = Color(red: 0.30, green: 0.75, blue: 0.55)  // teal-green
    static let heartRate = Color(red: 0.88, green: 0.32, blue: 0.35)  // rose
    static let calories  = Color(red: 0.95, green: 0.55, blue: 0.10)  // amber-orange
}
