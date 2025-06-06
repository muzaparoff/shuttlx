//
//  TeamDetailView.swift
//  ShuttlX
//
//  Comprehensive team management and collaboration interface
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import Charts

struct TeamDetailView: View {
    let team: Team
    @StateObject private var viewModel: TeamDetailViewModel
    @EnvironmentObject var socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TeamTab = .overview
    @State private var showingInviteMembers = false
    @State private var showingTeamSettings = false
    @State private var showingLeaveTeam = false
    
    init(team: Team, socialService: SocialService) {
        self.team = team
        self._viewModel = StateObject(wrappedValue: TeamDetailViewModel(socialService: socialService))
    }
    
    enum TeamTab: String, CaseIterable {
        case overview = "Overview"
        case members = "Members"
        case challenges = "Challenges"
        case workouts = "Workouts"
        case chat = "Chat"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Team Header
                teamHeaderSection
                
                // Tab Selector
                teamTabSelector
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    teamOverviewTab
                        .tag(TeamTab.overview)
                    
                    teamMembersTab
                        .tag(TeamTab.members)
                    
                    teamChallengesTab
                        .tag(TeamTab.challenges)
                    
                    teamWorkoutsTab
                        .tag(TeamTab.workouts)
                    
                    teamChatTab
                        .tag(TeamTab.chat)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadTeamData(teamId: team.id)
        }
        .sheet(isPresented: $showingInviteMembers) {
            InviteMembersView(team: team)
        }
        .sheet(isPresented: $showingTeamSettings) {
            TeamSettingsView(team: team)
        }
        .alert("Leave Team", isPresented: $showingLeaveTeam) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.leaveTeam(team)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to leave '\(team.name)'? This action cannot be undone.")
        }
    }
    
    // MARK: - Team Header Section
    private var teamHeaderSection: some View {
        VStack(spacing: 16) {
            // Navigation and Actions
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    if viewModel.currentUserRole == .admin || viewModel.currentUserRole == .moderator {
                        Button(action: { showingInviteMembers = true }) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                        
                        Button(action: { showingTeamSettings = true }) {
                            Image(systemName: "gear")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Menu {
                        if viewModel.currentUserRole != .admin {
                            Button("Leave Team", role: .destructive) {
                                showingLeaveTeam = true
                            }
                        }
                        
                        Button("Share Team") {
                            shareTeam()
                        }
                        
                        Button("Report Team", role: .destructive) {
                            reportTeam()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)
            
            // Team Info
            VStack(spacing: 12) {
                // Team Avatar
                ZStack {
                    Circle()
                        .fill(Color.orange.gradient)
                        .frame(width: 80, height: 80)
                    
                    if let imageURL = team.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: team.iconName)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: team.iconName)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                
                // Team Details
                VStack(spacing: 4) {
                    HStack {
                        Text(team.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if team.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                        }
                        
                        if team.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(team.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        Label("\(team.memberCount) members", systemImage: "person.3.fill")
                        Label("\(viewModel.activeMembers) active", systemImage: "circle.fill")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Team Tab Selector
    private var teamTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(TeamTab.allCases, id: \.rawValue) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 8) {
                            HStack {
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .semibold : .medium)
                                
                                if tab == .chat && viewModel.unreadMessages > 0 {
                                    Text("\(viewModel.unreadMessages)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                            }
                            .foregroundColor(selectedTab == tab ? .orange : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? Color.orange : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(minWidth: 80)
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Team Overview Tab
    private var teamOverviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Team Stats
                teamStatsSection
                
                // Recent Activity
                recentActivitySection
                
                // Upcoming Events
                upcomingEventsSection
                
                // Top Performers
                topPerformersSection
            }
            .padding()
        }
    }
    
    private var teamStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                TeamStatCard(
                    title: "Total Workouts",
                    value: "\(viewModel.teamStats.totalWorkouts)",
                    icon: "figure.run",
                    color: .blue
                )
                
                TeamStatCard(
                    title: "Combined Distance",
                    value: String(format: "%.0f km", viewModel.teamStats.totalDistance / 1000),
                    icon: "location.fill",
                    color: .green
                )
                
                TeamStatCard(
                    title: "Active Challenges",
                    value: "\(viewModel.teamStats.activeChallenges)",
                    icon: "flag.fill",
                    color: .orange
                )
                
                TeamStatCard(
                    title: "Avg Weekly Activity",
                    value: String(format: "%.1f", viewModel.teamStats.averageWeeklyWorkouts),
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !viewModel.recentActivities.isEmpty {
                ForEach(viewModel.recentActivities.prefix(5)) { activity in
                    TeamActivityRow(activity: activity)
                }
            } else {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.currentUserRole == .admin || viewModel.currentUserRole == .moderator {
                    Button("Create Event") {
                        // TODO: Implement event creation
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            
            if !viewModel.upcomingEvents.isEmpty {
                ForEach(viewModel.upcomingEvents) { event in
                    TeamEventCard(event: event)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No upcoming events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var topPerformersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Performers This Week")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !viewModel.topPerformers.isEmpty {
                ForEach(viewModel.topPerformers.indices, id: \.self) { index in
                    TeamMemberPerformanceRow(
                        member: viewModel.topPerformers[index],
                        rank: index + 1
                    )
                }
            } else {
                Text("No performance data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Team Members Tab
    private var teamMembersTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Members List
                ForEach(viewModel.teamMembers) { member in
                    TeamMemberRow(
                        member: member,
                        currentUserRole: viewModel.currentUserRole,
                        onRoleChange: { newRole in
                            Task {
                                await viewModel.updateMemberRole(member, role: newRole)
                            }
                        },
                        onRemoveMember: {
                            Task {
                                await viewModel.removeMember(member)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Team Challenges Tab
    private var teamChallengesTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active Challenges
                if !viewModel.teamChallenges.isEmpty {
                    ForEach(viewModel.teamChallenges) { challenge in
                        TeamChallengeCard(challenge: challenge)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "flag")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("No active team challenges")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create or join challenges to compete with your team!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if viewModel.currentUserRole == .admin || viewModel.currentUserRole == .moderator {
                            Button("Create Team Challenge") {
                                // TODO: Implement team challenge creation
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Team Workouts Tab
    private var teamWorkoutsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Shared Workouts
                if !viewModel.sharedWorkouts.isEmpty {
                    ForEach(viewModel.sharedWorkouts) { workout in
                        SharedWorkoutCard(workout: workout)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("No shared workouts")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Share your workouts with the team!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Share a Workout") {
                            // TODO: Implement workout sharing
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Team Chat Tab
    private var teamChatTab: some View {
        VStack {
            if viewModel.chatMessages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("Start the conversation!")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Chat with your team members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Chat messages list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.chatMessages) { message in
                            TeamChatMessageRow(message: message)
                        }
                    }
                    .padding()
                }
                
                // Message input
                teamChatInput
            }
        }
    }
    
    private var teamChatInput: some View {
        HStack {
            TextField("Type a message...", text: $viewModel.newMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: { sendMessage() }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.orange)
            }
            .disabled(viewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    private func sendMessage() {
        Task {
            await viewModel.sendMessage(viewModel.newMessage, to: team.id)
            viewModel.newMessage = ""
        }
    }
    
    private func shareTeam() {
        // TODO: Implement team sharing
    }
    
    private func reportTeam() {
        // TODO: Implement team reporting
    }
}

// MARK: - Supporting Views

struct TeamStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TeamActivityRow: View {
    let activity: TeamActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.iconName)
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.description)
                    .font(.subheadline)
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TeamEventCard: View {
    let event: TeamEvent
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "calendar")
                    Text(event.date, style: .date)
                    
                    Image(systemName: "clock")
                    Text(event.date, style: .time)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Text("\(event.participantCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("going")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TeamMemberPerformanceRow: View {
    let member: TeamMember
    let rank: Int
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            // Member Info
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: member.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(member.displayName.prefix(1))
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                Text(member.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Performance metric
            VStack(alignment: .trailing) {
                Text("\(member.weeklyWorkouts)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    TeamDetailView(
        team: Team(
            id: UUID(),
            name: "Sprint Squad",
            description: "Elite sprinters pushing each other to new limits",
            iconName: "bolt.fill",
            memberCount: 12,
            activityLevel: .elite,
            averageWorkoutsPerWeek: 6.2,
            isPrivate: false,
            isVerified: true,
            imageURL: nil
        )
    )
}
