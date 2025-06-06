//
//  SocialService.swift
//  ShuttlX
//
//  Real-time social features and community integration service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine
import Network

/// Comprehensive social service for managing community features, real-time interactions, and user engagement
@MainActor
class SocialService: ObservableObject {
    
    // MARK: - Published Properties
    
    // User Profile
    @Published var currentUserProfile: UserProfile?
    @Published var followedUsers: [UserProfile] = []
    @Published var followers: [UserProfile] = []
    @Published var blockedUsers: [UUID] = []
    
    // Feed & Posts
    @Published var feedPosts: [FeedPost] = []
    @Published var userPosts: [FeedPost] = []
    @Published var savedPosts: [FeedPost] = []
    @Published var isLoadingFeed = false
    
    // Social Interactions
    @Published var notifications: [SocialNotification] = []
    @Published var unreadNotificationCount = 0
    @Published var conversations: [Conversation] = []
    @Published var unreadMessageCount = 0
    
    // Community Features
    @Published var challenges: [Challenge] = []
    @Published var activeChallenges: [Challenge] = []
    @Published var teams: [Team] = []
    @Published var myTeams: [Team] = []
    @Published var discoveredTeams: [Team] = []
    
    // Leaderboards
    @Published var globalLeaderboard: [LeaderboardEntry] = []
    @Published var friendsLeaderboard: [LeaderboardEntry] = []
    @Published var teamLeaderboard: [LeaderboardEntry] = []
    
    // Achievements & Badges
    @Published var availableBadges: [Badge] = []
    @Published var earnedBadges: [Badge] = []
    @Published var recentAchievements: [Achievement] = []
    
    // Network & Connection
    @Published var isOnline = true
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private let apiService: APIService
    private let healthManager: HealthManager
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Real-time sync
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 30 // 30 seconds
    
    // Caching
    private var feedCache: [String: Any] = [:]
    private var profileCache: [UUID: UserProfile] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(apiService: APIService, healthManager: HealthManager) {
        self.apiService = apiService
        self.healthManager = healthManager
        
        setupNetworkMonitoring()
        setupRealTimeSync()
        setupNotificationObservers()
    }
    
    deinit {
        syncTimer?.invalidate()
        networkMonitor.cancel()
    }
    
    // MARK: - Setup Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.connectionStatus = path.status == .satisfied ? .connected : .disconnected
                
                if path.status == .satisfied {
                    Task {
                        await self?.syncAllData()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupRealTimeSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard self?.isOnline == true else { return }
            
            Task {
                await self?.syncNotifications()
                await self?.syncMessages()
                await self?.updateOnlineStatus()
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen to health updates for social sharing
        healthManager.$currentHealthMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                Task {
                    await self?.updateUserStats(with: metrics)
                }
            }
            .store(in: &cancellables)
        
        // Listen to workout completions for automatic posts
        NotificationCenter.default.publisher(for: .workoutCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let workout = notification.object as? TrainingSession {
                    Task {
                        await self?.handleWorkoutCompletion(workout)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Profile Management
    
    func createUserProfile(username: String, displayName: String) async throws {
        let profile = UserProfile(username: username, displayName: displayName)
        
        do {
            let response = try await apiService.createUserProfile(profile)
            currentUserProfile = response.user
            await loadInitialSocialData()
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func updateUserProfile(_ updates: [String: Any]) async throws {
        guard var profile = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        // Apply updates
        if let username = updates["username"] as? String {
            profile.username = username
        }
        if let displayName = updates["displayName"] as? String {
            profile.displayName = displayName
        }
        if let bio = updates["bio"] as? String {
            profile.bio = bio
        }
        if let location = updates["location"] as? String {
            profile.location = location
        }
        if let isPrivate = updates["isPrivate"] as? Bool {
            profile.isPrivate = isPrivate
        }
        
        do {
            let response = try await apiService.updateUserProfile(profile)
            currentUserProfile = response.user
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func loadUserProfile(_ userId: UUID) async throws -> UserProfile {
        // Check cache first
        if let cachedProfile = profileCache[userId] {
            return cachedProfile
        }
        
        do {
            let response = try await apiService.getUserProfile(userId: userId)
            let profile = response.user
            profileCache[userId] = profile
            return profile
        } catch {
            throw SocialError.userNotFound
        }
    }
    
    // MARK: - Follow System
    
    func followUser(_ userId: UUID) async throws {
        guard let currentUser = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        do {
            let response = try await apiService.followUser(userId: userId)
            
            // Update local state
            currentUserProfile?.followingCount += 1
            
            // Reload followed users to get updated list
            await loadFollowedUsers()
            
            // Send notification through API
            try await apiService.sendNotification(
                to: userId,
                type: .follow,
                message: "\(currentUser.displayName) started following you"
            )
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func unfollowUser(_ userId: UUID) async throws {
        guard let currentUser = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        do {
            try await apiService.unfollowUser(userId: userId)
            
            // Update local state
            currentUserProfile?.followingCount -= 1
            followedUsers.removeAll { $0.id == userId }
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func blockUser(_ userId: UUID) async throws {
        do {
            try await apiService.blockUser(userId: userId)
            
            // Add to blocked users locally
            blockedUsers.append(userId)
            
            // Remove from followers and following
            try await unfollowUser(userId)
            
            // Hide posts from this user
            feedPosts.removeAll { $0.authorId == userId }
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    // MARK: - Feed Management
    
    func loadFeed(limit: Int = 20, offset: Int = 0) async throws {
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        
        do {
            let response = try await apiService.getFeed(page: offset / limit, limit: limit)
            
            if offset == 0 {
                feedPosts = response.posts
            } else {
                feedPosts.append(contentsOf: response.posts)
            }
        } catch {
            throw SocialError.loadError(error.localizedDescription)
        }
    }
    
    func createPost(content: String, workoutSummary: WorkoutSummary? = nil, 
                   imageURLs: [String] = [], visibility: PostVisibility = .public_) async throws {
        guard let currentUser = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        let post = FeedPost(
            authorId: currentUser.id,
            userName: currentUser.displayName,
            content: content
        )
        
        var updatedPost = post
        updatedPost.workoutSummary = workoutSummary
        updatedPost.imageURLs = imageURLs
        updatedPost.visibility = visibility
        updatedPost.userLevel = currentUser.level
        
        do {
            let response = try await apiService.createPost(updatedPost)
            
            // Add to local feed if visible
            if visibility == .public_ || visibility == .followers {
                feedPosts.insert(response.post, at: 0)
            }
            
            // Update user stats
            currentUserProfile?.postsCount += 1
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func likePost(_ postId: UUID) async throws {
        guard let index = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw SocialError.postNotFound
        }
        
        let wasLiked = feedPosts[index].isLiked
        
        do {
            if wasLiked {
                try await apiService.unlikePost(postId: postId)
                feedPosts[index].isLiked = false
                feedPosts[index].likesCount -= 1
            } else {
                try await apiService.likePost(postId: postId)
                feedPosts[index].isLiked = true
                feedPosts[index].likesCount += 1
                
                // Send notification if liked
                try await apiService.sendNotification(
                    to: feedPosts[index].authorId,
                    type: .like,
                    entityId: postId,
                    message: "liked your post"
                )
            }
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    // MARK: - Challenge Management
    
    func createChallenge(_ challenge: Challenge) async throws {
        var newChallenge = challenge
        newChallenge.participantCount = 1 // Creator auto-joins
        
        do {
            let response = try await apiService.createChallenge(newChallenge)
            challenges.append(response.challenge)
            activeChallenges.append(response.challenge)
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func joinChallenge(_ challengeId: UUID) async throws {
        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw SocialError.challengeNotFound
        }
        
        do {
            let response = try await apiService.joinChallenge(challengeId: challengeId)
            
            // Update local state
            challenges[index].participantCount += 1
            challenges[index].myProgress = response.progress
            
            if !activeChallenges.contains(where: { $0.id == challengeId }) {
                activeChallenges.append(challenges[index])
            }
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func updateChallengeProgress(_ challengeId: UUID, value: Double) async throws {
        guard let challengeIndex = activeChallenges.firstIndex(where: { $0.id == challengeId }) else {
            throw SocialError.challengeNotFound
        }
        
        guard var progress = activeChallenges[challengeIndex].myProgress else {
            throw SocialError.challengeProgressNotFound
        }
        
        progress.currentValue += value
        progress.lastUpdateDate = Date()
        progress.completedSessions += 1
        
        // Check completion
        let challenge = activeChallenges[challengeIndex]
        let targetValue = challenge.requirements.targetValue
        let progressPercent = min(progress.currentValue / targetValue, 1.0)
        
        if progressPercent >= 1.0 && !progress.isCompleted {
            progress.isCompleted = true
            progress.completionDate = Date()
            
            // Award badge and experience
            await awardChallengeCompletion(challenge)
        }
        
        do {
            let response = try await apiService.updateChallengeProgress(challengeId: challengeId, progress: progress)
            
            activeChallenges[challengeIndex].myProgress = response.progress
            activeChallenges[challengeIndex].progress = progressPercent
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    // MARK: - Team Management
    
    func createTeam(_ team: Team) async throws {
        var newTeam = team
        newTeam.memberCount = 1 // Creator is first member
        
        do {
            let response = try await apiService.createTeam(newTeam)
            teams.append(response.team)
            myTeams.append(response.team)
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    func joinTeam(_ teamId: UUID) async throws {
        guard let index = discoveredTeams.firstIndex(where: { $0.id == teamId }) else {
            throw SocialError.teamNotFound
        }
        
        do {
            let response = try await apiService.joinTeam(teamId: teamId)
            
            // Update local state
            var team = discoveredTeams[index]
            team.memberCount += 1
            
            // Move to my teams
            discoveredTeams.remove(at: index)
            myTeams.append(team)
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    // MARK: - Notification Management
    
    func sendNotification(to userId: UUID, type: NotificationType, 
                         entityId: UUID? = nil, message: String) async {
        do {
            try await apiService.sendNotification(
                to: userId,
                                type: type,
                entityId: entityId,
                message: message
            )
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    func markNotificationAsRead(_ notificationId: UUID) async throws {
        guard let index = notifications.firstIndex(where: { $0.id == notificationId }) else {
            return
        }
        
        notifications[index].isRead = true
        unreadNotificationCount = max(0, unreadNotificationCount - 1)
        
        try await apiService.markNotificationAsRead(notificationId: notificationId)
    }
    
    func markAllNotificationsAsRead() async throws {
        for i in notifications.indices {
            if !notifications[i].isRead {
                notifications[i].isRead = true
            }
        }
        
        unreadNotificationCount = 0
        
        try await apiService.markAllNotificationsAsRead()
    }
    
    func savePost(_ postId: UUID) async throws {
        guard let index = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw SocialError.postNotFound
        }
        
        let wasSaved = feedPosts[index].isSaved
        
        do {
            if wasSaved {
                try await apiService.unsavePost(postId: postId)
                feedPosts[index].isSaved = false
                savedPosts.removeAll { $0.id == postId }
            } else {
                try await apiService.savePost(postId: postId)
                feedPosts[index].isSaved = true
                savedPosts.append(feedPosts[index])
            }
        } catch {
            throw SocialError.saveError(error.localizedDescription)
        }
    }
    
    // MARK: - Leaderboard Management
    
    func loadGlobalLeaderboard() async throws {
        let response = try await apiService.getGlobalLeaderboard()
        globalLeaderboard = response.entries
    }
    
    func loadFriendsLeaderboard() async throws {
        let response = try await apiService.getFriendsLeaderboard()
        friendsLeaderboard = response.entries
    }
    
    func loadTeamLeaderboard(_ teamId: UUID) async throws {
        let response = try await apiService.getTeamLeaderboard(teamId: teamId)
        teamLeaderboard = response.entries
    }
    
    func loadUserPosts(userId: UUID) async throws {
        let response = try await apiService.getUserPosts(userId: userId)
        if userId == currentUserProfile?.id {
            userPosts = response.posts
        }
    }
    
    func loadSavedPosts() async throws {
        let response = try await apiService.getSavedPosts()
        savedPosts = response.posts
    }
    
    func searchUsers(query: String) async throws -> [UserProfile] {
        let response = try await apiService.searchUsers(query: query)
        return response.users
    }
    
    func searchTeams(query: String) async throws -> [Team] {
        let response = try await apiService.searchTeams(query: query)
        return response.teams
    }
    
    func searchChallenges(query: String) async throws -> [Challenge] {
        let response = try await apiService.searchChallenges(query: query)
        return response.challenges
    }
    
    func addComment(to postId: UUID, content: String) async throws {
        guard let postIndex = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw SocialError.postNotFound
        }
        
        let response = try await apiService.addComment(postId: postId, content: content)
        feedPosts[postIndex].commentsCount += 1
    }
    
    func getComments(for postId: UUID) async throws -> [PostComment] {
        let response = try await apiService.getComments(postId: postId)
        return response.comments
    }
    
    // MARK: - Real-time Sync
    
    func syncAllData() async {
        guard isOnline else { return }
        
        async let feedSync: Void = syncFeed()
        async let notificationSync: Void = syncNotifications()
        async let challengeSync: Void = syncChallenges()
        async let teamSync: Void = syncTeams()
        
        _ = await [feedSync, notificationSync, challengeSync, teamSync]
        
        lastSyncDate = Date()
    }
    
    private func syncFeed() async {
        do {
            try await loadFeed()
        } catch {
            print("Failed to sync feed: \(error)")
        }
    }
    
    private func syncNotifications() async {
        do {
            try await loadNotifications()
        } catch {
            print("Failed to sync notifications: \(error)")
        }
    }
    
    private func syncChallenges() async {
        do {
            try await loadChallenges()
        } catch {
            print("Failed to sync challenges: \(error)")
        }
    }
    
    private func syncTeams() async {
        do {
            try await loadTeams()
        } catch {
            print("Failed to sync teams: \(error)")
        }
    }
    
    private func syncMessages() async {
        do {
            try await loadConversations()
        } catch {
            print("Failed to sync messages: \(error)")
        }
    }
    
    // MARK: - Achievement System Integration
    
    private func awardChallengeCompletion(_ challenge: Challenge) async {
        guard let currentUser = currentUserProfile else { return }
        
        // Calculate experience points
        let baseXP = 100
        let difficultyMultiplier = challenge.difficultyLevel.experienceMultiplier
        let experiencePoints = Int(Double(baseXP) * difficultyMultiplier)
        
        // Award badge if available
        if let badge = challenge.badge {
            var earnedBadge = badge
            earnedBadge.earnedDate = Date()
            earnedBadges.append(earnedBadge)
        }
        
        // Check for level up
        await checkLevelUp(experienceGained: experiencePoints)
        
        // Send achievement notification
        await sendNotification(
            to: currentUser.id,
            type: .achievementEarned,
            message: "Challenge completed: \(challenge.title)"
        )
    }
    
    private func checkLevelUp(experienceGained: Int) async {
        guard var profile = currentUserProfile else { return }
        
        let totalExperience = profile.totalWorkouts + experienceGained
        let newLevel = UserLevel.allCases.last { $0.experienceRequired <= totalExperience } ?? .beginner
        
        if newLevel != profile.level {
            profile.level = newLevel
            currentUserProfile = profile
            
            // Award level up badge
            let levelBadge = Badge(
                id: UUID(),
                name: "Level \(newLevel.displayName)",
                description: "Reached \(newLevel.displayName) level",
                iconName: "star.fill",
                color: newLevel.color,
                rarity: .common,
                category: .milestone,
                requirements: BadgeRequirements(
                    targetValue: Double(newLevel.experienceRequired),
                    metric: "experience",
                    description: "Reach \(newLevel.displayName) level"
                ),
                earnedDate: Date(),
                progress: 1.0
            )
            
            earnedBadges.append(levelBadge)
            
            do {
                let response = try await apiService.updateUserProfile(profile)
                currentUserProfile = response.user
            } catch {
                print("Failed to save level up: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialSocialData() async {
        async let feedLoad: Void = syncFeed()
        async let notificationLoad: Void = syncNotifications()
        async let challengeLoad: Void = syncChallenges()
        async let teamLoad: Void = syncTeams()
        async let followLoad: Void = loadFollowedUsers()
        async let badgeLoad: Void = loadBadges()
        
        _ = await [feedLoad, notificationLoad, challengeLoad, teamLoad, followLoad, badgeLoad]
    }
    
    private func loadFollowedUsers() async {
        do {
            let response = try await apiService.getFollowedUsers()
            followedUsers = response.users
        } catch {
            print("Failed to load followed users: \(error)")
        }
    }
    
    private func loadBadges() async {
        do {
            let response = try await apiService.getUserBadges()
            availableBadges = response.available
            earnedBadges = response.earned
        } catch {
            print("Failed to load badges: \(error)")
        }
    }
    
    private func loadNotifications() async throws {
        let response = try await apiService.getNotifications()
        notifications = response.notifications
        unreadNotificationCount = notifications.filter { !$0.isRead }.count
    }
    
    private func loadChallenges() async throws {
        let response = try await apiService.getChallenges()
        challenges = response.challenges
        activeChallenges = challenges.filter { challenge in
            challenge.myProgress?.isCompleted == false
        }
    }
    
    private func loadTeams() async throws {
        async let myTeamsTask = apiService.getMyTeams()
        async let discoveredTeamsTask = apiService.getDiscoverableTeams()
        
        let (myTeamsResponse, discoveredTeamsResponse) = try await (myTeamsTask, discoveredTeamsTask)
        
        myTeams = myTeamsResponse.teams
        discoveredTeams = discoveredTeamsResponse.teams
        teams = myTeams + discoveredTeams
    }
    
    private func loadConversations() async throws {
        let response = try await apiService.getConversations()
        conversations = response.conversations
        unreadMessageCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    private func updateOnlineStatus() async {
        do {
            try await apiService.updateLastSeen()
        } catch {
            print("Failed to update online status: \(error)")
        }
    }
    
    private func updateUserStats(with metrics: HealthMetrics) async {
        guard var profile = currentUserProfile else { return }
        
        // Update workout count when a workout is completed
        if metrics.workoutDuration > 0 {
            profile.totalWorkouts += 1
            profile.totalDistance += metrics.distanceCovered
            profile.totalCalories += metrics.activeEnergyBurned
        }
        
        currentUserProfile = profile
        
        do {
            let response = try await apiService.updateUserProfile(profile)
            currentUserProfile = response.user
        } catch {
            print("Failed to update user stats: \(error)")
        }
    }
    
    private func handleWorkoutCompletion(_ workout: TrainingSession) async {
        // Auto-create post for significant workouts
        if workout.duration > 600 { // 10 minutes
            let summary = WorkoutSummary(
                workoutType: SimpleWorkoutType.shuttleRun, // Convert from WorkoutConfiguration
                duration: workout.duration,
                caloriesBurned: workout.caloriesBurned ?? 0,
                distance: workout.totalDistance,
                averageHeartRate: workout.averageHeartRate,
                maxHeartRate: workout.maxHeartRate,
                achievements: workout.achievements.map { $0.title },
                personalBests: []
            )
            
            let content = generateWorkoutPostContent(summary)
            
            try? await createPost(
                content: content,
                workoutSummary: summary,
                visibility: .public_
            )
        }
        
        // Update challenge progress
        await updateChallengeProgressForWorkout(workout)
    }
    
    private func generateWorkoutPostContent(_ summary: WorkoutSummary) -> String {
        let duration = Int(summary.duration / 60)
        var content = "Just completed a \(duration)-minute \(summary.workoutType.displayName) workout! 💪"
        
        if let distance = summary.distance, distance > 0 {
            content += " Covered \(String(format: "%.1f", distance / 1000))km"
        }
        
        content += " and burned \(Int(summary.caloriesBurned)) calories!"
        
        if !summary.achievements.isEmpty {
            content += " \n🏆 " + summary.achievements.joined(separator: ", ")
        }
        
        return content
    }
    
    private func updateChallengeProgressForWorkout(_ workout: TrainingSession) async {
        for challenge in activeChallenges {
            guard let progress = challenge.myProgress, !progress.isCompleted else { continue }
            
            var updateValue: Double = 0
            
            switch challenge.requirements.metric {
            case .workouts:
                updateValue = 1
            case .distance:
                updateValue = workout.totalDistance ?? 0
            case .duration:
                updateValue = workout.duration / 60 // Convert to minutes
            case .calories:
                updateValue = workout.caloriesBurned ?? 0
            default:
                continue
            }
            
            if updateValue > 0 {
                try? await updateChallengeProgress(challenge.id, value: updateValue)
            }
        }
    }
    
    // MARK: - Helper Methods (Legacy CloudKit methods removed - now using APIService)
}

// MARK: - Error Types

enum SocialError: LocalizedError {
    case noUserProfile
    case userNotFound
    case postNotFound
    case challengeNotFound
    case challengeProgressNotFound
    case teamNotFound
    case loadError(String)
    case saveError(String)
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noUserProfile:
            return "No user profile found"
        case .userNotFound:
            return "User not found"
        case .postNotFound:
            return "Post not found"
        case .challengeNotFound:
            return "Challenge not found"
        case .challengeProgressNotFound:
            return "Challenge progress not found"
        case .teamNotFound:
            return "Team not found"
        case .loadError(let message):
            return "Load error: \(message)"
        case .saveError(let message):
            return "Save error: \(message)"
        case .networkError:
            return "Network connection error"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - Connection Status

enum ConnectionStatus {
    case connected
    case disconnected
    case connecting
    case error(String)
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Offline"
        case .connecting: return "Connecting"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var color: String {
        switch self {
        case .connected: return "green"
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .error: return "red"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
    static let achievementEarned = Notification.Name("achievementEarned")
    static let challengeCompleted = Notification.Name("challengeCompleted")
}
