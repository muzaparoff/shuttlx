//
//  ChallengeDetailView.swift
//  ShuttlX
//
//  Detailed challenge view with participant tracking and real-time updates
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import Charts

struct ChallengeDetailView: View {
    let challenge: Challenge
    @EnvironmentObject var socialService: SocialService
    @StateObject private var viewModel: ChallengeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingParticipants = false
    @State private var showingProgress = false
    
    init(challenge: Challenge, socialService: SocialService) {
        self.challenge = challenge
        self._viewModel = StateObject(wrappedValue: ChallengeDetailViewModel(socialService: socialService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Challenge Header
                    challengeHeaderSection
                    
                    // Progress Overview
                    progressOverviewSection
                    
                    // Leaderboard Preview
                    leaderboardPreviewSection
                    
                    // My Progress
                    myProgressSection
                    
                    // Activity Feed
                    activityFeedSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { shareChallenge() }) {
                            Label("Share Challenge", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { reportChallenge() }) {
                            Label("Report", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadChallengeData(challengeId: challenge.id)
        }
        .sheet(isPresented: $showingParticipants) {
            ChallengeParticipantsView(challenge: challenge)
        }
        .sheet(isPresented: $showingProgress) {
            ChallengeProgressView(challenge: challenge)
        }
    }
    
    // MARK: - Challenge Header Section
    private var challengeHeaderSection: some View {
        VStack(spacing: 16) {
            // Challenge Icon and Title
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.gradient)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.orange)
                        Text("\(challenge.participantCount) participants")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            // Challenge Duration
            HStack {
                VStack(alignment: .leading) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(challengeDurationText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timeRemainingText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(timeRemainingColor)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Progress Overview Section
    private var progressOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: challenge.progress)
                    .stroke(Color.orange.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: challenge.progress)
                
                VStack {
                    Text("\(Int(challenge.progress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Details
            if let progressDetails = viewModel.progressDetails {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ProgressCard(
                        title: "Your Progress",
                        value: "\(Int(progressDetails.userProgress * 100))%",
                        icon: "person.fill",
                        color: .blue
                    )
                    
                    ProgressCard(
                        title: "Rank",
                        value: "#\(progressDetails.userRank)",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                    
                    ProgressCard(
                        title: "Average",
                        value: "\(Int(progressDetails.averageProgress * 100))%",
                        icon: "chart.bar.fill",
                        color: .green
                    )
                    
                    ProgressCard(
                        title: "Top Performer",
                        value: "\(Int(progressDetails.topProgress * 100))%",
                        icon: "star.fill",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Leaderboard Preview Section
    private var leaderboardPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingParticipants = true
                }
                .foregroundColor(.orange)
            }
            
            if !viewModel.topParticipants.isEmpty {
                ForEach(viewModel.topParticipants.prefix(5).indices, id: \.self) { index in
                    ChallengeLeaderboardRow(
                        participant: viewModel.topParticipants[index],
                        rank: index + 1,
                        isCurrentUser: viewModel.topParticipants[index].userId == socialService.currentUserProfile?.id
                    )
                }
            } else {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - My Progress Section
    private var myProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let userProgress = viewModel.userChallengeProgress {
                VStack(spacing: 16) {
                    // Progress Chart
                    if #available(iOS 16.0, *) {
                        Chart(userProgress.dailyProgress.indices, id: \.self) { index in
                            LineMark(
                                x: .value("Day", index + 1),
                                y: .value("Progress", userProgress.dailyProgress[index])
                            )
                            .foregroundStyle(Color.orange.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                        .frame(height: 120)
                        .chartYScale(domain: 0...1)
                    } else {
                        // Fallback for older iOS versions
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(userProgress.dailyProgress.indices, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.orange.opacity(0.7))
                                    .frame(width: 20, height: max(4, userProgress.dailyProgress[index] * 80))
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 100)
                        .padding()
                    }
                    
                    // Progress Stats
                    HStack {
                        VStack {
                            Text("\(userProgress.completedSessions)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("\(Int(userProgress.totalProgress * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("\(userProgress.streak)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Day Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: { showingProgress = true }) {
                    Text("View Detailed Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                }
            } else {
                Text("Join the challenge to track your progress!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Activity Feed Section
    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !viewModel.recentActivity.isEmpty {
                ForEach(viewModel.recentActivity) { activity in
                    ChallengeActivityRow(activity: activity)
                }
            } else {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if viewModel.isUserParticipating {
                // Leave Challenge Button
                Button(action: { leaveChallengeAction() }) {
                    Text("Leave Challenge")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
            } else {
                // Join Challenge Button
                Button(action: { joinChallengeAction() }) {
                    Text("Join Challenge")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.gradient)
                        .cornerRadius(12)
                }
                .disabled(challenge.isExpired)
            }
            
            // Invite Friends Button
            Button(action: { inviteFriendsAction() }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Invite Friends")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var challengeDurationText: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: challenge.startDate, to: challenge.endDate).day ?? 0
        
        if days == 1 {
            return "1 day"
        } else if days < 7 {
            return "\(days) days"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }
    
    private var timeRemainingText: String {
        let timeRemaining = challenge.endDate.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            return "Expired"
        }
        
        let days = Int(timeRemaining) / (24 * 3600)
        let hours = (Int(timeRemaining) % (24 * 3600)) / 3600
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = (Int(timeRemaining) % 3600) / 60
            return "\(minutes)m"
        }
    }
    
    private var timeRemainingColor: Color {
        let timeRemaining = challenge.endDate.timeIntervalSinceNow
        let totalDuration = challenge.endDate.timeIntervalSince(challenge.startDate)
        let remainingPercentage = timeRemaining / totalDuration
        
        if remainingPercentage > 0.5 {
            return .green
        } else if remainingPercentage > 0.2 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Actions
    private func joinChallengeAction() {
        Task {
            await viewModel.joinChallenge(challenge)
        }
    }
    
    private func leaveChallengeAction() {
        Task {
            await viewModel.leaveChallenge(challenge)
        }
    }
    
    private func inviteFriendsAction() {
        // TODO: Implement friend invitation
    }
    
    private func shareChallenge() {
        // TODO: Implement challenge sharing
    }
    
    private func reportChallenge() {
        // TODO: Implement challenge reporting
    }
}

// MARK: - Supporting Views

struct ProgressCard: View {
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChallengeLeaderboardRow: View {
    let participant: ChallengeParticipant
    let rank: Int
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.gradient)
                    .frame(width: 32, height: 32)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // User Info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: participant.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(participant.username.prefix(1))
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.displayName)
                        .font(.subheadline)
                        .fontWeight(isCurrentUser ? .bold : .medium)
                        .foregroundColor(isCurrentUser ? .orange : .primary)
                    
                    Text("@\(participant.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(participant.progress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(participant.progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct ChallengeActivityRow: View {
    let activity: ChallengeActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.iconName)
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.message)
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

// MARK: - Preview
#Preview {
    ChallengeDetailView(
        challenge: Challenge(
            id: UUID(),
            title: "100K Steps This Week",
            description: "Walk or run 100,000 steps in 7 days",
            iconName: "figure.walk",
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            participantCount: 127,
            progress: 0.68,
            isExpired: false
        )
    )
}
