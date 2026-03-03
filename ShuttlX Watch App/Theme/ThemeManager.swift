import SwiftUI
import os.log

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ThemeManager")
    private let defaultsKey = "selectedThemeID"
    private let appGroupID = "group.com.shuttlx.shared"

    var selectedThemeID: String {
        didSet {
            guard selectedThemeID != oldValue else { return }
            persist()
            logger.info("Theme changed to: \(self.selectedThemeID)")
        }
    }

    var current: AppTheme {
        AppTheme.theme(for: selectedThemeID)
    }

    var colors: ThemeColors { current.colors }
    var fonts: ThemeFonts { current.fonts }
    var effects: ThemeEffects { current.effects }

    init() {
        if let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared"),
           let saved = defaults.string(forKey: "selectedThemeID") {
            self.selectedThemeID = saved
        } else {
            self.selectedThemeID = "clean"
        }
    }

    private func persist() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(selectedThemeID, forKey: defaultsKey)
    }
}
