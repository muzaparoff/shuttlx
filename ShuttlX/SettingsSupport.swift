import SwiftUI
import HealthKit

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
        static let syncIntervalSeconds = "syncIntervalSeconds"
    }
    
    /// Published properties for UI binding
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }
    
    @Published var syncIntervalSeconds: Int {
        didSet {
            UserDefaults.standard.set(syncIntervalSeconds, forKey: Keys.syncIntervalSeconds)
        }
    }
    
    /// Available sync interval options
    let syncIntervalOptions = [3, 5, 10, 30, 60]
    
    init() {
        // Load appearance setting from UserDefaults or use system default
        let appearanceString = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: appearanceString) ?? .system
        
        // Load sync interval settings from UserDefaults or use defaults
        self.syncIntervalSeconds = UserDefaults.standard.integer(forKey: Keys.syncIntervalSeconds)
        if self.syncIntervalSeconds == 0 {
            self.syncIntervalSeconds = 3 // Default to 3 seconds if not set
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var appSettings: AppSettings
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
            }
            
            // Health Integration Section
            Section(header: Text("Health Integration")) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("HealthKit Status")
                    Spacer()
                    Text(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")
                        .foregroundColor(dataManager.healthKitAuthorized ? .green : .red)
                }
                
                if !dataManager.healthKitAuthorized {
                    Button("Request HealthKit Access") {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                        }
                    }
                }
                
                Button("Why We Need Access") {
                    showingHealthPermissionsInfo = true
                }
                
                // Sync Interval Setting
                Picker("Sync Interval", selection: $appSettings.syncIntervalSeconds) {
                    ForEach(appSettings.syncIntervalOptions, id: \.self) { seconds in
                        Text(seconds == 1 ? "1 second" : "\(seconds) seconds")
                    }
                }
            }
            
            // Sync Section
            Section(header: Text("Sync")) {
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(formatLastSyncTime())
                        .foregroundColor(.secondary)
                }
                
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
            }
            
            // Data Management Section
            Section(header: Text("Data Management")) {
                Button("Clear All Training Sessions", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
            
            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
                }
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
            : nil
        )
        .animation(.easeInOut, value: showSuccessMessage)
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

// Toast message view
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
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
        )
    }
}

// Health Permissions Info View
struct HealthPermissionsInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why ShuttlX Needs HealthKit Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Read")
                            .font(.headline)
                        
                        Text("• Heart Rate: To monitor your exertion during workouts")
                        Text("• Steps & Distance: To track your activity accurately")
                        Text("• Calories: To measure energy expenditure")
                    }
                    .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Store")
                            .font(.headline)
                        
                        Text("• Workout Sessions: To maintain your training history")
                        Text("• Active Energy: To track calories burned during activities")
                        Text("• Distance: To record your training progress")
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