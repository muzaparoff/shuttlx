//
//  SocialView.swift
//  ShuttlX
//
//  Enhanced Social Platform Interface with comprehensive community features
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel: SocialViewModel
    @EnvironmentObject var socialService: SocialService
    @State private var selectedTab: SocialTab = .feed
    @State private var showingProfile = false
    @State private var showingNotifications = false
    @State private var showingMessages = false
    
    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: SocialViewModel(socialService: socialService))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Header with user info and notifications
                    headerView
                    
                    // Modern Tab Selector
                    customTabSelector
                    
                    // Content with smooth transitions
                    TabView(selection: $selectedTab) {
                        enhancedFeedView
                            .tag(SocialTab.feed)
                        
                        modernChallengesView
                            .tag(SocialTab.challenges)
                        
                        advancedLeaderboardView
                            .tag(SocialTab.leaderboard)
                        
                        comprehensiveTeamsView
                            .tag(SocialTab.teams)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $viewModel.showingCreatePost) {
            EnhancedCreatePostView()
        }
        .sheet(isPresented: $showingProfile) {
            UserProfileView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingMessages) {
            MessagesView()
        }
        .onAppear {
            viewModel.loadSocialData()
            socialService.startRealTimeSync()
        }
        .onDisappear {
            socialService.stopRealTimeSync()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // User avatar and greeting
            Button(action: { showingProfile = true }) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: socialService.currentUser?.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.gradient)
                            .overlay(
                                Text(socialService.currentUser?.name.prefix(1) ?? "U")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(socialService.currentUser?.isOnline == true ? Color.green : Color.clear, lineWidth: 3)
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hello, \(socialService.currentUser?.name.split(separator: " ").first ?? "User")!")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Level \(socialService.currentUser?.level ?? 1) • \(socialService.currentUser?.experienceLevel.rawValue.capitalized ?? "Beginner")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                // Messages
                Button(action: { showingMessages = true }) {
                    ZStack {
                        Image(systemName: "message.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        if socialService.unreadMessagesCount > 0 {
                            Text("\(socialService.unreadMessagesCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // Notifications
                Button(action: { showingNotifications = true }) {
                    ZStack {
                        Image(systemName: "bell.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        if socialService.unreadNotificationsCount > 0 {
                            Text("\(socialService.unreadNotificationsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                // Create post
                Button(action: { viewModel.showingCreatePost = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Custom Tab Selector
    private var customTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(tab.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .orange : .secondary)
                        
                        // Active indicator
                        Rectangle()
                            .fill(selectedTab == tab ? Color.orange : Color.clear)
                            .frame(height: 2)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Enhanced Feed View
    private var enhancedFeedView: some View {
        RefreshableScrollView {
            LazyVStack(spacing: 20) {
                // Stories section
                if !socialService.activeStories.isEmpty {
                    storiesSection
                }
                
                // Quick stats card
                quickStatsCard
                
                // Feed posts
                ForEach(viewModel.feedPosts) { post in
                    EnhancedFeedPostCard(
                        post: post,
                        onLike: { viewModel.toggleLike(for: post) },
                        onComment: { viewModel.showComments(for: post) },
                        onShare: { viewModel.sharePost(post) },
                        onProfile: { viewModel.showUserProfile(post.author) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // Load more indicator
                if viewModel.hasMorePosts {
                    LoadingIndicator()
                        .onAppear {
                            viewModel.loadMorePosts()
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } onRefresh: {
            await viewModel.refreshFeed()
        }
    }
    
    // MARK: - Stories Section
    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stories")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Add story button
                    Button(action: { viewModel.showingCreateStory = true }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.gradient)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Your Story")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Stories from followed users
                    ForEach(socialService.activeStories) { story in
                        StoryCircle(story: story) {
                            viewModel.viewStory(story)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Quick Stats Card
    private var quickStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                StatItem(
                    title: "Workouts",
                    value: "\(socialService.todayStats.workoutsCompleted)",
                    icon: "figure.run",
                    color: .orange
                )
                
                StatItem(
                    title: "Minutes",
                    value: "\(Int(socialService.todayStats.totalDuration / 60))",
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "Calories",
                    value: "\(Int(socialService.todayStats.caloriesBurned))",
                    icon: "flame.fill",
                    color: .red
                )
                
                StatItem(
                    title: "Distance",
                    value: String(format: "%.1f", socialService.todayStats.totalDistance),
                    icon: "location.fill",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Modern Challenges View
    private var modernChallengesView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Active challenges header
                if !viewModel.activeChallenges.isEmpty {
                    activeChallengesSection
                }
                
                // Challenge categories
                challengeCategoriesSection
                
                // Available challenges
                availableChallengesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await viewModel.refreshChallenges()
        }
    }
    
    private var activeChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Challenges")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(viewModel.activeChallenges.count) active")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
            
            ForEach(viewModel.activeChallenges) { challenge in
                ActiveChallengeCard(challenge: challenge) {
                    viewModel.leaveChallenge(challenge)
                } onViewDetails: {
                    viewModel.showChallengeDetails(challenge)
                }
            }
        }
    }
    
    private var challengeCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChallengeCategory.allCases, id: \.self) { category in
                        ChallengeCategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Challenges")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    viewModel.showAllChallenges = true
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            ForEach(viewModel.filteredAvailableChallenges) { challenge in
                AvailableChallengeCard(challenge: challenge) {
                    viewModel.joinChallenge(challenge)
                } onViewDetails: {
                    viewModel.showChallengeDetails(challenge)
                }
            }
        }
    }
                
                // Available Challenges
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Challenges")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    ForEach(viewModel.availableChallenges) { challenge in
                        ChallengeCard(challenge: challenge, isActive: false) {
                            viewModel.joinChallenge(challenge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .refreshable {
            await viewModel.refreshChallenges()
        }
    }
    
    private var leaderboardView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Leaderboard Type Selector
                Picker("Leaderboard Type", selection: $viewModel.selectedLeaderboardType) {
                    ForEach(LeaderboardType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Time Period Selector
                Picker("Time Period", selection: $viewModel.selectedTimePeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                
                // Leaderboard Entries
                ForEach(Array(viewModel.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(entry: entry, rank: index + 1)
                        .padding(.horizontal)
                }
            }
        }
        .refreshable {
            await viewModel.refreshLeaderboard()
        }
    }
    
    private var teamsView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // My Teams
                if !viewModel.myTeams.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Teams")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ForEach(viewModel.myTeams) { team in
                            TeamCard(team: team, isMember: true) {
                                viewModel.viewTeam(team)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Discover Teams
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Discover Teams")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Create Team") {
                            viewModel.showingCreateTeam = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    
                    ForEach(viewModel.discoveredTeams) { team in
                        TeamCard(team: team, isMember: false) {
                            viewModel.joinTeam(team)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCreateTeam) {
            CreateTeamView()
        }
        .refreshable {
            await viewModel.refreshTeams()
        }
    }
}

// MARK: - Supporting Views

struct FeedPostCard: View {
    let post: FeedPost
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Header
            HStack {
                AsyncImage(url: URL(string: post.userAvatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.userName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: post.timestamp, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Content
            Text(post.content)
                .font(.body)
            
            // Workout Data (if applicable)
            if let workoutSummary = post.workoutSummary {
                WorkoutSummaryCard(summary: workoutSummary)
            }
            
            // Media (if applicable)
            if let imageURL = post.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(8)
            }
            
            // Actions
            HStack(spacing: 24) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .secondary)
                        
                        Text("\(post.likesCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: challenge.iconName)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            // Progress (if active)
            if isActive {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(challenge.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: challenge.progress)
                        .tint(.orange)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(challenge.participantCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(challenge.endDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Button(action: action) {
                Text(isActive ? "Leave Challenge" : "Join Challenge")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .red : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isActive ? .red.opacity(0.1) : .orange)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(rankColor)
                .frame(width: 30)
            
            // User Avatar
            AsyncImage(url: URL(string: entry.userAvatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entry.userLocation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedScore)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(entry.scoreType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rank <= 3 ? .orange.opacity(0.1) : .ultraThinMaterial)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .orange
        case 2: return .gray
        case 3: return .brown
        default: return .primary
        }
    }
}

struct TeamCard: View {
    let team: Team
    let isMember: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(team.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: team.iconName)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(team.memberCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Activity Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(team.activityLevel.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(team.activityLevel.color)
                }
            }
            
            Button(action: action) {
                Text(isMember ? "View Team" : "Join Team")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.orange)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct WorkoutSummaryCard: View {
    let summary: WorkoutSummary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: summary.workoutType.iconName)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.workoutType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(summary.duration / 60)):\(String(format: "%02d", Int(summary.duration) % 60))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 2) {
                    Text("\(Int(summary.caloriesBurned))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("CAL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let distance = summary.distance {
                    VStack(alignment: .center, spacing: 2) {
                        Text(String(format: "%.1f", distance))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("KM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.1))
        )
    }
}

// MARK: - Enhanced Social Components

// MARK: - Enhanced Feed Components
struct EnhancedFeedPostCard: View {
    let post: FeedPost
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onProfile: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced User Header
            HStack(spacing: 12) {
                Button(action: onProfile) {
                    AsyncImage(url: URL(string: post.author.avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.gradient)
                            .overlay(
                                Text(post.author.name.prefix(1))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if post.author.level >= 10 {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(post.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if post.location != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Share Post", systemImage: "square.and.arrow.up") { onShare() }
                    Button("Report Post", systemImage: "flag") { }
                    Button("Mute User", systemImage: "speaker.slash") { }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Enhanced Content
            VStack(alignment: .leading, spacing: 12) {
                if !post.content.isEmpty {
                    Text(post.content)
                        .font(.body)
                        .lineSpacing(4)
                }
                
                // Workout Data with enhanced styling
                if let workoutData = post.workoutData {
                    EnhancedWorkoutCard(workoutData: workoutData)
                }
                
                // Media with better layout
                if !post.mediaURLs.isEmpty {
                    EnhancedMediaView(mediaURLs: post.mediaURLs)
                }
                
                // Achievement badge
                if let achievement = post.achievement {
                    AchievementBadge(achievement: achievement)
                }
            }
            
            // Enhanced Actions Bar
            HStack(spacing: 24) {
                // Like button with animation
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(post.isLikedByCurrentUser ? .red : .secondary)
                            .scaleEffect(post.isLikedByCurrentUser ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: post.isLikedByCurrentUser)
                        
                        Text("\(post.likesCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Comment button
                Button(action: onComment) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        
                        Text("\(post.commentsCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Share button
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                        
                        if post.sharesCount > 0 {
                            Text("\(post.sharesCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Bookmark button
                Button(action: {}) {
                    Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(post.isBookmarked ? .orange : .secondary)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct EnhancedWorkoutCard: View {
    let workoutData: WorkoutData
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: workoutData.type.iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(workoutData.type.color.gradient)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workoutData.type.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(Int(workoutData.duration / 60)):\(String(format: "%02d", Int(workoutData.duration) % 60))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Intensity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= workoutData.intensity ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            
            // Workout stats grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                StatItem(
                    title: "Calories",
                    value: "\(Int(workoutData.caloriesBurned))",
                    icon: "flame.fill",
                    color: .red
                )
                
                if let distance = workoutData.distance {
                    StatItem(
                        title: "Distance",
                        value: String(format: "%.1f km", distance),
                        icon: "location.fill",
                        color: .green
                    )
                }
                
                if let avgHeartRate = workoutData.averageHeartRate {
                    StatItem(
                        title: "Avg HR",
                        value: "\(Int(avgHeartRate)) bpm",
                        icon: "heart.fill",
                        color: .pink
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Challenge Components
struct ActiveChallengeCard: View {
    let challenge: Challenge
    let onLeave: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: challenge.category.iconName)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(challenge.category.color.gradient)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(challenge.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(challenge.category.color.opacity(0.2))
                                .foregroundColor(challenge.category.color)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Menu {
                    Button("View Details", systemImage: "info.circle") { onViewDetails() }
                    Button("Share Challenge", systemImage: "square.and.arrow.up") { }
                    Button("Leave Challenge", systemImage: "xmark", role: .destructive) { onLeave() }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Progress Section
            VStack(spacing: 12) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(challenge.currentValue))/\(Int(challenge.targetValue)) \(challenge.metric.unit)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .clipShape(Capsule())
                        
                        Rectangle()
                            .fill(Color.orange.gradient)
                            .frame(width: geometry.size.width * min(challenge.progress, 1.0), height: 8)
                            .clipShape(Capsule())
                            .animation(.easeInOut(duration: 0.5), value: challenge.progress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(Int(challenge.progress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(challenge.daysRemaining) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Challenge Stats
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(challenge.participantCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("#\(challenge.currentRank ?? 0)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Your Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(challenge.experiencePoints) XP")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Reward")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct ChallengeCategoryCard: View {
    let category: ChallengeCategory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? category.color.gradient : category.color.opacity(0.1))
                    )
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? category.color : .secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Leaderboard Components
struct TopPerformerCard: View {
    let entry: LeaderboardEntry
    let rank: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: entry.user.avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.orange.gradient)
                        .overlay(
                            Text(entry.user.name.prefix(1))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                // Medal overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Image(systemName: "medal.fill")
                            .font(.title3)
                            .foregroundColor(color)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 28, height: 28)
                            )
                    }
                }
                .frame(width: 80, height: 80)
            }
            
            VStack(spacing: 4) {
                Text(entry.user.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(entry.value, specifier: "%.1f") \(entry.metric.unit)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text("Level \(entry.user.level)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct CompactPerformerCard: View {
    let entry: LeaderboardEntry
    let rank: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 30)
            
            AsyncImage(url: URL(string: entry.user.avatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.orange.gradient)
                    .overlay(
                        Text(entry.user.name.prefix(1))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(entry.value, specifier: "%.1f")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentUser: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Rank with special styling for top positions
                Text("#\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
                    .frame(width: 40)
                
                // User avatar with online indicator
                ZStack {
                    AsyncImage(url: URL(string: entry.user.avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.gradient)
                            .overlay(
                                Text(entry.user.name.prefix(1))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    if entry.user.isOnline {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: 2)
                                    )
                            }
                        }
                        .frame(width: 50, height: 50)
                    }
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.user.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if entry.user.level >= 10 {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
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
                    
                    Text("Level \(entry.user.level) • \(entry.user.location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Performance metrics
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(entry.value, specifier: "%.1f")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(rankColor)
                    
                    Text(entry.metric.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentUser ? Color.orange.opacity(0.1) : 
                          (rank <= 3 ? rankColor.opacity(0.1) : .ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrentUser ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .primary
        }
    }
}

// MARK: - Team Components
struct MyTeamCard: View {
    let team: Team
    let onView: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: team.logoURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(team.color.gradient)
                                .overlay(
                                    Text(team.name.prefix(1))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack(spacing: 8) {
                                Text(team.category.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(team.category.color.opacity(0.2))
                                    .foregroundColor(team.category.color)
                                    .clipShape(Capsule())
                                
                                Text("Level \(team.level)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("View Team", systemImage: "eye") { onView() }
                    Button("Team Settings", systemImage: "gear") { }
                    Button("Invite Members", systemImage: "person.badge.plus") { }
                    Button("Leave Team", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { onLeave() }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Team stats
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(team.memberCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(team.weeklyWorkouts)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Weekly Workouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("#\(team.leaderboardRank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Team Rank")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recent activity
            if !team.recentActivities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(team.recentActivities.prefix(2)) { activity in
                        HStack(spacing: 8) {
                            Image(systemName: activity.type.iconName)
                                .font(.caption)
                                .foregroundColor(activity.type.color)
                                .frame(width: 20)
                            
                            Text(activity.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(activity.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(team.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

// MARK: - Utility Components
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LoadingIndicator: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading more...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}

struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    
    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await onRefresh()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.orange : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Tab Extensions
extension SocialTab {
    var iconName: String {
        switch self {
        case .feed: return "house.fill"
        case .challenges: return "target"
        case .leaderboard: return "trophy.fill"
        case .teams: return "person.3.fill"
        }
    }
}

// MARK: - Enhanced Create Views
struct EnhancedCreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialService = SocialService.shared
    @State private var postContent = ""
    @State private var selectedWorkout: WorkoutData?
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingWorkoutPicker = false
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // User header
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: socialService.currentUser?.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.orange.gradient)
                            .overlay(
                                Text(socialService.currentUser?.name.prefix(1) ?? "U")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(socialService.currentUser?.name ?? "User")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Share with your community")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Content area
                ScrollView {
                    VStack(spacing: 20) {
                        // Text input
                        VStack(alignment: .leading, spacing: 12) {
                            TextView(text: $postContent, placeholder: "What's on your mind?")
                                .frame(minHeight: 120)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Attached workout
                        if let workout = selectedWorkout {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Workout Attached")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Button("Remove") {
                                        selectedWorkout = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                
                                EnhancedWorkoutCard(workoutData: workout)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Attached images
                        if !selectedImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(selectedImages.count) Photo\(selectedImages.count == 1 ? "" : "s")")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Button("Edit") {
                                        showingImagePicker = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                }
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        selectedImages.remove(at: index)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Color.black.opacity(0.5))
                                                            .clipShape(Circle())
                                                    }
                                                    .padding(4)
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: { showingImagePicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.title3)
                            Text("Photo")
                                .font(.subheadline)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Button(action: { showingWorkoutPicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.run")
                                .font(.title3)
                            Text("Workout")
                                .font(.subheadline)
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createPost) {
                        if isPosting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
        }
    }
    
    private func createPost() {
        // Implementation for creating post
        isPosting = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPosting = false
            dismiss()
        }
    }
}

struct TextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.clear
        textView.delegate = context.coordinator
        textView.text = placeholder
        textView.textColor = UIColor.placeholderText
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty && uiView.textColor != UIColor.placeholderText {
            uiView.text = placeholder
            uiView.textColor = UIColor.placeholderText
        } else if !text.isEmpty && uiView.textColor == UIColor.placeholderText {
            uiView.text = text
            uiView.textColor = UIColor.label
        } else if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: TextView
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.placeholderText {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor != UIColor.placeholderText {
                parent.text = textView.text
            }
        }
    }
}

// MARK: - Placeholder Views for Missing Components
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("User Profile View")
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

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Notifications View")
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct MessagesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Messages View")
                .navigationTitle("Messages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
