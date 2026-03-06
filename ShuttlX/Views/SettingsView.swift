import SwiftUI
import HealthKit
import WatchConnectivity

struct SettingsView: View {
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var sharedDataManager: SharedDataManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingHealthPermissionsInfo = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var isSyncing = false
    @State private var isCloudSyncing = false

    var body: some View {
        List {
            // Account Section
            Section("Account") {
                if authManager.isSignedIn {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authManager.userName ?? "Signed In")
                                .font(.body)
                            Text("iCloud sync enabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundStyle(ShuttlXColor.positive)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Account")
                    .accessibilityValue("Signed in as \(authManager.userName ?? "Apple ID")")

                    Button {
                        isCloudSyncing = true
                        CloudKitSyncManager.shared.performFullSync(dataManager: dataManager) {
                            isCloudSyncing = false
                            successMessage = "Sync complete"
                            showSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSuccessMessage = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                            Spacer()
                            if isCloudSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isCloudSyncing)

                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                } else {
                    NavigationLink {
                        SignInView()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.tint)
                            Text("Sign In with Apple")
                        }
                    }

                    Label("Data is stored locally only", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(ShuttlXColor.ctaWarning)
                }
            }

            // Watch Connection Section
            Section("Apple Watch") {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Watch Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(watchPaired ? ShuttlXColor.positive : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(watchStatusText)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Watch Status")
                .accessibilityValue(watchStatusText)

                if watchPaired {
                    Button {
                        isSyncing = true
                        sharedDataManager.requestSessionsFromWatch { count in
                            isSyncing = false
                            if count > 0 {
                                dataManager.loadSessionsFromAppGroup()
                                successMessage = "Synced \(count) session\(count == 1 ? "" : "s") from Watch"
                            } else {
                                successMessage = "No new sessions found. Keep both apps open and retry."
                            }
                            showSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                showSuccessMessage = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync from Watch")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                    .accessibilityHint("Pulls training sessions directly from your Apple Watch")
                }
            }

            // Health Integration Section
            Section("Health Integration") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(ShuttlXColor.heartRate)
                        .accessibilityHidden(true)
                    Text("HealthKit Status")
                    Spacer()
                    Text(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")
                        .foregroundStyle(dataManager.healthKitAuthorized ? ShuttlXColor.positive : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("HealthKit Status")
                .accessibilityValue(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")

                if !dataManager.healthKitAuthorized {
                    Button("Request HealthKit Access") {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                        }
                    }
                    .accessibilityHint("Opens the HealthKit permission dialog")
                }

                Button("Why We Need Access") {
                    showingHealthPermissionsInfo = true
                }
                .accessibilityHint("Shows information about how health data is used")
            }

            // Appearance Section
            Section("Appearance") {
                ForEach(AppTheme.all) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.selectTheme(theme.id)
                        }
                        sharedDataManager.sendThemeToWatch(theme.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: theme.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(theme.colors.ctaPrimary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.displayName)
                                    .font(.body)
                                    .foregroundStyle(Color(.label))
                                Text(themeSubtitle(for: theme.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if themeManager.selectedThemeID == theme.id {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(ShuttlXColor.ctaPrimary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(theme.displayName) theme")
                    .accessibilityValue(themeManager.selectedThemeID == theme.id ? "Selected" : "")
                    .accessibilityHint("Switches to \(theme.displayName) theme")
                }

                // Preview swatch
                HStack(spacing: 6) {
                    let preview = themeManager.current.colors
                    Circle().fill(preview.running).frame(width: 16, height: 16)
                    Circle().fill(preview.heartRate).frame(width: 16, height: 16)
                    Circle().fill(preview.steps).frame(width: 16, height: 16)
                    Circle().fill(preview.ctaPrimary).frame(width: 16, height: 16)
                    Circle().fill(preview.pace).frame(width: 16, height: 16)
                    Spacer()
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Theme color preview")
            }

            // Data Management Section
            Section("Data Management") {
                Button("Clear All Training Sessions", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .foregroundStyle(ShuttlXColor.ctaDestructive)
                .accessibilityHint("Permanently deletes all training session data")
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("App Version")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Build Number")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingHealthPermissionsInfo) {
            HealthPermissionsInfoView()
        }
        .alert("Clear All Training Sessions", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                SharedDataManager.shared.purgeAllSessionsFromStorage()
                dataManager.sessions = []
                successMessage = "All sessions cleared!"
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                }
            }
        } message: {
            Text("This will delete all your training history. This action cannot be undone.")
        }
        .overlay(alignment: .top) {
            if showSuccessMessage {
                ToastView(message: successMessage, systemImage: "checkmark.circle.fill")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .accessibilityLabel(successMessage)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuccessMessage)
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Your local data will be kept, but it will no longer sync to iCloud.")
        }
        .themedScreenBackground()
    }

    // MARK: - Watch Helpers

    private var watchPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    private var watchStatusText: String {
        guard WCSession.isSupported() else { return "Not Supported" }
        return WCSession.default.isPaired ? "Paired" : "Not Paired"
    }

    private func themeSubtitle(for id: String) -> String {
        switch id {
        case "clean": return "Modern & minimal"
        case "synthwave": return "Neon nights"
        case "mixtape": return "Portable player"
        case "arcade": return "8-bit energy"
        case "classicradio": return "Warm analog tape"
        case "vumeter": return "Hi-fi dashboard"
        default: return ""
        }
    }
}

// Toast message view
struct ToastView: View {
    var message: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ShuttlXColor.positive)
            Text(message)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// HealthPermissionsInfoView
struct HealthPermissionsInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why ShuttlX Needs HealthKit Access")
                        .font(.largeTitle.bold())
                        .padding(.bottom)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Read")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text("Heart Rate: To monitor your exertion during workouts")
                        Text("Steps & Distance: To track your activity accurately")
                        Text("Calories: To measure energy expenditure")
                    }
                    .padding(.bottom)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Store")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text("Workout Sessions: To maintain your training history")
                        Text("Active Energy: To track calories burned during activities")
                        Text("Distance: To record your training progress")
                    }
                    .padding(.bottom)

                    Text("Your health data remains private and is only used within the app to enhance your training experience. We never share your health information with third parties.")
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Health Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(ThemeManager.shared)
            .environmentObject(DataManager())
            .environmentObject(SharedDataManager.shared)
            .environmentObject(AuthenticationManager.shared)
    }
}
