import SwiftUI

// MARK: - App Settings Model

/// Model for app appearance settings
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { self.rawValue }

    /// Convert to ColorScheme or nil for system default
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

/// Model for managing app settings
class AppSettings: ObservableObject {
    /// Keys for UserDefaults
    private enum Keys {
        static let appearance = "appearance"
    }

    /// Published properties for UI binding
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    init() {
        // Load appearance setting from UserDefaults or use system default
        let appearanceString = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: appearanceString) ?? .system
    }
}

// SettingsView, ToastView, and HealthPermissionsInfoView are defined in Views/SettingsView.swift
