//
//  SocialModels.swift
//  ShuttlX
//
//  Social features and community integration models
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CloudKit

// MARK: - User Profile Models

struct UserProfile: Codable, Identifiable {
    let id: UUID
    var username: String
    var displayName: String
    var bio: String
    var location: String
    var avatarURL: String?
    var coverImageURL: String?
    var joinDate: Date
    var isPrivate: Bool
    var isVerified: Bool
    
    // Stats
    var totalWorkouts: Int
    var totalDistance: Double
    var totalCalories: Double
    var currentStreak: Int
    var longestStreak: Int
    var level: UserLevel
    
    // Social Stats
    var followersCount: Int
    var followingCount: Int
    var postsCount: Int
    var challengesCompleted: Int
    
    // Preferences
    var preferences: SocialPreferences
    var achievements: [Achievement]
    var badges: [Badge]
    
    init(username: String, displayName: String) {
        self.id = UUID()
        self.username = username
        self.displayName = displayName
        self.bio = ""
        self.location = ""
        self.avatarURL = nil
        self.coverImageURL = nil
        self.joinDate = Date()
        self.isPrivate = false
        self.isVerified = false
        self.totalWorkouts = 0
        self.totalDistance = 0.0
        self.totalCalories = 0.0
        self.currentStreak = 0
        self.longestStreak = 0
        self.level = .beginner
        self.followersCount = 0
        self.followingCount = 0
        self.postsCount = 0
        self.challengesCompleted = 0
        self.preferences = SocialPreferences()
        self.achievements = []
        self.badges = []
    }
}

struct SocialPreferences: Codable {
    var allowDirectMessages: Bool = true
    var allowChallengeInvites: Bool = true
    var allowTeamInvites: Bool = true
    var showOnlineStatus: Bool = true
    var shareWorkoutData: Bool = true
    var allowTagging: Bool = true
    var pushNotifications: PushNotificationSettings = PushNotificationSettings()
}

struct PushNotificationSettings: Codable {
    var likes: Bool = true
    var comments: Bool = true
    var follows: Bool = true
    var challenges: Bool = true
    var teamUpdates: Bool = true
    var achievements: Bool = true
    var workoutReminders: Bool = true
}

enum UserLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case elite = "elite"
    case professional = "professional"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "purple"
        case .elite: return "orange"
        case .professional: return "red"
        }
    }
    
    var experienceRequired: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 50
        case .advanced: return 200
        case .elite: return 500
        case .professional: return 1000
        }
    }
}

// MARK: - Feed Post Models

struct FeedPost: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    var userName: String
    var userAvatarURL: String
    var userLevel: UserLevel
    var content: String
    let timestamp: Date
    var editedAt: Date?
    
    // Engagement
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var isLiked: Bool = false
    var isSaved: Bool = false
    
    // Content
    var workoutSummary: WorkoutSummary?
    var imageURLs: [String]
    var videoURL: String?
    var location: PostLocation?
    var hashtags: [String]
    var mentions: [String]
    
    // Privacy & Moderation
    var visibility: PostVisibility
    var isReported: Bool = false
    var isHidden: Bool = false
    
    init(authorId: UUID, userName: String, content: String) {
        self.id = UUID()
        self.authorId = authorId
        self.userName = userName
        self.userAvatarURL = ""
        self.userLevel = .beginner
        self.content = content
        self.timestamp = Date()
        self.editedAt = nil
        self.likesCount = 0
        self.commentsCount = 0
        self.sharesCount = 0
        self.workoutSummary = nil
        self.imageURLs = []
        self.videoURL = nil
        self.location = nil
        self.hashtags = []
        self.mentions = []
        self.visibility = .public
    }
}

struct WorkoutSummary: Codable {
    let workoutType: SimpleWorkoutType
    let duration: TimeInterval
    let caloriesBurned: Double
    let distance: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let achievements: [String]
    let personalBests: [String]
}

struct PostLocation: Codable {
    let name: String
    let city: String
    let country: String
    let coordinates: PostCoordinate?
}

struct PostCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

enum PostVisibility: String, Codable, CaseIterable {
    case public_ = "public"
    case followers = "followers"
    case friends = "friends"
    case private_ = "private"
    
    var displayName: String {
        switch self {
        case .public_: return "Public"
        case .followers: return "Followers"
        case .friends: return "Friends"
        case .private_: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .public_: return "globe"
        case .followers: return "person.2"
        case .friends: return "heart"
        case .private_: return "lock"
        }
    }
}

// MARK: - Comment Models

struct Comment: Codable, Identifiable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    var authorName: String
    var authorAvatarURL: String
    var content: String
    let timestamp: Date
    var editedAt: Date?
    var likesCount: Int
    var isLiked: Bool = false
    var replies: [CommentReply]
    var isReported: Bool = false
    var isHidden: Bool = false
    
    init(postId: UUID, authorId: UUID, authorName: String, content: String) {
        self.id = UUID()
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorAvatarURL = ""
        self.content = content
        self.timestamp = Date()
        self.editedAt = nil
        self.likesCount = 0
        self.replies = []
    }
}

struct CommentReply: Codable, Identifiable {
    let id: UUID
    let commentId: UUID
    let authorId: UUID
    var authorName: String
    var content: String
    let timestamp: Date
    var likesCount: Int
    var isLiked: Bool = false
    
    init(commentId: UUID, authorId: UUID, authorName: String, content: String) {
        self.id = UUID()
        self.commentId = commentId
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.timestamp = Date()
        self.likesCount = 0
    }
}

// MARK: - Challenge Models

struct Challenge: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    var title: String
    var description: String
    var iconName: String
    let startDate: Date
    let endDate: Date
    var isActive: Bool
    
    // Requirements
    var requirements: ChallengeRequirements
    var difficultyLevel: ChallengeDifficulty
    var category: ChallengeCategory
    
    // Participation
    var participantCount: Int
    var maxParticipants: Int?
    var isPublic: Bool
    var inviteOnly: Bool
    
    // Progress
    var progress: Double // 0.0 to 1.0
    var myProgress: ChallengeProgress?
    
    // Rewards
    var rewards: ChallengeRewards
    var badge: Badge?
    
    init(title: String, description: String, requirements: ChallengeRequirements, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.creatorId = UUID() // Should be current user
        self.title = title
        self.description = description
        self.iconName = "target"
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = true
        self.requirements = requirements
        self.difficultyLevel = .medium
        self.category = .fitness
        self.participantCount = 0
        self.maxParticipants = nil
        self.isPublic = true
        self.inviteOnly = false
        self.progress = 0.0
        self.myProgress = nil
        self.rewards = ChallengeRewards()
    }
}

struct ChallengeRequirements: Codable {
    var targetValue: Double
    var metric: ChallengeMetric
    var frequency: ChallengeFrequency
    var workoutTypes: [SimpleWorkoutType]?
}

struct ChallengeProgress: Codable {
    let userId: UUID
    let challengeId: UUID
    var currentValue: Double
    var completedSessions: Int
    var lastUpdateDate: Date
    var isCompleted: Bool
    var completionDate: Date?
    var ranking: Int?
}

struct ChallengeRewards: Codable {
    var experiencePoints: Int
    var badges: [Badge]
    var virtualTrophies: [VirtualTrophy]
    var unlockableContent: [String]
}

enum ChallengeMetric: String, Codable, CaseIterable {
    case workouts = "workouts"
    case distance = "distance"
    case duration = "duration"
    case calories = "calories"
    case heartRateZone = "heart_rate_zone"
    case consistency = "consistency"
    case personalBests = "personal_bests"
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .calories: return "Calories"
        case .heartRateZone: return "Heart Rate Zone Time"
        case .consistency: return "Consistency"
        case .personalBests: return "Personal Bests"
        }
    }
    
    var unit: String {
        switch self {
        case .workouts: return "workouts"
        case .distance: return "km"
        case .duration: return "minutes"
        case .calories: return "calories"
        case .heartRateZone: return "minutes"
        case .consistency: return "days"
        case .personalBests: return "records"
        }
    }
}

enum ChallengeFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case total = "total"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum ChallengeDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case extreme = "extreme"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "yellow"
        case .hard: return "orange"
        case .extreme: return "red"
        }
    }
    
    var experienceMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.0
        case .extreme: return 3.0
        }
    }
}

enum ChallengeCategory: String, Codable, CaseIterable {
    case fitness = "fitness"
    case endurance = "endurance"
    case strength = "strength"
    case consistency = "consistency"
    case social = "social"
    case seasonal = "seasonal"
    case community = "community"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .fitness: return "figure.run"
        case .endurance: return "timer"
        case .strength: return "dumbbell"
        case .consistency: return "calendar"
        case .social: return "person.2"
        case .seasonal: return "leaf"
        case .community: return "building.2"
        }
    }
}

// MARK: - Team Models

struct Team: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    var name: String
    var description: String
    var iconName: String
    var bannerImageURL: String?
    let createdDate: Date
    
    // Membership
    var memberCount: Int
    var maxMembers: Int
    var isPublic: Bool
    var requiresApproval: Bool
    var inviteCode: String?
    
    // Stats
    var activityLevel: ActivityLevel
    var averageWorkoutsPerWeek: Double
    var totalTeamWorkouts: Int
    var totalTeamDistance: Double
    var currentChallenges: [UUID] // Challenge IDs
    
    // Leaderboard
    var teamRanking: Int?
    var weeklyScore: Double
    var monthlyScore: Double
    
    init(name: String, description: String, creatorId: UUID) {
        self.id = UUID()
        self.creatorId = creatorId
        self.name = name
        self.description = description
        self.iconName = "person.2.fill"
        self.bannerImageURL = nil
        self.createdDate = Date()
        self.memberCount = 1
        self.maxMembers = 50
        self.isPublic = true
        self.requiresApproval = false
        self.inviteCode = nil
        self.activityLevel = .moderate
        self.averageWorkoutsPerWeek = 0.0
        self.totalTeamWorkouts = 0
        self.totalTeamDistance = 0.0
        self.currentChallenges = []
        self.teamRanking = nil
        self.weeklyScore = 0.0
        self.monthlyScore = 0.0
    }
}

struct TeamMember: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let teamId: UUID
    var username: String
    var displayName: String
    var avatarURL: String?
    let joinDate: Date
    var role: TeamRole
    var isActive: Bool
    
    // Stats
    var teamWorkouts: Int
    var teamDistance: Double
    var teamCalories: Double
    var contributionScore: Double
    var lastActiveDate: Date
}

enum TeamRole: String, Codable, CaseIterable {
    case member = "member"
    case moderator = "moderator"
    case admin = "admin"
    case owner = "owner"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var permissions: TeamPermissions {
        switch self {
        case .member:
            return TeamPermissions(canInvite: false, canKick: false, canEdit: false, canDelete: false)
        case .moderator:
            return TeamPermissions(canInvite: true, canKick: true, canEdit: false, canDelete: false)
        case .admin:
            return TeamPermissions(canInvite: true, canKick: true, canEdit: true, canDelete: false)
        case .owner:
            return TeamPermissions(canInvite: true, canKick: true, canEdit: true, canDelete: true)
        }
    }
}

struct TeamPermissions {
    let canInvite: Bool
    let canKick: Bool
    let canEdit: Bool
    let canDelete: Bool
}

enum ActivityLevel: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case elite = "elite"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .moderate: return "blue"
        case .high: return "orange"
        case .elite: return "red"
        }
    }
    
    var workoutRange: ClosedRange<Double> {
        switch self {
        case .low: return 0.0...2.0
        case .moderate: return 2.0...4.0
        case .high: return 4.0...6.0
        case .elite: return 6.0...10.0
        }
    }
}

// MARK: - Leaderboard Models

struct LeaderboardEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var userName: String
    var userLocation: String
    var userAvatarURL: String
    var userLevel: UserLevel
    var score: Double
    var scoreType: String
    var formattedScore: String
    var rank: Int
    var previousRank: Int?
    var trend: RankTrend
    let lastUpdate: Date
}

enum LeaderboardType: String, Codable, CaseIterable {
    case workouts = "workouts"
    case distance = "distance"
    case calories = "calories"
    case speed = "speed"
    case consistency = "consistency"
    case achievements = "achievements"
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .distance: return "Distance"
        case .calories: return "Calories"
        case .speed: return "Speed"
        case .consistency: return "Consistency"
        case .achievements: return "Achievements"
        }
    }
    
    var icon: String {
        switch self {
        case .workouts: return "figure.run"
        case .distance: return "location"
        case .calories: return "flame"
        case .speed: return "bolt"
        case .consistency: return "calendar"
        case .achievements: return "trophy"
        }
    }
    
    var scoreType: String {
        switch self {
        case .workouts: return "workouts"
        case .distance: return "km"
        case .calories: return "calories"
        case .speed: return "m/s"
        case .consistency: return "days"
        case .achievements: return "achievements"
        }
    }
}

enum TimePeriod: String, Codable, CaseIterable {
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case thisYear = "this_year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisYear: return "This Year"
        case .allTime: return "All Time"
        }
    }
    
    var dateRange: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return DateInterval(start: startOfWeek, end: now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: startOfMonth, end: now)
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return DateInterval(start: startOfYear, end: now)
        case .allTime:
            return DateInterval(start: Date.distantPast, end: now)
        }
    }
}

enum RankTrend: String, Codable {
    case up = "up"
    case down = "down"
    case stable = "stable"
    case new = "new"
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        case .new: return "star"
        }
    }
    
    var color: String {
        switch self {
        case .up: return "green"
        case .down: return "red"
        case .stable: return "gray"
        case .new: return "blue"
        }
    }
}

// MARK: - Badge & Achievement Models

struct Badge: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let color: String
    let rarity: BadgeRarity
    let category: BadgeCategory
    let requirements: BadgeRequirements
    let earnedDate: Date?
    let progress: Double // 0.0 to 1.0
    
    var isEarned: Bool {
        return earnedDate != nil
    }
}

struct VirtualTrophy: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let material: TrophyMaterial
    let earnedDate: Date
    let source: String // Challenge, achievement, etc.
}

enum BadgeRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }
}

enum BadgeCategory: String, Codable, CaseIterable {
    case workout = "workout"
    case social = "social"
    case achievement = "achievement"
    case consistency = "consistency"
    case milestone = "milestone"
    case special = "special"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

struct BadgeRequirements: Codable {
    let targetValue: Double
    let metric: String
    let description: String
}

enum TrophyMaterial: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    case diamond = "diamond"
    
    var color: String {
        switch self {
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .platinum: return "white"
        case .diamond: return "cyan"
        }
    }
}

// MARK: - Direct Messaging Models

struct DirectMessage: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let receiverId: UUID
    var content: String
    let timestamp: Date
    var isRead: Bool
    var messageType: MessageType
    var attachments: [MessageAttachment]
}

struct Conversation: Codable, Identifiable {
    let id: UUID
    let participantIds: [UUID]
    var lastMessage: DirectMessage?
    let createdDate: Date
    var isArchived: Bool
    var isMuted: Bool
    var unreadCount: Int
}

enum MessageType: String, Codable {
    case text = "text"
    case workout = "workout"
    case challenge = "challenge"
    case image = "image"
    case gif = "gif"
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .workout: return "figure.run"
        case .challenge: return "target"
        case .image: return "photo"
        case .gif: return "gif"
        }
    }
}

struct MessageAttachment: Codable {
    let id: UUID
    let type: AttachmentType
    let url: String
    let thumbnail: String?
    let metadata: [String: String]
}

enum AttachmentType: String, Codable {
    case image = "image"
    case video = "video"
    case workout = "workout"
    case location = "location"
}

// MARK: - Notification Models

struct SocialNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID // Recipient
    let actorId: UUID // Who performed the action
    var actorName: String
    var actorAvatarURL: String
    let type: NotificationType
    let entityId: UUID? // Post, comment, etc.
    var message: String
    let timestamp: Date
    var isRead: Bool
    var actionURL: String? // Deep link
}

enum NotificationType: String, Codable, CaseIterable {
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case challengeInvite = "challenge_invite"
    case teamInvite = "team_invite"
    case achievementEarned = "achievement_earned"
    case workoutShared = "workout_shared"
    case mention = "mention"
    case directMessage = "direct_message"
    
    var displayName: String {
        switch self {
        case .like: return "Liked your post"
        case .comment: return "Commented on your post"
        case .follow: return "Started following you"
        case .challengeInvite: return "Invited you to a challenge"
        case .teamInvite: return "Invited you to join a team"
        case .achievementEarned: return "Achievement earned"
        case .workoutShared: return "Shared a workout with you"
        case .mention: return "Mentioned you in a post"
        case .directMessage: return "Sent you a message"
        }
    }
    
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "bubble.left"
        case .follow: return "person.badge.plus"
        case .challengeInvite: return "target"
        case .teamInvite: return "person.2"
        case .achievementEarned: return "trophy"
        case .workoutShared: return "square.and.arrow.up"
        case .mention: return "at"
        case .directMessage: return "message"
        }
    }
}

// MARK: - Follow System Models

struct FollowRelationship: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdDate: Date
    var isBlocked: Bool = false
    var isMuted: Bool = false
}

// MARK: - CloudKit Extensions

extension UserProfile {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserProfile", recordID: CKRecord.ID(recordName: id.uuidString))
        record["username"] = username
        record["displayName"] = displayName
        record["bio"] = bio
        record["location"] = location
        record["joinDate"] = joinDate
        record["isPrivate"] = isPrivate
        record["totalWorkouts"] = totalWorkouts
        record["totalDistance"] = totalDistance
        record["totalCalories"] = totalCalories
        record["currentStreak"] = currentStreak
        record["longestStreak"] = longestStreak
        record["level"] = level.rawValue
        record["followersCount"] = followersCount
        record["followingCount"] = followingCount
        record["postsCount"] = postsCount
        return record
    }
}

extension FeedPost {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "FeedPost", recordID: CKRecord.ID(recordName: id.uuidString))
        record["authorId"] = authorId.uuidString
        record["content"] = content
        record["timestamp"] = timestamp
        record["likesCount"] = likesCount
        record["commentsCount"] = commentsCount
        record["visibility"] = visibility.rawValue
        return record
    }
}

extension Challenge {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Challenge", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["description"] = description
        record["startDate"] = startDate
        record["endDate"] = endDate
        record["participantCount"] = participantCount
        record["difficultyLevel"] = difficultyLevel.rawValue
        record["category"] = category.rawValue
        return record
    }
}

extension Team {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Team", recordID: CKRecord.ID(recordName: id.uuidString))
        record["name"] = name
        record["description"] = description
        record["createdDate"] = createdDate
        record["memberCount"] = memberCount
        record["maxMembers"] = maxMembers
        record["isPublic"] = isPublic
        record["activityLevel"] = activityLevel.rawValue
        return record
    }
}

// MARK: - Enhanced Social Enums and Extensions

// Social Tab Configuration
enum SocialTab: CaseIterable {
    case feed, challenges, leaderboard, teams
    
    var displayName: String {
        switch self {
        case .feed: return "Feed"
        case .challenges: return "Challenges"
        case .leaderboard: return "Leaderboard"
        case .teams: return "Teams"
        }
    }
    
    var iconName: String {
        switch self {
        case .feed: return "house.fill"
        case .challenges: return "target"
        case .leaderboard: return "trophy.fill"
        case .teams: return "person.3.fill"
        }
    }
}

// Leaderboard Types
enum LeaderboardType: CaseIterable {
    case workouts, distance, calories, speed, consistency
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .distance: return "Distance"
        case .calories: return "Calories"
        case .speed: return "Speed"
        case .consistency: return "Consistency"
        }
    }
    
    var unit: String {
        switch self {
        case .workouts: return "workouts"
        case .distance: return "km"
        case .calories: return "cal"
        case .speed: return "km/h"
        case .consistency: return "days"
        }
    }
    
    var iconName: String {
        switch self {
        case .workouts: return "figure.run"
        case .distance: return "location.fill"
        case .calories: return "flame.fill"
        case .speed: return "speedometer"
        case .consistency: return "calendar.badge.checkmark"
        }
    }
}

// Time Period Types
enum TimePeriod: CaseIterable {
    case thisWeek, thisMonth, last3Months, thisYear, allTime
    
    var displayName: String {
        switch self {
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .last3Months: return "Last 3 Months"
        case .thisYear: return "This Year"
        case .allTime: return "All Time"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (threeMonthsAgo, now)
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        case .allTime:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (distantPast, now)
        }
    }
}

// Challenge Categories
enum ChallengeCategory: String, CaseIterable {
    case all = "all"
    case endurance = "endurance"
    case speed = "speed"
    case strength = "strength"
    case consistency = "consistency"
    case social = "social"
    case beginner = "beginner"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .endurance: return "Endurance"
        case .speed: return "Speed"
        case .strength: return "Strength"
        case .consistency: return "Consistency"
        case .social: return "Social"
        case .beginner: return "Beginner"
        case .advanced: return "Advanced"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .endurance: return "heart.fill"
        case .speed: return "bolt.fill"
        case .strength: return "dumbbell.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .social: return "person.3.fill"
        case .beginner: return "star.fill"
        case .advanced: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .endurance: return .red
        case .speed: return .blue
        case .strength: return .orange
        case .consistency: return .green
        case .social: return .purple
        case .beginner: return .yellow
        case .advanced: return .pink
        }
    }
}

// Team Categories
enum TeamCategory: String, CaseIterable {
    case all = "all"
    case casual = "casual"
    case competitive = "competitive"
    case beginner = "beginner"
    case advanced = "advanced"
    case local = "local"
    case global = "global"
    case corporate = "corporate"
    
    var displayName: String {
        switch self {
        case .all: return "All Teams"
        case .casual: return "Casual"
        case .competitive: return "Competitive"
        case .beginner: return "Beginner"
        case .advanced: return "Advanced"
        case .local: return "Local"
        case .global: return "Global"
        case .corporate: return "Corporate"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "person.3.fill"
        case .casual: return "leaf.fill"
        case .competitive: return "trophy.fill"
        case .beginner: return "star.fill"
        case .advanced: return "crown.fill"
        case .local: return "location.fill"
        case .global: return "globe"
        case .corporate: return "building.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .casual: return .green
        case .competitive: return .red
        case .beginner: return .blue
        case .advanced: return .purple
        case .local: return .orange
        case .global: return .cyan
        case .corporate: return .indigo
        }
    }
}

// Activity Level Extensions
extension ActivityLevel {
    var displayName: String {
        switch self {
        case .low: return "Casual"
        case .moderate: return "Regular"
        case .high: return "Active"
        case .elite: return "Elite"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .blue
        case .high: return .orange
        case .elite: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "leaf.fill"
        case .moderate: return "figure.walk"
        case .high: return "figure.run"
        case .elite: return "bolt.fill"
        }
    }
}

// Simple Workout Type Extensions
extension SimpleWorkoutType {
    var iconName: String {
        switch self {
        case .shuttleRun: return "figure.run"
        case .hiit: return "timer"
        case .tabata: return "bolt.fill"
        case .pyramid: return "triangle.fill"
        case .runWalk: return "figure.walk"
        case .custom: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .shuttleRun: return .orange
        case .hiit: return .blue
        case .tabata: return .red
        case .pyramid: return .green
        case .runWalk: return .yellow
        case .custom: return .purple
        }
    }
}

// Experience Level Extensions
extension ExperienceLevel {
    var iconName: String {
        switch self {
        case .beginner: return "star.fill"
        case .intermediate: return "star.leadinghalf.filled"
        case .advanced: return "star.circle.fill"
        case .expert: return "crown.fill"
        case .professional: return "medal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .purple
        case .professional: return .gold
        }
    }
    
    var experienceMultiplier: Double {
        switch self {
        case .beginner: return 1.0
        case .intermediate: return 1.2
        case .advanced: return 1.5
        case .expert: return 2.0
        case .professional: return 3.0
        }
    }
}

// Color Extensions
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let silver = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let bronze = Color(red: 0.8, green: 0.5, blue: 0.2)
}

// Post Type Extensions
extension PostType {
    var iconName: String {
        switch self {
        case .workout: return "figure.run"
        case .achievement: return "trophy.fill"
        case .text: return "text.bubble.fill"
        case .media: return "photo.fill"
        case .challenge: return "target"
        }
    }
    
    var displayName: String {
        switch self {
        case .workout: return "Workout"
        case .achievement: return "Achievement"
        case .text: return "Post"
        case .media: return "Photo"
        case .challenge: return "Challenge"
        }
    }
}

// Notification Type Extensions
extension NotificationType {
    var iconName: String {
        switch self {
        case .like: return "heart.fill"
        case .comment: return "message.fill"
        case .follow: return "person.badge.plus"
        case .challengeInvite: return "target"
        case .teamInvite: return "person.3.fill"
        case .achievement: return "trophy.fill"
        case .workoutReminder: return "bell.fill"
        case .message: return "envelope.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .red
        case .comment: return .blue
        case .follow: return .green
        case .challengeInvite: return .orange
        case .teamInvite: return .purple
        case .achievement: return .yellow
        case .workoutReminder: return .orange
        case .message: return .blue
        }
    }
    
    var displayName: String {
        switch self {
        case .like: return "Like"
        case .comment: return "Comment"
        case .follow: return "Follow"
        case .challengeInvite: return "Challenge Invite"
        case .teamInvite: return "Team Invite"
        case .achievement: return "Achievement"
        case .workoutReminder: return "Workout Reminder"
        case .message: return "Message"
        }
    }
}

// Challenge Metric Extensions
extension ChallengeMetric {
    var unit: String {
        switch self {
        case .workouts: return "workouts"
        case .distance: return "km"
        case .duration: return "minutes"
        case .calories: return "calories"
        case .steps: return "steps"
        case .consistency: return "days"
        }
    }
    
    var iconName: String {
        switch self {
        case .workouts: return "figure.run"
        case .distance: return "location.fill"
        case .duration: return "clock.fill"
        case .calories: return "flame.fill"
        case .steps: return "footprints"
        case .consistency: return "calendar.badge.checkmark"
        }
    }
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .calories: return "Calories"
        case .steps: return "Steps"
        case .consistency: return "Consistency"
        }
    }
}

// Team Role Extensions
extension TeamRole {
    var iconName: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "person.badge.key.fill"
        case .moderator: return "shield.fill"
        case .member: return "person.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .owner: return .gold
        case .admin: return .red
        case .moderator: return .blue
        case .member: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .member: return "Member"
        }
    }
    
    var permissions: [TeamPermission] {
        switch self {
        case .owner:
            return TeamPermission.allCases
        case .admin:
            return [.manageMembers, .editTeam, .createChallenges, .moderateContent, .viewAnalytics]
        case .moderator:
            return [.moderateContent, .createChallenges]
        case .member:
            return []
        }
    }
}

// Team Permission enum
enum TeamPermission: String, CaseIterable {
    case manageMembers = "manage_members"
    case editTeam = "edit_team"
    case createChallenges = "create_challenges"
    case moderateContent = "moderate_content"
    case viewAnalytics = "view_analytics"
    case deleteTeam = "delete_team"
    
    var displayName: String {
        switch self {
        case .manageMembers: return "Manage Members"
        case .editTeam: return "Edit Team"
        case .createChallenges: return "Create Challenges"
        case .moderateContent: return "Moderate Content"
        case .viewAnalytics: return "View Analytics"
        case .deleteTeam: return "Delete Team"
        }
    }
}

// Story Type Extensions (for future implementation)
enum StoryType: String, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    case workout = "workout"
    case achievement = "achievement"
    
    var iconName: String {
        switch self {
        case .text: return "text.bubble.fill"
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .workout: return "figure.run"
        case .achievement: return "trophy.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Photo"
        case .video: return "Video"
        case .workout: return "Workout"
        case .achievement: return "Achievement"
        }
    }
}

// Activity Type for team activities
enum TeamActivityType: String, CaseIterable {
    case memberJoined = "member_joined"
    case memberLeft = "member_left"
    case challengeCompleted = "challenge_completed"
    case achievementUnlocked = "achievement_unlocked"
    case workoutShared = "workout_shared"
    case goalReached = "goal_reached"
    
    var iconName: String {
        switch self {
        case .memberJoined: return "person.badge.plus"
        case .memberLeft: return "person.badge.minus"
        case .challengeCompleted: return "checkmark.circle.fill"
        case .achievementUnlocked: return "trophy.fill"
        case .workoutShared: return "square.and.arrow.up"
        case .goalReached: return "target"
        }
    }
    
    var color: Color {
        switch self {
        case .memberJoined: return .green
        case .memberLeft: return .red
        case .challengeCompleted: return .blue
        case .achievementUnlocked: return .yellow
        case .workoutShared: return .orange
        case .goalReached: return .purple
        }
    }
    
    var displayName: String {
        switch self {
        case .memberJoined: return "Member Joined"
        case .memberLeft: return "Member Left"
        case .challengeCompleted: return "Challenge Completed"
        case .achievementUnlocked: return "Achievement Unlocked"
        case .workoutShared: return "Workout Shared"
        case .goalReached: return "Goal Reached"
        }
    }
}

// MARK: - Additional Helper Models

// Today's Stats Model for quick stats display
struct TodayStats {
    let workoutsCompleted: Int
    let totalDuration: TimeInterval
    let caloriesBurned: Double
    let totalDistance: Double
    let averageHeartRate: Double?
    let activeMinutes: Int
    
    static let empty = TodayStats(
        workoutsCompleted: 0,
        totalDuration: 0,
        caloriesBurned: 0,
        totalDistance: 0,
        averageHeartRate: nil,
        activeMinutes: 0
    )
}

// Story Model for enhanced stories feature
struct Story: Identifiable, Codable {
    let id: String
    let userId: String
    let user: UserProfile
    let type: StoryType
    let content: String
    let mediaURL: String?
    let timestamp: Date
    let expiresAt: Date
    let isViewed: Bool
    let viewCount: Int
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
}

// Team Activity Model for team activity feeds
struct TeamActivity: Identifiable, Codable {
    let id: String
    let teamId: String
    let userId: String
    let user: UserProfile
    let type: TeamActivityType
    let description: String
    let metadata: [String: String]
    let timestamp: Date
    
    var displayText: String {
        switch type {
        case .memberJoined:
            return "\(user.name) joined the team"
        case .memberLeft:
            return "\(user.name) left the team"
        case .challengeCompleted:
            return "\(user.name) completed a challenge"
        case .achievementUnlocked:
            return "\(user.name) unlocked an achievement"
        case .workoutShared:
            return "\(user.name) shared a workout"
        case .goalReached:
            return "\(user.name) reached a goal"
        }
    }
}

// Enhanced Workout Data for social posts
struct WorkoutData: Identifiable, Codable {
    let id: String
    let type: WorkoutType
    let duration: TimeInterval
    let distance: Double?
    let caloriesBurned: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let intensity: Int // 1-5 scale
    let location: String?
    let weather: String?
    let notes: String?
    let timestamp: Date
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDistance: String? {
        guard let distance = distance else { return nil }
        return String(format: "%.1f km", distance)
    }
    
    var intensityLevel: String {
        switch intensity {
        case 1: return "Light"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "Unknown"
        }
    }
}

// Media attachment model for posts
struct MediaAttachment: Identifiable, Codable {
    let id: String
    let url: String
    let type: MediaType
    let thumbnail: String?
    let caption: String?
    let aspectRatio: Double
    
    enum MediaType: String, CaseIterable, Codable {
        case image = "image"
        case video = "video"
        case gif = "gif"
        
        var iconName: String {
            switch self {
            case .image: return "photo.fill"
            case .video: return "video.fill"
            case .gif: return "play.circle.fill"
            }
        }
    }
}

// Enhanced Achievement Model for better social integration
extension Achievement {
    var shareText: String {
        "🏆 Just unlocked the '\(title)' achievement! \(description) #ShuttlX #Achievement"
    }
    
    var celebrationEmoji: String {
        switch category {
        case .workout: return "💪"
        case .distance: return "🏃‍♀️"
        case .consistency: return "📅"
        case .social: return "👥"
        case .special: return "⭐"
        }
    }
}
