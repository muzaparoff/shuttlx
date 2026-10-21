import Foundation
#if canImport(Security)
import Security
#endif

/// Where the optional medicine name and daily dose live. They are medication notes: phone only, never in the
/// App Group UserDefaults JSON (`HeartSafetySettings.save()` strips them), never synced.
public protocol SecretBackend: AnyObject {
    func read(_ key: String) -> String?
    /// nil deletes. Returns false when the value could not be stored.
    @discardableResult func write(_ key: String, _ value: String?) -> Bool
}

/// Keychain, this device only, readable after the first unlock (background wakes can still load settings).
public final class KeychainBackend: SecretBackend {
    private let service = "com.shuttlx.medication"
    public init() {}

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    public func read(_ key: String) -> String? {
        var q = query(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult public func write(_ key: String, _ value: String?) -> Bool {
        SecItemDelete(query(key) as CFDictionary)
        guard let value else { return true }
        guard let data = value.data(using: .utf8) else { return false }
        var q = query(key)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }
}

public enum MedicineVault {
    /// Tests swap in an in-memory backend.
    public nonisolated(unsafe) static var backend: SecretBackend = KeychainBackend()

    public static var name: String? {
        get { backend.read("name") }
        set { backend.write("name", newValue) }
    }
    public static var dose: String? {
        get { backend.read("dose") }
        set { backend.write("dose", newValue) }
    }

    /// Stores a value; true when it is readable back afterwards.
    @discardableResult static func store(_ key: String, _ value: String) -> Bool {
        backend.write(key, value) && backend.read(key) == value
    }

    /// Deletes the medicine name and dose (Delete Account / Clear All).
    public static func clear() {
        backend.write("name", nil)
        backend.write("dose", nil)
    }
}
