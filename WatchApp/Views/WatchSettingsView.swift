import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("autoLock") private var autoLock = true
    @AppStorage("voiceCoaching") private var voiceCoaching = true
    @AppStorage("heartRateAlerts") private var heartRateAlerts = true
    @AppStorage("distanceUnit") private var distanceUnit = "km"
    @AppStorage("workoutReminders") private var workoutReminders = true
    
    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 8) {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .cornerRadius(10)
                    
                    Text("ShuttlX")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Connection status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectivity.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(connectivity.isConnected ? "Connected to iPhone" : "Disconnected")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            // Workout Settings
            Section("Workout") {
                // Haptic feedback
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Haptic Feedback")
                    
                    Spacer()
                    
                    Toggle("", isOn: $hapticFeedback)
                        .labelsHidden()
                }
                
                // Auto screen lock
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    Text("Prevent Auto-Lock")
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoLock)
                        .labelsHidden()
                }
                
                // Voice coaching
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    Text("Voice Coaching")
                    
                    Spacer()
                    
                    Toggle("", isOn: $voiceCoaching)
                        .labelsHidden()
                }
                
                // Heart rate alerts
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text("Heart Rate Alerts")
                    
                    Spacer()
                    
                    Toggle("", isOn: $heartRateAlerts)
                        .labelsHidden()
                }
            }
            
            // Display Settings
            Section("Display") {
                // Distance unit
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    
                    Text("Distance Unit")
                    
                    Spacer()
                    
                    Picker("Distance Unit", selection: $distanceUnit) {
                        Text("Kilometers").tag("km")
                        Text("Miles").tag("mi")
                        Text("Meters").tag("m")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Workout reminders
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.yellow)
                        .frame(width: 20)
                    
                    Text("Workout Reminders")
                    
                    Spacer()
                    
                    Toggle("", isOn: $workoutReminders)
                        .labelsHidden()
                }
            }
            
            // Health Settings
            Section("Health") {
                NavigationLink(destination: HealthPermissionsView()) {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        
                        Text("Health Permissions")
                    }
                }
                
                NavigationLink(destination: DataSyncView()) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text("Data Sync")
                    }
                }
            }
            
            // About
            Section("About") {
                NavigationLink(destination: AboutView()) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text("About ShuttlX")
                    }
                }
                
                Button(action: {
                    // Open support/feedback
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        
                        Text("Support & Feedback")
                            .foregroundColor(.primary)
                    }
                }
                
                Button(action: {
                    resetAllSettings()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        
                        Text("Reset Settings")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func resetAllSettings() {
        hapticFeedback = true
        autoLock = true
        voiceCoaching = true
        heartRateAlerts = true
        distanceUnit = "km"
        workoutReminders = true
        
        // Show confirmation
        WKInterfaceDevice.current().play(.success)
    }
}

struct HealthPermissionsView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var permissions: [HealthPermission] = []
    
    struct HealthPermission {
        let name: String
        let icon: String
        let status: PermissionStatus
        let description: String
    }
    
    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        
        var color: Color {
            switch self {
            case .granted: return .green
            case .denied: return .red
            case .notDetermined: return .yellow
            }
        }
        
        var text: String {
            switch self {
            case .granted: return "Granted"
            case .denied: return "Denied"
            case .notDetermined: return "Not Set"
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                Text("ShuttlX needs access to your health data to track workouts and provide personalized insights.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Health Data Permissions") {
                ForEach(permissions.indices, id: \.self) { index in
                    let permission = permissions[index]
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: permission.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(permission.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(permission.status.text)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(permission.status.color.opacity(0.2))
                                .foregroundColor(permission.status.color)
                                .cornerRadius(8)
                        }
                        
                        Text(permission.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: {
                    workoutManager.requestAuthorization()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Permissions")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Health Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPermissions()
        }
    }
    
    private func loadPermissions() {
        permissions = [
            HealthPermission(
                name: "Heart Rate",
                icon: "heart",
                status: .granted,
                description: "Monitor heart rate during workouts"
            ),
            HealthPermission(
                name: "Active Energy",
                icon: "flame",
                status: .granted,
                description: "Track calories burned during exercise"
            ),
            HealthPermission(
                name: "Distance",
                icon: "location",
                status: .granted,
                description: "Measure distance covered in workouts"
            ),
            HealthPermission(
                name: "Workouts",
                icon: "figure.run",
                status: .granted,
                description: "Save workout sessions to Health app"
            )
        ]
    }
}

struct DataSyncView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var lastSyncDate = Date()
    @State private var autoSync = true
    @State private var syncInProgress = false
    
    var body: some View {
        List {
            Section {
                Text("Keep your workout data synchronized between your iPhone and Apple Watch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Sync Status") {
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Sync")
                            .font(.subheadline)
                        
                        Text(lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if syncInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Auto Sync")
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoSync)
                        .labelsHidden()
                }
            }
            
            Section("Actions") {
                Button(action: {
                    syncNow()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        
                        Text("Sync Now")
                            .foregroundColor(.primary)
                    }
                }
                .disabled(syncInProgress || !connectivity.isConnected)
                
                Button(action: {
                    // Export data
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.green)
                        
                        Text("Export Data")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("Data Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func syncNow() {
        syncInProgress = true
        
        // Simulate sync process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            syncInProgress = false
            lastSyncDate = Date()
            WKInterfaceDevice.current().play(.success)
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                    
                    Text("ShuttlX")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("The ultimate shuttle run and interval training companion for Apple Watch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            Section("Features") {
                FeatureRow(icon: "timer", title: "Interval Training", description: "Customizable workout intervals")
                FeatureRow(icon: "heart", title: "Health Integration", description: "Full HealthKit compatibility")
                FeatureRow(icon: "iphone", title: "iPhone Sync", description: "Seamless data synchronization")
                FeatureRow(icon: "speaker.wave.2", title: "Audio Coaching", description: "Real-time voice guidance")
            }
            
            Section("Legal") {
                Button("Privacy Policy") {
                    // Open privacy policy
                }
                
                Button("Terms of Service") {
                    // Open terms
                }
                
                Button("Licenses") {
                    // Show open source licenses
                }
            }
            
            Section {
                Text("© 2024 ShuttlX. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        WatchSettingsView()
            .environmentObject(WatchWorkoutManager())
            .environmentObject(WatchConnectivityManager())
    }
}
