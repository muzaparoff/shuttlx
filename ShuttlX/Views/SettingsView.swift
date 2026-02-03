import SwiftUI
import HealthKit

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
            Section(header: Text("Appearance")) {
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

            // Health Integration Section
            Section(header: Text("Health Integration")) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    Text("HealthKit Status")
                    Spacer()
                    Text(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")
                        .foregroundColor(dataManager.healthKitAuthorized ? .green : .red)
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

                // Sync Interval Setting
                Picker("Sync Interval", selection: $appSettings.syncIntervalSeconds) {
                    ForEach(appSettings.syncIntervalOptions, id: \.self) { seconds in
                        Text(seconds == 1 ? "1 second" : "\(seconds) seconds")
                    }
                }
                .accessibilityLabel("Sync Interval")
                .accessibilityValue("\(appSettings.syncIntervalSeconds) seconds")
                .accessibilityHint("Choose how often data syncs with Apple Watch")
            }

            // Sync Section
            Section(header: Text("Sync")) {
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(formatLastSyncTime())
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last Synced")
                .accessibilityValue(formatLastSyncTime())

                Button("Force Sync with Watch") {
                    if let programs = dataManager.programs as? [TrainingProgram] {
                        SharedDataManager.shared.syncProgramsToWatch(programs)
                        // Update last sync time
                        UserDefaults.standard.set(Date(), forKey: "lastSyncTime")
                        // Show success message
                        successMessage = "Sync completed!"
                        showSuccessMessage = true

                        // Hide message after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessMessage = false
                        }
                    }
                }
                .accessibilityHint("Manually sends all programs to Apple Watch")

                Button("Show Debug View") {
                    // Implementation for debug view
                }
                .accessibilityHint("Opens the debug information view")
            }

            // Data Management Section
            Section(header: Text("Data Management")) {
                Button("Clear All Training Sessions", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
                .accessibilityHint("Permanently deletes all training session data")
            }

            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("App Version")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Build Number")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .sheet(isPresented: $showingHealthPermissionsInfo) {
            HealthPermissionsInfoView()
        }
        .alert("Clear All Training Sessions", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                SharedDataManager.shared.purgeAllSessionsFromStorage()
                // Show success message
                successMessage = "All sessions cleared!"
                showSuccessMessage = true

                // Hide message after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                }
            }
        } message: {
            Text("This will delete all your training history. This action cannot be undone.")
        }
        .overlay(
            showSuccessMessage ?
            ToastView(message: successMessage, systemImage: "checkmark.circle.fill")
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 60)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(successMessage)
            : nil
        )
        .animation(.easeInOut, value: showSuccessMessage)
        .preferredColorScheme(appSettings.appearance.colorScheme)
    }

    private func formatLastSyncTime() -> String {
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date ?? Date.distantPast

        if lastSync == Date.distantPast {
            return "Never"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        }
    }
}

// Add Toast message view
struct ToastView: View {
    var message: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.green)
            Text(message)
                .font(.callout)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.primary.opacity(0.2), radius: 3, x: 0, y: 2)
        )
    }
}

// Keep the existing HealthPermissionsInfoView
struct HealthPermissionsInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why ShuttlX Needs HealthKit Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
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
                        .padding(.bottom)
                }
                .padding()
            }
            .navigationBarTitle("Health Permissions", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                // Dismiss sheet
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(DataManager())
        }
    }
}
