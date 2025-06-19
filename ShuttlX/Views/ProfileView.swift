//
//  ProfileView.swift
//  ShuttlX MVP
//
//  Created by ShuttlX on 6/8/25.
//

import SwiftUI
import HealthKit

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var serviceLocator: ServiceLocator
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingHealthPermissions = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Health Stats Cards
                    healthStatsSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Settings Section
                    settingsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .refreshable {
                await refreshProfileData()
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHealthPermissions) {
            SettingsView()
        }
        .onAppear {
            viewModel.loadProfileData()
            Task {
                await refreshProfileData()
            }
        }
    }
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Picture and Basic Info
            HStack(spacing: 16) {
                Button(action: { showingEditProfile = true }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.userName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Fitness Enthusiast")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Stats
                    HStack(spacing: 20) {
                        StatView(
                            title: "Workouts",
                            value: "\(viewModel.totalWorkouts)"
                        )
                        
                        StatView(
                            title: "This Week",
                            value: "\(viewModel.weeklyWorkouts)"
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private var healthStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                HealthStatCard(
                    title: "Avg Heart Rate",
                    value: "\(Int(viewModel.averageHeartRate))",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
                
                HealthStatCard(
                    title: "Calories Burned",
                    value: "\(Int(viewModel.totalCalories))",
                    unit: "cal",
                    icon: "flame.fill",
                    color: .orange
                )
                
                HealthStatCard(
                    title: "Total Distance",
                    value: String(format: "%.1f", viewModel.totalDistance),
                    unit: "km",
                    icon: "figure.run",
                    color: .blue
                )
                
                HealthStatCard(
                    title: "Active Time",
                    value: formatDuration(viewModel.totalActiveTime),
                    unit: "",
                    icon: "clock.fill",
                    color: .green
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                QuickActionRow(
                    icon: "heart.text.square",
                    title: "Health Permissions",
                    subtitle: serviceLocator.healthManager.hasHealthKitPermission ? "Authorized" : "Not Authorized"
                ) {
                    showingHealthPermissions = true
                }
                
                QuickActionRow(
                    icon: "chart.bar.fill",
                    title: "Export Health Data",
                    subtitle: "Export your workout data"
                ) {
                    exportHealthData()
                }
                
                QuickActionRow(
                    icon: "applewatch",
                    title: "Watch Settings",
                    subtitle: "Configure Apple Watch connection"
                ) {
                    // Navigate to watch settings
                }
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                QuickActionRow(
                    icon: "gearshape.fill",
                    title: "App Settings",
                    subtitle: "Notifications, privacy, and more"
                ) {
                    showingSettings = true
                }
                
                QuickActionRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help using ShuttlX"
                ) {
                    // Show help
                }
                
                QuickActionRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "Version 1.0.0"
                ) {
                    // Show about
                }
            }
        }
    }
    
    private func refreshProfileData() async {
        viewModel.loadProfileData()
        serviceLocator.healthManager.requestHealthKitPermissions()
    }
    
    private func exportHealthData() {
        // Implementation for exporting health data
        print("Exporting health data...")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sheet Views

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = "John Doe"
    @State private var bio = "Fitness enthusiast who loves running and cycling"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save profile changes
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
        .environmentObject(ServiceLocator.shared)
}
