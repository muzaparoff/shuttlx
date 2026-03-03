import SwiftUI
import os.log

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "ThemeManager")
    private let defaultsKey = "selectedThemeID"
    private let appGroupID = "group.com.shuttlx.shared"

    // Both stored so @Observable generates proper tracking for each
    var selectedThemeID: String = "clean"
    private(set) var current: AppTheme = .clean

    var colors: ThemeColors { current.colors }
    var fonts: ThemeFonts { current.fonts }
    var effects: ThemeEffects { current.effects }

    func selectTheme(_ id: String) {
        guard id != selectedThemeID else { return }
        selectedThemeID = id
        current = AppTheme.theme(for: id)
        persist()
        logger.info("Theme changed to: \(id)")
    }

    init() {
        if let defaults = UserDefaults(suiteName: appGroupID),
           let saved = defaults.string(forKey: defaultsKey) {
            selectedThemeID = saved
            current = AppTheme.theme(for: saved)
        }
    }

    private func persist() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(selectedThemeID, forKey: defaultsKey)
    }
}
