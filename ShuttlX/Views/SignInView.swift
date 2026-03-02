import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                Image(systemName: "icloud.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 12) {
                    Text("Sync Your Data")
                        .font(.largeTitle.bold())

                    Text("Sign in with Apple to back up your workouts to iCloud. Your data syncs privately across all your devices.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Automatic Sync", subtitle: "Workouts sync across iPhone, iPad")
                    FeatureRow(icon: "lock.shield", title: "Private & Secure", subtitle: "Stored in your private iCloud")
                    FeatureRow(icon: "arrow.counterclockwise", title: "Backup & Restore", subtitle: "Never lose your training history")
                }
                .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authManager.handleAuthorization(result: result)
                        if authManager.isSignedIn {
                            dismiss()
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Text("Without signing in, your data is stored locally and could be lost if you reset or lose your device.")
                        .font(.caption)
                        .foregroundStyle(ShuttlXColor.ctaWarning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
