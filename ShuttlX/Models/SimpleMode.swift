import SwiftUI

/// Owner's "Simple mode" switch (per device, default OFF). Bigger tiles, fewer cards; it only hides, never deletes,
/// and heart-safety items are never hidden. Use in a view: `@AppStorage(SimpleMode.key, store: SimpleMode.store) private var simpleMode = false`.
enum SimpleMode {
    static let key = "simpleMode"
    static let store = UserDefaults(suiteName: "group.com.shuttlx.shared") ?? .standard
    static var isOn: Bool { store.bool(forKey: key) }
}
