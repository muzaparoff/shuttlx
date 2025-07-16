import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        TabView {
            ProgramListView()
                .tabItem {
                    Label("Programs", systemImage: "list.bullet")
                }
            
            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
            
            NavigationView {
                SimpleSettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

// Simple Settings View to resolve build issues
struct SimpleSettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingHealthPermissionsInfo = false
    @State private var showingDeleteConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @AppStorage("appearance") private var appearance: String = "System"
    @AppStorage("syncIntervalSeconds") private var syncIntervalSeconds: Int = 3
    
    private let appearanceOptions = ["System", "Light", "Dark"]
    private let syncIntervalOptions = [3, 5, 10, 30, 60]
    
    var body: some View {
        List {
            // Appearance Section
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $appearance) {
                    ForEach(appearanceOptions, id: \.self) { option in
                        HStack {
                            Image(systemName: iconForAppearance(option))
                            Text(option)
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
                Picker("Sync Interval", selection: $syncIntervalSeconds) {
                    ForEach(syncIntervalOptions, id: \.self) { seconds in
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
                        UserDefaults.standard.set(Date(), forKey: "lastSyncTime")
                        successMessage = "Sync completed!"
                        showSuccessMessage = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSuccessMessage = false
                        }
                    }
                }
            }
            
            // Data Management Section
            Section(header: Text("Data Management")) {
                Button("Clear All Training Sessions") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
            
            // App Information Section
            Section(header: Text("App Information")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .overlay(
            // Success message overlay
            Group {
                if showSuccessMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
                }
            }
        )
        .alert("HealthKit Permissions", isPresented: $showingHealthPermissionsInfo) {
            Button("OK") { }
        } message: {
            Text("We use HealthKit to track your heart rate and calories during workouts. This helps provide accurate training data and sync with the Health app.")
        }
        .alert("Clear All Sessions", isPresented: $showingDeleteConfirmation) {
            Button("Clear All", role: .destructive) {
                SharedDataManager.shared.purgeAllSessionsFromStorage()
                dataManager.sessions = []
                successMessage = "All sessions cleared!"
                showSuccessMessage = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all training session data. This action cannot be undone.")
        }
        .preferredColorScheme(colorSchemeForAppearance(appearance))
    }
    
    private func iconForAppearance(_ appearance: String) -> String {
        switch appearance {
        case "Light": return "sun.max.fill"
        case "Dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }
    
    private func colorSchemeForAppearance(_ appearance: String) -> ColorScheme? {
        switch appearance {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    private func formatLastSyncTime() -> String {
        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        }
        return "Never"
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
