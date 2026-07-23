import SwiftUI

// MARK: - AppTheme
//
// `colors`, `fonts`, `effects`, `chartStyle` are `var` so callers can copy an
// existing theme and override individual tokens:
//   var t = SynthwaveTheme.theme
//   t.colors.running = .pink
//
// `id`, `displayName`, `icon` stay `let` — they form the theme's identity.
// `all` is `static var` to allow dynamic registration of custom themes via
//   AppTheme.all.append(myTheme)

struct AppTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let icon: String
    var colors: ThemeColors         = ThemeColors()
    var fonts: ThemeFonts           = ThemeFonts()
    var effects: ThemeEffects       = ThemeEffects()
    var chartStyle: ThemeChartStyle = ThemeChartStyle()

    static var all: [AppTheme] = [.clean, .mixtape]

    static func theme(for id: String) -> AppTheme {
        all.first { $0.id == id } ?? .clean
    }
}
