import Foundation
import AuthenticationServices

@MainActor
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isSignedIn = false
    @Published var userName: String?
    @Published var userEmail: String?

    private let userIDKey = "com.shuttlx.appleUserID"
    private let userNameKey = "com.shuttlx.appleUserName"

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
                    UserDefaults.standard.set(name, forKey: userNameKey)
                }
            }

            if let email = credential.email {
                userEmail = email
            }

            isSignedIn = true

        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() {
        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: userNameKey)
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

        // 3. Sign out (clears keychain + UserDefaults)
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
        userName = UserDefaults.standard.string(forKey: userNameKey)
    }

    // MARK: - Keychain

    private func saveToKeychain(userID: String) {
        let data = Data(userID.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIDKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
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
            kSecAttrAccount as String: userIDKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
