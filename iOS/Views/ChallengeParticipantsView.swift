//
//  ChallengeParticipantsView.swift
//  ShuttlX
//
//  Comprehensive view for challenge participants with detailed progress tracking
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import Charts

struct ChallengeParticipantsView: View {
    let challenge: Challenge
    @StateObject private var viewModel: ChallengeDetailViewModel
    @EnvironmentObject var socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSortOption: SortOption = .rank
    @State private var showingInviteSheet = false
    @State private var searchText = ""
    
    init(challenge: Challenge, socialService: SocialService) {
        self.challenge = challenge
        self._viewModel = StateObject(wrappedValue: ChallengeDetailViewModel(socialService: socialService))
    }
    
    enum SortOption: CaseIterable {
        case rank, progress, joinDate, name
        
        var displayName: String {
            switch self {
            case .rank: return "Rank"
            case .progress: return "Progress"
            case .joinDate: return "Join Date"
            case .name: return "Name"
            }
        }
    }
    
    var filteredAndSortedParticipants: [ChallengeParticipant] {
        var participants = viewModel.topParticipants
        
        // Filter by search text
        if !searchText.isEmpty {
            participants = participants.filter { participant in
                participant.displayName.localizedCaseInsensitiveContains(searchText) ||
                participant.username.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by selected option
        switch selectedSortOption {
        case .rank:
            return participants.sorted { $0.progress > $1.progress }
        case .progress:
            return participants.sorted { $0.progress > $1.progress }
        case .joinDate:
            return participants.sorted { $0.joinDate < $1.joinDate }
        case .name:
            return participants.sorted { $0.displayName < $1.displayName }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Controls Section
                controlsSection
                
                // Participants List
                participantsList
            }
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInviteSheet = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadChallengeData(challengeId: challenge.id)
            }
            .sheet(isPresented: $showingInviteSheet) {
                InviteToChallengView(challenge: challenge)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Challenge Overview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(viewModel.topParticipants.count) participants")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(challenge.endDate, style: .relative)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Progress Distribution Chart
            if #available(iOS 16.0, *) {
                progressDistributionChart
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Progress Distribution Chart
    @available(iOS 16.0, *)
    private var progressDistributionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress Distribution")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            Chart {
                ForEach(progressBuckets, id: \.range) { bucket in
                    BarMark(
                        x: .value("Progress", bucket.range),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
                }
            }
            .frame(height: 120)
            .padding(.horizontal)
        }
    }
    
    private var progressBuckets: [(range: String, count: Int)] {
        let participants = viewModel.topParticipants
        let buckets = [
            "0-20%": participants.filter { $0.progress >= 0 && $0.progress < 0.2 }.count,
            "20-40%": participants.filter { $0.progress >= 0.2 && $0.progress < 0.4 }.count,
            "40-60%": participants.filter { $0.progress >= 0.4 && $0.progress < 0.6 }.count,
            "60-80%": participants.filter { $0.progress >= 0.6 && $0.progress < 0.8 }.count,
            "80-100%": participants.filter { $0.progress >= 0.8 && $0.progress <= 1.0 }.count
        ]
        
        return buckets.map { (range: $0.key, count: $0.value) }
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search participants...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Sort Options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { selectedSortOption = option }) {
                            Text(option.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedSortOption == option ? Color.orange : Color(.systemGray5))
                                )
                                .foregroundColor(selectedSortOption == option ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Participants List
    private var participantsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredAndSortedParticipants.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(filteredAndSortedParticipants.enumerated()), id: \.element.userId) { index, participant in
                        ParticipantDetailRow(
                            participant: participant,
                            rank: index + 1,
                            challenge: challenge,
                            isCurrentUser: participant.userId == socialService.currentUserProfile?.id
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No participants found")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(searchText.isEmpty ? "Be the first to join this challenge!" : "Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("Invite Friends") {
                    showingInviteSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding()
    }
}

// MARK: - Participant Detail Row

struct ParticipantDetailRow: View {
    let participant: ChallengeParticipant
    let rank: Int
    let challenge: Challenge
    let isCurrentUser: Bool
    @State private var showingProfile = false
    
    var body: some View {
        Button(action: { showingProfile = true }) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Rank and Avatar
                    HStack(spacing: 12) {
                        // Rank Badge
                        Text("#\(rank)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor)
                            .frame(width: 40)
                        
                        // User Avatar
                        AsyncImage(url: URL(string: participant.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.orange.gradient)
                                .overlay(
                                    Text(participant.displayName.prefix(1))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    }
                    
                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(participant.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if isCurrentUser {
                                Text("YOU")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text("@\(participant.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Joined \(participant.joinDate, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Progress Info
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(participant.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(progressColor)
                        
                        Text(participant.progressText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(participant.completedSessions) sessions")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: participant.progress)
                        .tint(progressColor)
                        .scaleEffect(y: 1.5)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentUser ? Color.orange.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrentUser ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfile) {
            UserProfileDetailView(userId: participant.userId)
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .primary
        }
    }
    
    private var progressColor: Color {
        switch participant.progress {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        case 0.3..<0.6: return .blue
        default: return .red
        }
    }
}

// MARK: - Invite to Challenge View

struct InviteToChallengView: View {
    let challenge: Challenge
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialService: SocialService
    @State private var selectedFriends: Set<UUID> = []
    @State private var friends: [UserProfile] = []
    @State private var searchText = ""
    @State private var isLoading = false
    
    var filteredFriends: [UserProfile] {
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { friend in
                friend.displayName.localizedCaseInsensitiveContains(searchText) ||
                friend.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Invite to \(challenge.title)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Challenge your friends to join and compete!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search friends...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Friends List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredFriends) { friend in
                            FriendInviteRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onToggle: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.remove(friend.id)
                                    } else {
                                        selectedFriends.insert(friend.id)
                                    }
                                }
                            )
                        }
                        
                        if filteredFriends.isEmpty && !isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No friends found")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Add friends to invite them to challenges!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                
                // Send Invites Button
                if !selectedFriends.isEmpty {
                    VStack {
                        Button(action: sendInvites) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send \(selectedFriends.count) Invites")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.gradient)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadFriends()
            }
        }
    }
    
    private func loadFriends() {
        isLoading = true
        Task {
            friends = await socialService.getUserFriends()
            isLoading = false
        }
    }
    
    private func sendInvites() {
        isLoading = true
        Task {
            await socialService.inviteUsersToChallenge(
                challengeId: challenge.id,
                userIds: Array(selectedFriends)
            )
            dismiss()
        }
    }
}

// MARK: - Friend Invite Row

struct FriendInviteRow: View {
    let friend: UserProfile
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: friend.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.orange.gradient)
                        .overlay(
                            Text(friend.displayName.prefix(1))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // Friend Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("@\(friend.username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .orange : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - User Profile Detail View

struct UserProfileDetailView: View {
    let userId: UUID
    @Environment(\.dismiss) private var dismiss
    // This would be implemented with full user profile details
    
    var body: some View {
        NavigationView {
            VStack {
                Text("User Profile")
                Text("User ID: \(userId)")
                // Full profile implementation would go here
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChallengeParticipantsView(
        challenge: Challenge(
            title: "100K Steps This Week",
            description: "Walk or run 100,000 steps in 7 days",
            requirements: ChallengeRequirements(targetValue: 100000),
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        )
    )
}
