//
//  NotificationModels.swift
//  ShuttlX
//
//  Notification system models for social and fitness features
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CloudKit

// MARK: - Notification Models

struct NotificationModel: Identifiable, Codable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let isRead: Bool
    let senderID: UUID?
    let relatedID: String? // Can be post ID, challenge ID, etc.
    let actionURL: String?
    let imageURL: String?
    var metadata: [String: String]
    
    init(type: NotificationType, title: String, message: String, senderID: UUID? = nil, relatedID: String? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = Date()
        self.isRead = false
        self.senderID = senderID
        self.relatedID = relatedID
        self.actionURL = nil
        self.imageURL = nil
        self.metadata = [:]
    }
}

enum NotificationType: String, CaseIterable, Codable {
    // Social notifications
    case newFollower = "new_follower"
    case followAccepted = "follow_accepted"
    case postLiked = "post_liked"
    case postCommented = "post_commented"
    case postShared = "post_shared"
    case userMentioned = "user_mentioned"
    case directMessage = "direct_message"
    
    // Challenge notifications
    case challengeInvite = "challenge_invite"
    case challengeStarted = "challenge_started"
    case challengeCompleted = "challenge_completed"
    case challengeWon = "challenge_won"
    case challengeLeaderboardUpdate = "challenge_leaderboard"
    
    // Team notifications
    case teamInvite = "team_invite"
    case teamJoined = "team_joined"
    case teamChallengeCreated = "team_challenge_created"
    case teamMemberJoined = "team_member_joined"
    case teamAchievement = "team_achievement"
    
    // Achievement notifications
    case achievementUnlocked = "achievement_unlocked"
    case badgeEarned = "badge_earned"
    case levelUp = "level_up"
    case streakMilestone = "streak_milestone"
    case personalRecord = "personal_record"
    
    // Fitness notifications
    case workoutReminder = "workout_reminder"
    case goalAchieved = "goal_achieved"
    case weeklyReport = "weekly_report"
    case monthlyReport = "monthly_report"
    case recoveryAlert = "recovery_alert"
    case heartRateAlert = "heart_rate_alert"
    
    // System notifications
    case appUpdate = "app_update"
    case maintenanceMode = "maintenance_mode"
    case newFeature = "new_feature"
    
    var iconName: String {
        switch self {
        case .newFollower, .followAccepted:
            return "person.badge.plus.fill"
        case .postLiked:
            return "heart.fill"
        case .postCommented:
            return "bubble.left.fill"
        case .postShared:
            return "square.and.arrow.up.fill"
        case .userMentioned:
            return "at.badge.plus"
        case .directMessage:
            return "message.fill"
        case .challengeInvite, .challengeStarted:
            return "flag.fill"
        case .challengeCompleted:
            return "checkmark.circle.fill"
        case .challengeWon:
            return "trophy.fill"
        case .challengeLeaderboardUpdate:
            return "chart.bar.fill"
        case .teamInvite, .teamJoined:
            return "person.3.fill"
        case .teamChallengeCreated:
            return "flag.2.crossed.fill"
        case .teamMemberJoined:
            return "person.badge.plus"
        case .teamAchievement:
            return "rosette"
        case .achievementUnlocked:
            return "medal.fill"
        case .badgeEarned:
            return "seal.fill"
        case .levelUp:
            return "arrow.up.circle.fill"
        case .streakMilestone:
            return "flame.fill"
        case .personalRecord:
            return "star.circle.fill"
        case .workoutReminder:
            return "clock.fill"
        case .goalAchieved:
            return "target"
        case .weeklyReport, .monthlyReport:
            return "chart.line.uptrend.xyaxis"
        case .recoveryAlert:
            return "heart.text.square.fill"
        case .heartRateAlert:
            return "waveform.path.ecg"
        case .appUpdate:
            return "arrow.down.circle.fill"
        case .maintenanceMode:
            return "gear.badge"
        case .newFeature:
            return "sparkles"
        }
    }
    
    var color: String {
        switch self {
        case .newFollower, .followAccepted, .userMentioned:
            return "blue"
        case .postLiked, .heartRateAlert:
            return "red"
        case .postCommented, .postShared, .directMessage:
            return "green"
        case .challengeInvite, .challengeStarted, .challengeCompleted, .challengeWon, .challengeLeaderboardUpdate:
            return "orange"
        case .teamInvite, .teamJoined, .teamChallengeCreated, .teamMemberJoined, .teamAchievement:
            return "purple"
        case .achievementUnlocked, .badgeEarned, .levelUp, .streakMilestone, .personalRecord:
            return "yellow"
        case .workoutReminder, .goalAchieved, .weeklyReport, .monthlyReport, .recoveryAlert:
            return "cyan"
        case .appUpdate, .maintenanceMode, .newFeature:
            return "gray"
        }
    }
    
    var priority: NotificationPriority {
        switch self {
        case .heartRateAlert, .recoveryAlert, .maintenanceMode:
            return .high
        case .challengeWon, .achievementUnlocked, .levelUp, .personalRecord:
            return .medium
        default:
            return .normal
        }
    }
}

enum NotificationPriority: Int, Codable {
    case low = 0
    case normal = 1
    case medium = 2
    case high = 3
    case urgent = 4
    
    var sortOrder: Int {
        return rawValue
    }
}

// MARK: - Push Notification Models

struct PushNotificationPayload: Codable {
    let title: String
    let body: String
    let badge: Int?
    let sound: String?
    let category: String?
    let userInfo: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case title, body, badge, sound, category
    }
    
    init(title: String, body: String, badge: Int? = nil, sound: String? = "default", category: String? = nil, userInfo: [String: Any] = [:]) {
        self.title = title
        self.body = body
        self.badge = badge
        self.sound = sound
        self.category = category
        self.userInfo = userInfo
    }
}

struct NotificationSettings: Codable {
    var isEnabled: Bool
    var soundEnabled: Bool
    var badgeEnabled: Bool
    var previewEnabled: Bool
    
    // Category-specific settings
    var socialNotifications: Bool
    var challengeNotifications: Bool
    var teamNotifications: Bool
    var achievementNotifications: Bool
    var fitnessNotifications: Bool
    var systemNotifications: Bool
    
    // Timing settings
    var quietHoursEnabled: Bool
    var quietHoursStart: Date
    var quietHoursEnd: Date
    
    static let `default` = NotificationSettings(
        isEnabled: true,
        soundEnabled: true,
        badgeEnabled: true,
        previewEnabled: true,
        socialNotifications: true,
        challengeNotifications: true,
        teamNotifications: true,
        achievementNotifications: true,
        fitnessNotifications: true,
        systemNotifications: true,
        quietHoursEnabled: false,
        quietHoursStart: Calendar.current.date(from: DateComponents(hour: 22)) ?? Date(),
        quietHoursEnd: Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    )
}

// MARK: - Notification Groups

struct NotificationGroup: Identifiable {
    let id = UUID()
    let type: NotificationType
    let notifications: [NotificationModel]
    let count: Int
    let latestTimestamp: Date
    
    var title: String {
        switch type {
        case .postLiked:
            return count == 1 ? "New like" : "\(count) new likes"
        case .newFollower:
            return count == 1 ? "New follower" : "\(count) new followers"
        case .postCommented:
            return count == 1 ? "New comment" : "\(count) new comments"
        case .challengeInvite:
            return count == 1 ? "Challenge invitation" : "\(count) challenge invitations"
        default:
            return type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    var summary: String {
        guard let latest = notifications.first else { return "" }
        
        if count == 1 {
            return latest.message
        } else {
            let others = count - 1
            return "\(latest.message) and \(others) other\(others == 1 ? "" : "s")"
        }
    }
}

// MARK: - Notification Actions

enum NotificationAction: String, CaseIterable {
    case like = "LIKE_ACTION"
    case comment = "COMMENT_ACTION"
    case follow = "FOLLOW_ACTION"
    case acceptChallenge = "ACCEPT_CHALLENGE"
    case declineChallenge = "DECLINE_CHALLENGE"
    case joinTeam = "JOIN_TEAM"
    case viewPost = "VIEW_POST"
    case reply = "REPLY_ACTION"
    case markAsRead = "MARK_READ"
    case delete = "DELETE_ACTION"
    
    var title: String {
        switch self {
        case .like: return "Like"
        case .comment: return "Comment"
        case .follow: return "Follow"
        case .acceptChallenge: return "Accept"
        case .declineChallenge: return "Decline"
        case .joinTeam: return "Join"
        case .viewPost: return "View"
        case .reply: return "Reply"
        case .markAsRead: return "Mark as Read"
        case .delete: return "Delete"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .delete, .declineChallenge:
            return true
        default:
            return false
        }
    }
}

// MARK: - Extensions

extension NotificationModel {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var canBeGrouped: Bool {
        switch type {
        case .postLiked, .newFollower, .postCommented, .challengeInvite:
            return true
        default:
            return false
        }
    }
    
    func withRead(_ isRead: Bool) -> NotificationModel {
        var notification = self
        notification = NotificationModel(
            type: type,
            title: title,
            message: message,
            senderID: senderID,
            relatedID: relatedID
        )
        return notification
    }
}

extension Array where Element == NotificationModel {
    func grouped() -> [NotificationGroup] {
        let groupedDict = Dictionary(grouping: self) { notification in
            notification.canBeGrouped ? notification.type : nil
        }
        
        var groups: [NotificationGroup] = []
        
        // Add ungrouped notifications
        if let ungrouped = groupedDict[nil] {
            for notification in ungrouped {
                groups.append(NotificationGroup(
                    type: notification.type,
                    notifications: [notification],
                    count: 1,
                    latestTimestamp: notification.timestamp
                ))
            }
        }
        
        // Add grouped notifications
        for (type, notifications) in groupedDict where type != nil {
            guard let notificationType = type else { continue }
            let sortedNotifications = notifications.sorted { $0.timestamp > $1.timestamp }
            groups.append(NotificationGroup(
                type: notificationType,
                notifications: sortedNotifications,
                count: notifications.count,
                latestTimestamp: sortedNotifications.first?.timestamp ?? Date()
            ))
        }
        
        return groups.sorted { $0.latestTimestamp > $1.latestTimestamp }
    }
    
    var unreadCount: Int {
        return filter { !$0.isRead }.count
    }
    
    func filtered(by types: [NotificationType]) -> [NotificationModel] {
        return filter { types.contains($0.type) }
    }
}
