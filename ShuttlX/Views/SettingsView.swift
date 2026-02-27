import SwiftUI
import HealthKit
import WatchConnectivity

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var appSettings = AppSettings()
    @State private var showingHealthPermissionsInfo = false
    @State private var showingDeleteConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""

    var body: some View {
        List {
            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $appSettings.appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Label {
                            Text(option.rawValue)
                        } icon: {
                            Image(systemName: option.icon)
                        }
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Theme")
                .accessibilityValue(appSettings.appearance.rawValue)
                .accessibilityHint("Select light, dark, or system appearance")
            }

            // Watch Connection Section
            Section("Apple Watch") {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Watch Status")
                    Spacer()
                    Text(watchStatusText)
                        .foregroundStyle(watchPaired ? .green : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Watch Status")
                .accessibilityValue(watchStatusText)

                HStack {
                    Text("Connectivity")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(watchReachable ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(watchReachable ? "Reachable" : "Not Reachable")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Connectivity: \(watchReachable ? "Reachable" : "Not Reachable")")
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
                        .foregroundStyle(dataManager.healthKitAuthorized ? .green : .secondary)
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
        .preferredColorScheme(appSettings.appearance.colorScheme)
    }

    // MARK: - Watch Helpers

    private var watchPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    private var watchReachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    private var watchStatusText: String {
        guard WCSession.isSupported() else { return "Not Supported" }
        if WCSession.default.isPaired && WCSession.default.isWatchAppInstalled {
            return "Connected"
        } else if WCSession.default.isPaired {
            return "Paired (App Not Installed)"
        } else {
            return "Not Paired"
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
                .foregroundStyle(.green)
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
            .environmentObject(DataManager())
    }
}
