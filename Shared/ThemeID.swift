import Foundation

/// Single source of truth for which theme ids exist. Saved or synced ids that
/// are not listed here (e.g. the retired "mixtape") resolve to the default.
public enum ThemeID {
    public static let valid: Set<String> = ["clean"]
    public static let fallback = "clean"

    public static func resolve(_ id: String?) -> String {
        guard let id, valid.contains(id) else { return fallback }
        return id
    }
}
