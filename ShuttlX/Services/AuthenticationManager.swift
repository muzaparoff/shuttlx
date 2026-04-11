import Foundation
import AuthenticationServices
import os.log

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isSignedIn = false
    @Published var userName: String?
    @Published var userEmail: String?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "Authentication")
    private let userIDKey = "com.shuttlx.appleUserID"
    private let userNameKey = "com.shuttlx.appleUserName"

    // MARK: - Keychain Constants

    private let keychainService = "com.shuttlx.ShuttlX"
    private let userNameAccount = "shuttlx_user_name"

    private init() {
        loadStoredCredentials()
        verifyCredentialState()
        listenForRevocation()
    }

    // MARK: - Sign In

    func handleAuthorization(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

            let userID = credential.user
            saveToKeychain(userID: userID)

            if let fullName = credential.fullName {
                let name = PersonNameComponentsFormatter().string(from: fullName)
                if !name.isEmpty {
                    userName = name
                    saveNameToKeychain(name)
                }
            }

            if let email = credential.email {
                userEmail = email
            }

            isSignedIn = true

        case .failure(let error):
            logger.error("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        deleteFromKeychain()
        deleteNameFromKeychain()
        isSignedIn = false
        userName = nil
        userEmail = nil
    }

    // MARK: - Delete Account

    /// Deletes user account data: CloudKit records, local credentials, and local sessions.
    /// Required by Apple for Sign In with Apple compliance.
    func deleteAccount(dataManager: DataManager, sharedDataManager: SharedDataManager) async throws {
        // 1. Delete CloudKit data
        try await CloudKitSyncManager.shared.deleteAllUserData()

        // 2. Clear local sessions
        sharedDataManager.purgeAllSessionsFromStorage()
        dataManager.sessions = []

        // 3. Sign out (clears keychain + name keychain item)
        signOut()
    }

    // MARK: - Credential Verification

    func verifyCredentialState() {
        guard let userID = loadFromKeychain() else {
            isSignedIn = false
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            Task { @MainActor [weak self] in
                switch state {
                case .authorized:
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    private func listenForRevocation() {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.signOut()
            }
        }
    }

    // MARK: - Stored Credentials

    private func loadStoredCredentials() {
        if loadFromKeychain() != nil {
            isSignedIn = true
        }

        // Migrate display name from UserDefaults to Keychain (one-time)
        if let legacyName = UserDefaults.standard.string(forKey: userNameKey),
           loadNameFromKeychain() == nil {
            saveNameToKeychain(legacyName)
            UserDefaults.standard.removeObject(forKey: userNameKey)
            logger.info("Migrated display name from UserDefaults to Keychain")
        }

        userName = loadNameFromKeychain()
    }

    // MARK: - Keychain (User ID)

    private func saveToKeychain(userID: String) {
        let data = Data(userID.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save user ID to Keychain: \(status)")
        }
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userIDKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Keychain (Display Name)

    private func saveNameToKeychain(_ name: String) {
        guard let data = name.data(using: .utf8) else {
            logger.error("Failed to encode display name as UTF-8")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userNameAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userNameAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save display name to Keychain: \(status)")
        }
    }

    private func loadNameFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userNameAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteNameFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userNameAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
