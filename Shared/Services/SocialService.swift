//
//  SocialService.swift
//  ShuttlX
//
//  Real-time social features and community integration service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CloudKit
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
    
    private let cloudKitManager: CloudKitManager
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
    
    init(cloudKitManager: CloudKitManager, healthManager: HealthManager) {
        self.cloudKitManager = cloudKitManager
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
        currentUserProfile = profile
        
        try await saveUserProfile(profile)
        await loadInitialSocialData()
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
        
        currentUserProfile = profile
        try await saveUserProfile(profile)
    }
    
    func loadUserProfile(_ userId: UUID) async throws -> UserProfile {
        // Check cache first
        if let cachedProfile = profileCache[userId] {
            return cachedProfile
        }
        
        // Load from CloudKit
        let predicate = NSPredicate(format: "recordName == %@", userId.uuidString)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let records = try await cloudKitManager.performQuery(query)
            guard let record = records.first else {
                throw SocialError.userNotFound
            }
            
            let profile = try parseUserProfile(from: record)
            profileCache[userId] = profile
            return profile
            
        } catch {
            throw SocialError.loadError(error.localizedDescription)
        }
    }
    
    // MARK: - Follow System
    
    func followUser(_ userId: UUID) async throws {
        guard let currentUser = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        // Create follow relationship
        let follow = FollowRelationship(
            id: UUID(),
            followerId: currentUser.id,
            followingId: userId,
            createdDate: Date()
        )
        
        try await saveFollowRelationship(follow)
        
        // Update counts
        currentUserProfile?.followingCount += 1
        
        // Send notification to followed user
        await sendNotification(
            to: userId,
            type: .follow,
            message: "\(currentUser.displayName) started following you"
        )
        
        // Refresh followed users
        await loadFollowedUsers()
    }
    
    func unfollowUser(_ userId: UUID) async throws {
        guard let currentUser = currentUserProfile else {
            throw SocialError.noUserProfile
        }
        
        // Remove follow relationship
        try await removeFollowRelationship(followerId: currentUser.id, followingId: userId)
        
        // Update counts
        currentUserProfile?.followingCount -= 1
        
        // Remove from followed users
        followedUsers.removeAll { $0.id == userId }
    }
    
    func blockUser(_ userId: UUID) async throws {
        // Add to blocked users
        blockedUsers.append(userId)
        
        // Remove from followers and following
        try await unfollowUser(userId)
        
        // Hide posts from this user
        feedPosts.removeAll { $0.authorId == userId }
        
        // Save blocked status
        try await saveBlockedUsers()
    }
    
    // MARK: - Feed Management
    
    func loadFeed(limit: Int = 20, offset: Int = 0) async throws {
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        
        // Load posts from followed users and public posts
        let predicate = NSPredicate(format: "visibility == %@ OR authorId IN %@", 
                                   PostVisibility.public_.rawValue,
                                   followedUsers.map { $0.id.uuidString })
        
        let query = CKQuery(recordType: "FeedPost", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let records = try await cloudKitManager.performQuery(query)
            let posts = try records.compactMap { try parseFeedPost(from: $0) }
            
            if offset == 0 {
                feedPosts = posts
            } else {
                feedPosts.append(contentsOf: posts)
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
        
        try await saveFeedPost(updatedPost)
        
        // Add to local feed if visible
        if visibility == .public_ || visibility == .followers {
            feedPosts.insert(updatedPost, at: 0)
        }
        
        // Update user stats
        currentUserProfile?.postsCount += 1
    }
    
    func likePost(_ postId: UUID) async throws {
        guard let index = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw SocialError.postNotFound
        }
        
        feedPosts[index].isLiked.toggle()
        if feedPosts[index].isLiked {
            feedPosts[index].likesCount += 1
        } else {
            feedPosts[index].likesCount -= 1
        }
        
        // Save like status to CloudKit
        try await saveLikeStatus(postId: postId, isLiked: feedPosts[index].isLiked)
        
        // Send notification if liked
        if feedPosts[index].isLiked {
            await sendNotification(
                to: feedPosts[index].authorId,
                type: .like,
                entityId: postId,
                message: "liked your post"
            )
        }
    }
    
    func savePost(_ postId: UUID) async throws {
        guard let index = feedPosts.firstIndex(where: { $0.id == postId }) else {
            throw SocialError.postNotFound
        }
        
        feedPosts[index].isSaved.toggle()
        
        if feedPosts[index].isSaved {
            savedPosts.append(feedPosts[index])
        } else {
            savedPosts.removeAll { $0.id == postId }
        }
        
        // Save to CloudKit
        try await saveSavedPostStatus(postId: postId, isSaved: feedPosts[index].isSaved)
    }
    
    // MARK: - Challenge Management
    
    func createChallenge(_ challenge: Challenge) async throws {
        var newChallenge = challenge
        newChallenge.participantCount = 1 // Creator auto-joins
        
        try await saveChallenge(newChallenge)
        challenges.append(newChallenge)
        activeChallenges.append(newChallenge)
    }
    
    func joinChallenge(_ challengeId: UUID) async throws {
        guard let index = challenges.firstIndex(where: { $0.id == challengeId }) else {
            throw SocialError.challengeNotFound
        }
        
        challenges[index].participantCount += 1
        
        // Create progress tracking
        let progress = ChallengeProgress(
            userId: currentUserProfile?.id ?? UUID(),
            challengeId: challengeId,
            currentValue: 0.0,
            completedSessions: 0,
            lastUpdateDate: Date(),
            isCompleted: false,
            completionDate: nil,
            ranking: nil
        )
        
        challenges[index].myProgress = progress
        
        if !activeChallenges.contains(where: { $0.id == challengeId }) {
            activeChallenges.append(challenges[index])
        }
        
        try await saveChallengeProgress(progress)
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
        
        activeChallenges[challengeIndex].myProgress = progress
        activeChallenges[challengeIndex].progress = progressPercent
        
        try await saveChallengeProgress(progress)
    }
    
    // MARK: - Team Management
    
    func createTeam(_ team: Team) async throws {
        var newTeam = team
        newTeam.memberCount = 1 // Creator is first member
        
        try await saveTeam(newTeam)
        teams.append(newTeam)
        myTeams.append(newTeam)
    }
    
    func joinTeam(_ teamId: UUID) async throws {
        guard let index = discoveredTeams.firstIndex(where: { $0.id == teamId }) else {
            throw SocialError.teamNotFound
        }
        
        var team = discoveredTeams[index]
        team.memberCount += 1
        
        // Create team membership
        let membership = TeamMember(
            id: UUID(),
            userId: currentUserProfile?.id ?? UUID(),
            teamId: teamId,
            username: currentUserProfile?.username ?? "",
            displayName: currentUserProfile?.displayName ?? "",
            avatarURL: currentUserProfile?.avatarURL,
            joinDate: Date(),
            role: .member,
            isActive: true,
            teamWorkouts: 0,
            teamDistance: 0.0,
            teamCalories: 0.0,
            contributionScore: 0.0,
            lastActiveDate: Date()
        )
        
        try await saveTeamMembership(membership)
        
        // Move to my teams
        discoveredTeams.remove(at: index)
        myTeams.append(team)
    }
    
    // MARK: - Notification Management
    
    func sendNotification(to userId: UUID, type: NotificationType, 
                         entityId: UUID? = nil, message: String) async {
        guard let currentUser = currentUserProfile else { return }
        
        let notification = SocialNotification(
            id: UUID(),
            userId: userId,
            actorId: currentUser.id,
            actorName: currentUser.displayName,
            actorAvatarURL: currentUser.avatarURL ?? "",
            type: type,
            entityId: entityId,
            message: message,
            timestamp: Date(),
            isRead: false,
            actionURL: nil
        )
        
        do {
            try await saveNotification(notification)
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
        
        try await updateNotificationReadStatus(notificationId, isRead: true)
    }
    
    func markAllNotificationsAsRead() async throws {
        for i in notifications.indices {
            if !notifications[i].isRead {
                notifications[i].isRead = true
            }
        }
        
        unreadNotificationCount = 0
        
        try await updateAllNotificationsReadStatus()
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
            
            try? await saveUserProfile(profile)
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
        // Implementation for loading followed users
    }
    
    private func loadBadges() async {
        // Implementation for loading available and earned badges
    }
    
    private func loadNotifications() async throws {
        // Implementation for loading user notifications
    }
    
    private func loadChallenges() async throws {
        // Implementation for loading challenges
    }
    
    private func loadTeams() async throws {
        // Implementation for loading teams
    }
    
    private func loadConversations() async throws {
        // Implementation for loading conversations
    }
    
    private func updateOnlineStatus() async {
        // Update last seen timestamp
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
        try? await saveUserProfile(profile)
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
    
    // MARK: - CloudKit Save Methods
    
    private func saveUserProfile(_ profile: UserProfile) async throws {
        let record = profile.toCKRecord()
        try await cloudKitManager.save(record)
        profileCache[profile.id] = profile
    }
    
    private func saveFeedPost(_ post: FeedPost) async throws {
        let record = post.toCKRecord()
        try await cloudKitManager.save(record)
    }
    
    private func saveChallenge(_ challenge: Challenge) async throws {
        let record = challenge.toCKRecord()
        try await cloudKitManager.save(record)
    }
    
    private func saveTeam(_ team: Team) async throws {
        let record = team.toCKRecord()
        try await cloudKitManager.save(record)
    }
    
    private func saveFollowRelationship(_ follow: FollowRelationship) async throws {
        let record = CKRecord(recordType: "FollowRelationship", recordID: CKRecord.ID(recordName: follow.id.uuidString))
        record["followerId"] = follow.followerId.uuidString
        record["followingId"] = follow.followingId.uuidString
        record["createdDate"] = follow.createdDate
        try await cloudKitManager.save(record)
    }
    
    private func saveChallengeProgress(_ progress: ChallengeProgress) async throws {
        let record = CKRecord(recordType: "ChallengeProgress", recordID: CKRecord.ID(recordName: progress.userId.uuidString + "_" + progress.challengeId.uuidString))
        record["userId"] = progress.userId.uuidString
        record["challengeId"] = progress.challengeId.uuidString
        record["currentValue"] = progress.currentValue
        record["completedSessions"] = progress.completedSessions
        record["lastUpdateDate"] = progress.lastUpdateDate
        record["isCompleted"] = progress.isCompleted
        if let completionDate = progress.completionDate {
            record["completionDate"] = completionDate
        }
        try await cloudKitManager.save(record)
    }
    
    private func saveTeamMembership(_ membership: TeamMember) async throws {
        let record = CKRecord(recordType: "TeamMember", recordID: CKRecord.ID(recordName: membership.id.uuidString))
        record["userId"] = membership.userId.uuidString
        record["teamId"] = membership.teamId.uuidString
        record["username"] = membership.username
        record["displayName"] = membership.displayName
        record["joinDate"] = membership.joinDate
        record["role"] = membership.role.rawValue
        record["isActive"] = membership.isActive
        try await cloudKitManager.save(record)
    }
    
    private func saveNotification(_ notification: SocialNotification) async throws {
        let record = CKRecord(recordType: "SocialNotification", recordID: CKRecord.ID(recordName: notification.id.uuidString))
        record["userId"] = notification.userId.uuidString
        record["actorId"] = notification.actorId.uuidString
        record["type"] = notification.type.rawValue
        record["message"] = notification.message
        record["timestamp"] = notification.timestamp
        record["isRead"] = notification.isRead
        try await cloudKitManager.save(record)
    }
    
    private func saveLikeStatus(postId: UUID, isLiked: Bool) async throws {
        // Implementation for saving like status
    }
    
    private func saveSavedPostStatus(postId: UUID, isSaved: Bool) async throws {
        // Implementation for saving saved post status
    }
    
    private func saveBlockedUsers() async throws {
        // Implementation for saving blocked users list
    }
    
    private func removeFollowRelationship(followerId: UUID, followingId: UUID) async throws {
        // Implementation for removing follow relationship
    }
    
    private func updateNotificationReadStatus(_ notificationId: UUID, isRead: Bool) async throws {
        // Implementation for updating notification read status
    }
    
    private func updateAllNotificationsReadStatus() async throws {
        // Implementation for marking all notifications as read
    }
    
    // MARK: - CloudKit Parse Methods
    
    private func parseUserProfile(from record: CKRecord) throws -> UserProfile {
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        var profile = UserProfile(
            username: record["username"] as? String ?? "",
            displayName: record["displayName"] as? String ?? ""
        )
        profile.id = id
        profile.bio = record["bio"] as? String ?? ""
        profile.location = record["location"] as? String ?? ""
        profile.joinDate = record["joinDate"] as? Date ?? Date()
        profile.isPrivate = record["isPrivate"] as? Bool ?? false
        profile.totalWorkouts = record["totalWorkouts"] as? Int ?? 0
        profile.totalDistance = record["totalDistance"] as? Double ?? 0
        profile.totalCalories = record["totalCalories"] as? Double ?? 0
        profile.currentStreak = record["currentStreak"] as? Int ?? 0
        profile.longestStreak = record["longestStreak"] as? Int ?? 0
        
        if let levelString = record["level"] as? String {
            profile.level = UserLevel(rawValue: levelString) ?? .beginner
        }
        
        profile.followersCount = record["followersCount"] as? Int ?? 0
        profile.followingCount = record["followingCount"] as? Int ?? 0
        profile.postsCount = record["postsCount"] as? Int ?? 0
        
        return profile
    }
    
    private func parseFeedPost(from record: CKRecord) throws -> FeedPost {
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let authorId = UUID(uuidString: record["authorId"] as? String ?? "") ?? UUID()
        
        var post = FeedPost(
            authorId: authorId,
            userName: record["userName"] as? String ?? "",
            content: record["content"] as? String ?? ""
        )
        post.id = id
        post.timestamp = record["timestamp"] as? Date ?? Date()
        post.likesCount = record["likesCount"] as? Int ?? 0
        post.commentsCount = record["commentsCount"] as? Int ?? 0
        
        if let visibilityString = record["visibility"] as? String {
            post.visibility = PostVisibility(rawValue: visibilityString) ?? .public_
        }
        
        return post
    }
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
