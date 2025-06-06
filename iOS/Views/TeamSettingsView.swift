//
//  TeamSettingsView.swift
//  ShuttlX
//
//  Comprehensive team configuration and management interface
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import PhotosUI

struct TeamSettingsView: View {
    let team: Team
    @StateObject private var viewModel = TeamSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case privacy = "Privacy"
        case roles = "Roles"
        case notifications = "Notifications"
        case advanced = "Advanced"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                settingsTabSelector
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    generalSettingsTab
                        .tag(SettingsTab.general)
                    
                    privacySettingsTab
                        .tag(SettingsTab.privacy)
                    
                    rolesSettingsTab
                        .tag(SettingsTab.roles)
                    
                    notificationSettingsTab
                        .tag(SettingsTab.notifications)
                    
                    advancedSettingsTab
                        .tag(SettingsTab.advanced)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Team Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.hasChanges)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                viewModel.loadTeamSettings(team)
            }
        }
    }
    
    // MARK: - Tab Selector
    private var settingsTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.rawValue) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .medium)
                                .foregroundColor(selectedTab == tab ? .orange : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? Color.orange : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - General Settings Tab
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Team Avatar Section
                teamAvatarSection
                
                // Basic Info Section
                basicInfoSection
                
                // Team Description Section
                descriptionSection
                
                // Team Category Section
                categorySection
            }
            .padding()
        }
    }
    
    private var teamAvatarSection: some View {
        VStack(spacing: 16) {
            Text("Team Avatar")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                // Current Avatar
                ZStack {
                    if let imageURL = viewModel.teamImageURL {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.orange.gradient)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.orange.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: viewModel.teamIconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { viewModel.showingImagePicker = true }) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    }
                    .frame(width: 80, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upload a team photo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Choose an image that represents your team's spirit and goals.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Choose Photo") {
                        viewModel.showingImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .photosPicker(
            isPresented: $viewModel.showingImagePicker,
            selection: $viewModel.selectedImage,
            matching: .images
        )
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Team Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Team Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter team name", text: $viewModel.teamName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Team Location
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("City, Country", text: $viewModel.teamLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Team Website
                VStack(alignment: .leading, spacing: 4) {
                    Text("Website (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("https://example.com", text: $viewModel.teamWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text("Team Description")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe your team's mission, goals, and what makes it special.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $viewModel.teamDescription)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var categorySection: some View {
        VStack(spacing: 16) {
            Text("Team Category")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(TeamCategory.allCases, id: \.self) { category in
                    Button(action: { viewModel.selectedCategory = category }) {
                        VStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.title2)
                                .foregroundColor(viewModel.selectedCategory == category ? .white : category.color)
                            
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.selectedCategory == category ? category.color.gradient : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(category.color, lineWidth: viewModel.selectedCategory == category ? 0 : 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Privacy Settings Tab
    private var privacySettingsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Team Visibility
                teamVisibilitySection
                
                // Membership Settings
                membershipSection
                
                // Content Settings
                contentSettings
            }
            .padding()
        }
    }
    
    private var teamVisibilitySection: some View {
        VStack(spacing: 16) {
            Text("Team Visibility")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("Public Team", isOn: $viewModel.isPublic)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Text(viewModel.isPublic ? 
                     "Anyone can find and view your team. Members can be seen by everyone." :
                     "Only invited members can find and view your team.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if viewModel.isPublic {
                    Toggle("Searchable", isOn: $viewModel.isSearchable)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    
                    Text("Allow your team to appear in search results and discovery.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var membershipSection: some View {
        VStack(spacing: 16) {
            Text("Membership")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("Require Approval", isOn: $viewModel.requiresApproval)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Text(viewModel.requiresApproval ? 
                     "New members must be approved by admins before joining." :
                     "Anyone can join immediately if the team is public.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Max Members
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum Members")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("No limit", value: $viewModel.maxMembers, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Button("No Limit") {
                            viewModel.maxMembers = nil
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var contentSettings: some View {
        VStack(spacing: 16) {
            Text("Content & Activity")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("Allow Workout Sharing", isOn: $viewModel.allowWorkoutSharing)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Allow Challenge Creation", isOn: $viewModel.allowChallengeCreation)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Allow Event Creation", isOn: $viewModel.allowEventCreation)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("External Sharing", isOn: $viewModel.allowExternalSharing)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Text("Allow members to share team content outside the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Roles Settings Tab
    private var rolesSettingsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Role Permissions
                rolePermissionsSection
                
                // Default Role
                defaultRoleSection
            }
            .padding()
        }
    }
    
    private var rolePermissionsSection: some View {
        VStack(spacing: 16) {
            Text("Role Permissions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                ForEach(TeamRole.allCases.filter { $0 != .owner }, id: \.self) { role in
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: role.iconName)
                                .foregroundColor(role.color)
                            
                            Text(role.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        VStack(spacing: 8) {
                            PermissionToggle(
                                title: "Invite Members",
                                isEnabled: binding(for: role, permission: \.canInvite)
                            )
                            
                            PermissionToggle(
                                title: "Remove Members",
                                isEnabled: binding(for: role, permission: \.canKick)
                            )
                            
                            PermissionToggle(
                                title: "Edit Team Info",
                                isEnabled: binding(for: role, permission: \.canEdit)
                            )
                            
                            if role == .admin {
                                PermissionToggle(
                                    title: "Delete Team",
                                    isEnabled: binding(for: role, permission: \.canDelete)
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var defaultRoleSection: some View {
        VStack(spacing: 16) {
            Text("Default New Member Role")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Picker("Default Role", selection: $viewModel.defaultNewMemberRole) {
                ForEach([TeamRole.member, TeamRole.moderator], id: \.self) { role in
                    Text(role.displayName).tag(role)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text("New members will automatically receive this role when they join.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Notifications Settings Tab
    private var notificationSettingsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Team Notifications
                teamNotificationsSection
                
                // Member Activity
                memberActivitySection
                
                // Challenge Notifications
                challengeNotificationsSection
            }
            .padding()
        }
    }
    
    private var teamNotificationsSection: some View {
        VStack(spacing: 16) {
            Text("Team Notifications")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("New Members", isOn: $viewModel.notifyNewMembers)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Member Departures", isOn: $viewModel.notifyMemberDepartures)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Role Changes", isOn: $viewModel.notifyRoleChanges)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Team Achievements", isOn: $viewModel.notifyTeamAchievements)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var memberActivitySection: some View {
        VStack(spacing: 16) {
            Text("Member Activity")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("Workout Sharing", isOn: $viewModel.notifyWorkoutSharing)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Goal Achievements", isOn: $viewModel.notifyGoalAchievements)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Milestones", isOn: $viewModel.notifyMilestones)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var challengeNotificationsSection: some View {
        VStack(spacing: 16) {
            Text("Challenge Notifications")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Toggle("New Challenges", isOn: $viewModel.notifyNewChallenges)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Challenge Completions", isOn: $viewModel.notifyChallengeCompletions)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                Toggle("Leaderboard Updates", isOn: $viewModel.notifyLeaderboardUpdates)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Advanced Settings Tab
    private var advancedSettingsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Data Export
                dataExportSection
                
                // Danger Zone
                dangerZoneSection
            }
            .padding()
        }
    }
    
    private var dataExportSection: some View {
        VStack(spacing: 16) {
            Text("Data Export")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Button("Export Team Data") {
                    viewModel.exportTeamData()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .frame(maxWidth: .infinity)
                
                Text("Download a copy of your team's data including member lists, activities, and statistics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            Text("Danger Zone")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                Button("Transfer Ownership") {
                    viewModel.showingTransferOwnership = true
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .frame(maxWidth: .infinity)
                
                Button("Delete Team") {
                    viewModel.showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity)
                
                Text("These actions cannot be undone. Please be certain before proceeding.")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Helper Methods
    private func binding(for role: TeamRole, permission: KeyPath<TeamPermissions, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.rolePermissions[role]?[keyPath: permission] ?? false },
            set: { newValue in
                if viewModel.rolePermissions[role] == nil {
                    viewModel.rolePermissions[role] = TeamPermissions(canInvite: false, canKick: false, canEdit: false, canDelete: false)
                }
                // Create a new permissions object with the updated value
                let currentPermissions = viewModel.rolePermissions[role]!
                let newPermissions = TeamPermissions(
                    canInvite: permission == \TeamPermissions.canInvite ? newValue : currentPermissions.canInvite,
                    canKick: permission == \TeamPermissions.canKick ? newValue : currentPermissions.canKick,
                    canEdit: permission == \TeamPermissions.canEdit ? newValue : currentPermissions.canEdit,
                    canDelete: permission == \TeamPermissions.canDelete ? newValue : currentPermissions.canDelete
                )
                viewModel.rolePermissions[role] = newPermissions
            }
        )
    }
    
    private func saveSettings() {
        Task {
            await viewModel.saveSettings()
            dismiss()
        }
    }
}

// MARK: - Permission Toggle

struct PermissionToggle: View {
    let title: String
    let isEnabled: Binding<Bool>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Toggle("", isOn: isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .orange))
        }
    }
}

// MARK: - Team Settings ViewModel

@MainActor
class TeamSettingsViewModel: ObservableObject {
    // Team basic info
    @Published var teamName: String = ""
    @Published var teamDescription: String = ""
    @Published var teamLocation: String = ""
    @Published var teamWebsite: String = ""
    @Published var teamImageURL: String? = nil
    @Published var teamIconName: String = "person.3.fill"
    
    // Privacy settings
    @Published var isPublic: Bool = true
    @Published var isSearchable: Bool = true
    @Published var requiresApproval: Bool = false
    @Published var maxMembers: Int? = nil
    
    // Content settings
    @Published var allowWorkoutSharing: Bool = true
    @Published var allowChallengeCreation: Bool = true
    @Published var allowEventCreation: Bool = true
    @Published var allowExternalSharing: Bool = true
    
    // Role settings
    @Published var defaultNewMemberRole: TeamRole = .member
    @Published var rolePermissions: [TeamRole: TeamPermissions] = [:]
    
    // Notification settings
    @Published var notifyNewMembers: Bool = true
    @Published var notifyMemberDepartures: Bool = true
    @Published var notifyRoleChanges: Bool = true
    @Published var notifyTeamAchievements: Bool = true
    @Published var notifyWorkoutSharing: Bool = true
    @Published var notifyGoalAchievements: Bool = true
    @Published var notifyMilestones: Bool = true
    @Published var notifyNewChallenges: Bool = true
    @Published var notifyChallengeCompletions: Bool = true
    @Published var notifyLeaderboardUpdates: Bool = false
    
    // UI state
    @Published var selectedCategory: TeamCategory = .fitness
    @Published var showingImagePicker: Bool = false
    @Published var selectedImage: PhotosPickerItem? = nil
    @Published var showingTransferOwnership: Bool = false
    @Published var showingDeleteConfirmation: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasChanges: Bool = false
    
    private let socialService: SocialService
    private var originalTeam: Team?
    
    init(socialService: SocialService) {
        self.socialService = socialService
    }
    
    func loadTeamSettings(_ team: Team) {
        originalTeam = team
        
        teamName = team.name
        teamDescription = team.description
        teamImageURL = team.imageURL
        teamIconName = team.iconName
        isPublic = team.isPublic
        requiresApproval = team.requiresApproval
        maxMembers = team.maxMembers
        
        // Initialize role permissions
        initializeRolePermissions()
        
        // Monitor changes
        setupChangeDetection()
    }
    
    private func initializeRolePermissions() {
        rolePermissions = [
            .member: TeamPermissions(canInvite: false, canKick: false, canEdit: false, canDelete: false),
            .moderator: TeamPermissions(canInvite: true, canKick: true, canEdit: false, canDelete: false),
            .admin: TeamPermissions(canInvite: true, canKick: true, canEdit: true, canDelete: false)
        ]
    }
    
    private func setupChangeDetection() {
        // This would monitor all @Published properties for changes
        // and set hasChanges accordingly
    }
    
    func saveSettings() async {
        guard let originalTeam = originalTeam else { return }
        
        do {
            let updatedTeam = Team(
                id: originalTeam.id,
                creatorId: originalTeam.creatorId,
                name: teamName,
                description: teamDescription,
                iconName: teamIconName,
                bannerImageURL: teamImageURL,
                createdDate: originalTeam.createdDate,
                memberCount: originalTeam.memberCount,
                maxMembers: maxMembers ?? 1000,
                isPublic: isPublic,
                requiresApproval: requiresApproval,
                inviteCode: originalTeam.inviteCode,
                activityLevel: originalTeam.activityLevel,
                averageWorkoutsPerWeek: originalTeam.averageWorkoutsPerWeek,
                totalTeamWorkouts: originalTeam.totalTeamWorkouts,
                totalTeamDistance: originalTeam.totalTeamDistance,
                totalTeamCalories: originalTeam.totalTeamCalories,
                currentStreak: originalTeam.currentStreak,
                longestStreak: originalTeam.longestStreak,
                achievements: originalTeam.achievements,
                tags: originalTeam.tags,
                category: selectedCategory,
                level: originalTeam.level,
                experience: originalTeam.experience,
                recentActivities: originalTeam.recentActivities,
                isVerified: originalTeam.isVerified,
                imageURL: teamImageURL
            )
            
            await socialService.updateTeam(updatedTeam)
            hasChanges = false
            
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }
    
    func exportTeamData() {
        // Implement team data export
        print("Exporting team data...")
    }
}

// MARK: - Team Category

enum TeamCategory: String, CaseIterable, Codable {
    case fitness = "fitness"
    case running = "running"
    case cycling = "cycling"
    case weightlifting = "weightlifting"
    case yoga = "yoga"
    case sports = "sports"
    case outdoor = "outdoor"
    case competitive = "competitive"
    case social = "social"
    case wellness = "wellness"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .all: return "All Categories"
        default: return rawValue.capitalized
        }
    }
    
    var iconName: String {
        switch self {
        case .fitness: return "figure.run"
        case .running: return "figure.walk"
        case .cycling: return "bicycle"
        case .weightlifting: return "dumbbell"
        case .yoga: return "figure.mind.and.body"
        case .sports: return "sportscourt"
        case .outdoor: return "tree"
        case .competitive: return "trophy"
        case .social: return "person.3"
        case .wellness: return "heart"
        case .all: return "grid"
        }
    }
    
    var color: Color {
        switch self {
        case .fitness: return .orange
        case .running: return .blue
        case .cycling: return .green
        case .weightlifting: return .red
        case .yoga: return .purple
        case .sports: return .yellow
        case .outdoor: return .mint
        case .competitive: return .pink
        case .social: return .cyan
        case .wellness: return .indigo
        case .all: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    TeamSettingsView(
        team: Team(
            id: UUID(),
            name: "Sprint Squad",
            description: "Elite sprinters pushing each other to new limits",
            iconName: "bolt.fill",
            memberCount: 12,
            activityLevel: .elite,
            averageWorkoutsPerWeek: 6.2
        )
    )
}
