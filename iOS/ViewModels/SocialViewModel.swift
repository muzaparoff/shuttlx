//
//  SocialViewModel.swift
//  ShuttlX
//
//  Enhanced Social Platform ViewModel with comprehensive community features
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SocialViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var feedPosts: [FeedPost] = []
    @Published var activeChallenges: [Challenge] = []
    @Published var availableChallenges: [Challenge] = []
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var myTeams: [Team] = []
    @Published var discoveredTeams: [Team] = []
    
    // UI State
    @Published var selectedLeaderboardType: LeaderboardType = .workouts
    @Published var selectedTimePeriod: TimePeriod = .thisWeek
    @Published var selectedCategory: ChallengeCategory = .all
    @Published var selectedTeamCategory: TeamCategory = .all
    
    // Modal states
    @Published var showingCreatePost = false
    @Published var showingCreateTeam = false
    @Published var showingCreateStory = false
    @Published var showAllChallenges = false
    @Published var showFullLeaderboard = false
    
    // Loading states
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var hasMorePosts = true
    
    // Search and filters
    @Published var teamSearchText = ""
    
    // Computed properties
    var filteredAvailableChallenges: [Challenge] {
        availableChallenges.filter { challenge in
            selectedCategory == .all || challenge.category == selectedCategory
        }.prefix(5).map { $0 }
    }
    
    var filteredDiscoveredTeams: [Team] {
        let filtered = discoveredTeams.filter { team in
            (selectedTeamCategory == .all || team.category == selectedTeamCategory) &&
            (teamSearchText.isEmpty || team.name.localizedCaseInsensitiveContains(teamSearchText))
        }
        return Array(filtered.prefix(10))
    }
    
    var currentUserRank: LeaderboardEntry? {
        leaderboardEntries.first { $0.userId == socialService.currentUser?.id }
    }
    
    var nextRankThreshold: Double? {
        guard let currentRank = currentUserRank,
              let currentIndex = leaderboardEntries.firstIndex(where: { $0.id == currentRank.id }),
              currentIndex > 0 else { return nil }
        
        let nextEntry = leaderboardEntries[currentIndex - 1]
        return nextEntry.value
    }
    
    // MARK: - Services
    private let socialService: SocialService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(socialService: SocialService) {
        self.socialService = socialService
        setupObservers()
        bindToSocialService()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Listen for leaderboard changes
        Publishers.CombineLatest($selectedLeaderboardType, $selectedTimePeriod)
            .sink { [weak self] _, _ in
                Task {
                    await self?.refreshLeaderboard()
                }
            }
            .store(in: &cancellables)
        
        // Listen for challenge category changes
        $selectedCategory
            .sink { [weak self] _ in
                Task {
                    await self?.refreshChallenges()
                }
            }
            .store(in: &cancellables)
        
        // Listen for team category and search changes
        Publishers.CombineLatest($selectedTeamCategory, $teamSearchText)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task {
                    await self?.refreshTeams()
                }
            }
            .store(in: &cancellables)
    }
    
    private func bindToSocialService() {
        // Bind to social service data
        socialService.$feedPosts
            .receive(on: DispatchQueue.main)
            .assign(to: \.feedPosts, on: self)
            .store(in: &cancellables)
        
        socialService.$activeChallenges
            .receive(on: DispatchQueue.main)
            .assign(to: \.activeChallenges, on: self)
            .store(in: &cancellables)
        
        socialService.$availableChallenges
            .receive(on: DispatchQueue.main)
            .assign(to: \.availableChallenges, on: self)
            .store(in: &cancellables)
        
        socialService.$leaderboardEntries
            .receive(on: DispatchQueue.main)
            .assign(to: \.leaderboardEntries, on: self)
            .store(in: &cancellables)
        
        socialService.$myTeams
            .receive(on: DispatchQueue.main)
            .assign(to: \.myTeams, on: self)
            .store(in: &cancellables)
        
        socialService.$discoveredTeams
            .receive(on: DispatchQueue.main)
            .assign(to: \.discoveredTeams, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadSocialData() {
        Task {
            isLoading = true
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadFeedPosts() }
                group.addTask { await self.loadChallenges() }
                group.addTask { await self.loadLeaderboard() }
                group.addTask { await self.loadTeams() }
                group.addTask { await self.socialService.syncUserStats() }
            }
            
            isLoading = false
        }
    }
    
    private func loadFeedPosts() async {
        do {
            try await socialService.loadFeedPosts(limit: 20)
        } catch {
            print("Failed to load feed posts: \(error)")
        }
    }
    
    private func loadChallenges() async {
        do {
            try await socialService.loadChallenges()
        } catch {
            print("Failed to load challenges: \(error)")
        }
    }
    
    private func loadLeaderboard() async {
        do {
            try await socialService.loadLeaderboard(
                type: selectedLeaderboardType,
                period: selectedTimePeriod
            )
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
    }
    
    private func loadTeams() async {
        do {
            try await socialService.loadTeams()
        } catch {
            print("Failed to load teams: \(error)")
        }
    }
    
    // MARK: - Refresh Functions
    func refreshFeed() async {
        isRefreshing = true
        await loadFeedPosts()
        isRefreshing = false
    }
    
    func refreshChallenges() async {
        await loadChallenges()
    }
    
    func refreshLeaderboard() async {
        await loadLeaderboard()
    }
    
    func refreshTeams() async {
        await loadTeams()
    }
    
    func loadMorePosts() {
        guard hasMorePosts else { return }
        
        Task {
            do {
                let newPosts = try await socialService.loadMoreFeedPosts()
                hasMorePosts = newPosts.count >= 20
            } catch {
                print("Failed to load more posts: \(error)")
            }
        }
    }
    
    // MARK: - Feed Actions
    func toggleLike(for post: FeedPost) {
        Task {
            do {
                try await socialService.toggleLike(postId: post.id)
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } catch {
                print("Failed to toggle like: \(error)")
            }
        }
    }
    
    func showComments(for post: FeedPost) {
        // TODO: Implement comments view
        print("Show comments for post: \(post.id)")
    }
    
    func sharePost(_ post: FeedPost) {
        Task {
            do {
                try await socialService.sharePost(postId: post.id)
                
                // Show native share sheet
                let activityController = UIActivityViewController(
                    activityItems: [post.content],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityController, animated: true)
                }
            } catch {
                print("Failed to share post: \(error)")
            }
        }
    }
    
    func showUserProfile(_ user: UserProfile) {
        // TODO: Implement user profile navigation
        print("Show profile for user: \(user.name)")
    }
    
    // MARK: - Story Actions
    func viewStory(_ story: Story) {
        // TODO: Implement story viewer
        print("View story: \(story.id)")
    }
    
    // MARK: - Challenge Actions
    func joinChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await socialService.joinChallenge(challengeId: challenge.id)
                
                // Success feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                // Refresh challenges to update UI
                await refreshChallenges()
            } catch {
                print("Failed to join challenge: \(error)")
                
                // Error feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
    }
    
    func leaveChallenge(_ challenge: Challenge) {
        Task {
            do {
                try await socialService.leaveChallenge(challengeId: challenge.id)
                await refreshChallenges()
            } catch {
                print("Failed to leave challenge: \(error)")
            }
        }
    }
    
    func selectCategory(_ category: ChallengeCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedCategory = category
        }
    }
    
    func showChallengeDetails(_ challenge: Challenge) {
        // TODO: Implement challenge details view
        print("Show details for challenge: \(challenge.title)")
    }
    
    // MARK: - Team Actions
    func joinTeam(_ team: Team) {
        Task {
            do {
                try await socialService.joinTeam(teamId: team.id)
                
                // Success feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
                
                await refreshTeams()
            } catch {
                print("Failed to join team: \(error)")
                
                // Error feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
    }
    
    func leaveTeam(_ team: Team) {
        Task {
            do {
                try await socialService.leaveTeam(teamId: team.id)
                await refreshTeams()
            } catch {
                print("Failed to leave team: \(error)")
            }
        }
    }
    
    func requestToJoinTeam(_ team: Team) {
        Task {
            do {
                try await socialService.requestToJoinTeam(teamId: team.id)
                
                // Show confirmation
                print("Join request sent for team: \(team.name)")
            } catch {
                print("Failed to request team join: \(error)")
            }
        }
    }
    
    func viewTeamDetails(_ team: Team) {
        // TODO: Implement team details view
        print("View details for team: \(team.name)")
    }
    
    // MARK: - User Profile Actions
    func followUser(_ user: UserProfile) {
        Task {
            do {
                try await socialService.followUser(userId: user.id)
            } catch {
                print("Failed to follow user: \(error)")
            }
        }
    }
    
    func unfollowUser(_ user: UserProfile) {
        Task {
            do {
                try await socialService.unfollowUser(userId: user.id)
            } catch {
                print("Failed to unfollow user: \(error)")
            }
        }
    }
    
    // MARK: - Achievement Actions
    func shareAchievement(_ achievement: Achievement) {
        Task {
            do {
                try await socialService.shareAchievement(achievementId: achievement.id)
            } catch {
                print("Failed to share achievement: \(error)")
            }
        }
    }
    
    // MARK: - Notification Actions
    func markNotificationAsRead(_ notification: SocialNotification) {
        Task {
            do {
                try await socialService.markNotificationAsRead(notificationId: notification.id)
            } catch {
                print("Failed to mark notification as read: \(error)")
            }
        }
    }
    
    func clearAllNotifications() {
        Task {
            do {
                try await socialService.clearAllNotifications()
            } catch {
                print("Failed to clear notifications: \(error)")
            }
        }
    }
    
    // MARK: - Message Actions
    func sendMessage(to user: UserProfile, content: String) {
        Task {
            do {
                try await socialService.sendDirectMessage(
                    toUserId: user.id,
                    content: content
                )
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    func markConversationAsRead(_ conversation: Conversation) {
        Task {
            do {
                try await socialService.markConversationAsRead(conversationId: conversation.id)
            } catch {
                print("Failed to mark conversation as read: \(error)")
            }
        }
    }
    
    // MARK: - Analytics and Insights
    func trackViewEngagement(postId: String) {
        socialService.trackPostView(postId: postId)
    }
    
    func trackChallengeInteraction(challengeId: String, action: String) {
        socialService.trackChallengeInteraction(challengeId: challengeId, action: action)
    }
    
    func trackTeamInteraction(teamId: String, action: String) {
        socialService.trackTeamInteraction(teamId: teamId, action: action)
    }
}
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Feed
    
    func refreshFeed() async {
        await loadFeedPosts()
    }
    
    private func loadFeedPosts() async {
        // Simulate API call
        feedPosts = generateSampleFeedPosts()
    }
    
    func toggleLike(for post: FeedPost) {
        guard let index = feedPosts.firstIndex(where: { $0.id == post.id }) else { return }
        
        feedPosts[index].isLiked.toggle()
        if feedPosts[index].isLiked {
            feedPosts[index].likesCount += 1
        } else {
            feedPosts[index].likesCount -= 1
        }
    }
    
    func showComments(for post: FeedPost) {
        // TODO: Show comments view
        print("Show comments for post: \(post.id)")
    }
    
    func sharePost(_ post: FeedPost) {
        // TODO: Implement share functionality
        print("Share post: \(post.id)")
    }
    
    // MARK: - Challenges
    
    func refreshChallenges() async {
        await loadChallenges()
    }
    
    private func loadChallenges() async {
        // Simulate API call
        activeChallenges = generateSampleActiveChallenges()
        availableChallenges = generateSampleAvailableChallenges()
    }
    
    func joinChallenge(_ challenge: Challenge) {
        // Move from available to active
        if let index = availableChallenges.firstIndex(where: { $0.id == challenge.id }) {
            var newChallenge = availableChallenges.remove(at: index)
            newChallenge.participantCount += 1
            newChallenge.progress = 0.0
            activeChallenges.append(newChallenge)
        }
    }
    
    func leaveChallenge(_ challenge: Challenge) {
        // Move from active to available
        if let index = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
            var newChallenge = activeChallenges.remove(at: index)
            newChallenge.participantCount -= 1
            newChallenge.progress = 0.0
            availableChallenges.append(newChallenge)
        }
    }
    
    // MARK: - Leaderboard
    
    func refreshLeaderboard() async {
        await loadLeaderboard()
    }
    
    private func loadLeaderboard() async {
        // Simulate API call based on selected type and period
        leaderboardEntries = generateSampleLeaderboardEntries(
            type: selectedLeaderboardType,
            period: selectedTimePeriod
        )
    }
    
    // MARK: - Teams
    
    func refreshTeams() async {
        await loadTeams()
    }
    
    private func loadTeams() async {
        // Simulate API call
        myTeams = generateSampleMyTeams()
        discoveredTeams = generateSampleDiscoveredTeams()
    }
    
    func joinTeam(_ team: Team) {
        // Move from discovered to my teams
        if let index = discoveredTeams.firstIndex(where: { $0.id == team.id }) {
            var newTeam = discoveredTeams.remove(at: index)
            newTeam.memberCount += 1
            myTeams.append(newTeam)
        }
    }
    
    func viewTeam(_ team: Team) {
        // TODO: Show team detail view
        print("View team: \(team.name)")
    }
    
    // MARK: - Sample Data Generation
    
    private func generateSampleFeedPosts() -> [FeedPost] {
        return [
            FeedPost(
                id: UUID(),
                userName: "Sarah Johnson",
                userAvatarURL: "",
                content: "Just crushed my 20-meter shuttle run PR! 🔥 Managed 15.2 on the beep test today. Feeling stronger every day!",
                timestamp: Date().addingTimeInterval(-3600),
                likesCount: 24,
                commentsCount: 8,
                isLiked: false,
                workoutSummary: WorkoutSummary(
                    workoutType: .shuttleRun,
                    duration: 780,
                    caloriesBurned: 145,
                    distance: 2.1
                ),
                imageURL: nil
            ),
            FeedPost(
                id: UUID(),
                userName: "Mike Chen",
                userAvatarURL: "",
                content: "Morning HIIT session complete! Nothing beats starting the day with some high-intensity action. Who else is team morning workout? 💪",
                timestamp: Date().addingTimeInterval(-7200),
                likesCount: 31,
                commentsCount: 12,
                isLiked: true,
                workoutSummary: WorkoutSummary(
                    workoutType: .hiit,
                    duration: 1800,
                    caloriesBurned: 298,
                    distance: nil
                ),
                imageURL: nil
            ),
            FeedPost(
                id: UUID(),
                userName: "Emma Davis",
                userAvatarURL: "",
                content: "Tabata Tuesday is done! 4 minutes never felt so long 😅 But that's what makes it effective!",
                timestamp: Date().addingTimeInterval(-14400),
                likesCount: 18,
                commentsCount: 5,
                isLiked: false,
                workoutSummary: WorkoutSummary(
                    workoutType: .tabata,
                    duration: 240,
                    caloriesBurned: 89,
                    distance: nil
                ),
                imageURL: nil
            )
        ]
    }
    
    private func generateSampleActiveChallenges() -> [Challenge] {
        return [
            Challenge(
                id: UUID(),
                title: "100K Steps This Week",
                description: "Walk or run 100,000 steps in 7 days",
                iconName: "figure.walk",
                startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
                participantCount: 127,
                progress: 0.68
            ),
            Challenge(
                id: UUID(),
                title: "Daily Shuttle Challenge",
                description: "Complete at least one shuttle run workout every day for 30 days",
                iconName: "arrow.left.arrow.right",
                startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
                endDate: Calendar.current.date(byAdding: .day, value: 20, to: Date())!,
                participantCount: 89,
                progress: 0.33
            )
        ]
    }
    
    private func generateSampleAvailableChallenges() -> [Challenge] {
        return [
            Challenge(
                id: UUID(),
                title: "February Fitness Frenzy",
                description: "Burn 10,000 calories this month through any workout",
                iconName: "flame.fill",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
                participantCount: 234,
                progress: 0.0
            ),
            Challenge(
                id: UUID(),
                title: "Speed Demon Sprint",
                description: "Achieve your fastest 20m shuttle time",
                iconName: "bolt.fill",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
                participantCount: 56,
                progress: 0.0
            ),
            Challenge(
                id: UUID(),
                title: "Consistency King",
                description: "Work out 5 days a week for 4 weeks straight",
                iconName: "calendar",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 28, to: Date())!,
                participantCount: 178,
                progress: 0.0
            )
        ]
    }
    
    private func generateSampleLeaderboardEntries(type: LeaderboardType, period: TimePeriod) -> [LeaderboardEntry] {
        let baseEntries = [
            ("Alex Rodriguez", "New York, NY", ""),
            ("Jessica Park", "Los Angeles, CA", ""),
            ("David Kim", "Chicago, IL", ""),
            ("Maria Garcia", "Houston, TX", ""),
            ("James Wilson", "Phoenix, AZ", ""),
            ("Ashley Brown", "Philadelphia, PA", ""),
            ("Ryan Taylor", "San Antonio, TX", ""),
            ("Nicole Johnson", "San Diego, CA", ""),
            ("Chris Anderson", "Dallas, TX", ""),
            ("Lauren Martinez", "San Jose, CA", "")
        ]
        
        return baseEntries.enumerated().map { index, entry in
            let (name, location, avatar) = entry
            let baseScore = 1000 - (index * 50) + Int.random(in: -25...25)
            
            return LeaderboardEntry(
                id: UUID(),
                userName: name,
                userLocation: location,
                userAvatarURL: avatar,
                score: Double(baseScore),
                scoreType: type.scoreType,
                formattedScore: formatScore(Double(baseScore), for: type)
            )
        }
    }
    
    private func formatScore(_ score: Double, for type: LeaderboardType) -> String {
        switch type {
        case .workouts:
            return "\(Int(score))"
        case .distance:
            return String(format: "%.1f km", score / 100)
        case .calories:
            return "\(Int(score))"
        case .speed:
            return String(format: "%.2f m/s", score / 100)
        }
    }
    
    private func generateSampleMyTeams() -> [Team] {
        return [
            Team(
                id: UUID(),
                name: "Sprint Squad",
                description: "Elite sprinters pushing each other to new limits",
                iconName: "bolt.fill",
                memberCount: 12,
                activityLevel: .elite,
                averageWorkoutsPerWeek: 6.2
            ),
            Team(
                id: UUID(),
                name: "Morning Warriors",
                description: "Early birds who conquer their workouts before dawn",
                iconName: "sunrise.fill",
                memberCount: 28,
                activityLevel: .high,
                averageWorkoutsPerWeek: 4.8
            )
        ]
    }
    
    private func generateSampleDiscoveredTeams() -> [Team] {
        return [
            Team(
                id: UUID(),
                name: "Fitness Beginners",
                description: "Supportive community for those starting their fitness journey",
                iconName: "heart.fill",
                memberCount: 156,
                activityLevel: .moderate,
                averageWorkoutsPerWeek: 3.2
            ),
            Team(
                id: UUID(),
                name: "HIIT Enthusiasts",
                description: "High-intensity interval training lovers unite!",
                iconName: "flame.fill",
                memberCount: 89,
                activityLevel: .high,
                averageWorkoutsPerWeek: 5.1
            ),
            Team(
                id: UUID(),
                name: "Weekend Warriors",
                description: "Making the most of our weekend workout time",
                iconName: "calendar.badge.clock",
                memberCount: 203,
                activityLevel: .moderate,
                averageWorkoutsPerWeek: 2.8
            )
        ]
    }
}

// MARK: - Extensions

extension LeaderboardType {
    var scoreType: String {
        switch self {
        case .workouts: return "workouts"
        case .distance: return "km"
        case .calories: return "calories"
        case .speed: return "m/s"
        }
    }
}
