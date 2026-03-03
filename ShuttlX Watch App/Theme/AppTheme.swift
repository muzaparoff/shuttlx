import SwiftUI

struct AppTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let icon: String
    let colors: ThemeColors
    let fonts: ThemeFonts
    let effects: ThemeEffects

    static let all: [AppTheme] = [.clean, .synthwave, .casio, .arcade]

    static func theme(for id: String) -> AppTheme {
        all.first { $0.id == id } ?? .clean
    }
}
