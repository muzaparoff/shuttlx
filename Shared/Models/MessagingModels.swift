//
//  MessagingModels.swift
//  ShuttlX
//
//  Direct messaging and chat system models
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CloudKit

// MARK: - Conversation Models

struct Conversation: Identifiable, Codable {
    let id: UUID
    let type: ConversationType
    var participants: [UUID]
    var lastMessage: Message?
    var lastActivity: Date
    var isActive: Bool
    var metadata: ConversationMetadata
    
    // Group conversation specific
    var name: String?
    var description: String?
    var imageURL: String?
    var adminIDs: [UUID]
    
    init(type: ConversationType, participants: [UUID]) {
        self.id = UUID()
        self.type = type
        self.participants = participants
        self.lastMessage = nil
        self.lastActivity = Date()
        self.isActive = true
        self.metadata = ConversationMetadata()
        self.name = nil
        self.description = nil
        self.imageURL = nil
        self.adminIDs = []
    }
}

enum ConversationType: String, CaseIterable, Codable {
    case direct = "direct"
    case group = "group"
    case team = "team"
    case challenge = "challenge"
    
    var maxParticipants: Int {
        switch self {
        case .direct: return 2
        case .group: return 50
        case .team: return 100
        case .challenge: return 1000
        }
    }
    
    var iconName: String {
        switch self {
        case .direct: return "person.2.fill"
        case .group: return "person.3.fill"
        case .team: return "person.3.sequence.fill"
        case .challenge: return "flag.2.crossed.fill"
        }
    }
}

struct ConversationMetadata: Codable {
    var unreadCount: [UUID: Int]
    var mutedBy: [UUID]
    var pinnedBy: [UUID]
    var archivedBy: [UUID]
    var lastReadTimestamp: [UUID: Date]
    var conversationSettings: ConversationSettings
    
    init() {
        self.unreadCount = [:]
        self.mutedBy = []
        self.pinnedBy = []
        self.archivedBy = []
        self.lastReadTimestamp = [:]
        self.conversationSettings = ConversationSettings()
    }
}

struct ConversationSettings: Codable {
    var allowInvites: Bool
    var allowMediaSharing: Bool
    var allowWorkoutSharing: Bool
    var requireApprovalForJoin: Bool
    var disappearingMessages: Bool
    var disappearingMessageDuration: TimeInterval
    
    init() {
        self.allowInvites = true
        self.allowMediaSharing = true
        self.allowWorkoutSharing = true
        self.requireApprovalForJoin = false
        self.disappearingMessages = false
        self.disappearingMessageDuration = 24 * 60 * 60 // 24 hours
    }
}

// MARK: - Message Models

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let content: MessageContent
    let timestamp: Date
    let editedAt: Date?
    let replyToMessageID: UUID?
    var reactions: [MessageReaction]
    var readBy: [UUID: Date]
    var deliveredTo: [UUID: Date]
    var status: MessageStatus
    var metadata: MessageMetadata
    
    init(conversationID: UUID, senderID: UUID, content: MessageContent) {
        self.id = UUID()
        self.conversationID = conversationID
        self.senderID = senderID
        self.content = content
        self.timestamp = Date()
        self.editedAt = nil
        self.replyToMessageID = nil
        self.reactions = []
        self.readBy = [:]
        self.deliveredTo = [:]
        self.status = .sending
        self.metadata = MessageMetadata()
    }
}

enum MessageStatus: String, CaseIterable, Codable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    
    var iconName: String {
        switch self {
        case .sending: return "clock.fill"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

struct MessageMetadata: Codable {
    var isSystemMessage: Bool
    var isEncrypted: Bool
    var isEphemeral: Bool
    var expiresAt: Date?
    var originalLanguage: String?
    var translatedContent: [String: String]
    var linkPreview: LinkPreview?
    
    init() {
        self.isSystemMessage = false
        self.isEncrypted = false
        self.isEphemeral = false
        self.expiresAt = nil
        self.originalLanguage = nil
        self.translatedContent = [:]
        self.linkPreview = nil
    }
}

// MARK: - Message Content

enum MessageContent: Codable {
    case text(String)
    case media([MediaAttachment])
    case workout(WorkoutShareData)
    case location(LocationData)
    case challenge(ChallengeInviteData)
    case achievement(AchievementShareData)
    case voice(VoiceMessageData)
    case reaction(String) // Emoji reaction
    case system(SystemMessageData)
    case reply(ReplyData)
    
    var displayText: String {
        switch self {
        case .text(let text):
            return text
        case .media(let attachments):
            return attachments.count == 1 ? "📷 Photo" : "📷 \(attachments.count) photos"
        case .workout:
            return "🏃‍♀️ Workout shared"
        case .location:
            return "📍 Location shared"
        case .challenge:
            return "🏆 Challenge invitation"
        case .achievement:
            return "🏅 Achievement shared"
        case .voice:
            return "🎤 Voice message"
        case .reaction(let emoji):
            return emoji
        case .system(let data):
            return data.message
        case .reply(let data):
            return data.content
        }
    }
    
    var hasMedia: Bool {
        switch self {
        case .media, .voice:
            return true
        default:
            return false
        }
    }
    
    var isInteractive: Bool {
        switch self {
        case .challenge, .location, .workout:
            return true
        default:
            return false
        }
    }
}

// MARK: - Message Content Data Structures

struct WorkoutShareData: Codable {
    let workoutID: UUID
    let workoutType: String
    let duration: TimeInterval
    let distance: Double?
    let caloriesBurned: Double
    let timestamp: Date
    let summary: String
    let inviteToWorkout: Bool
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
    let name: String?
    let category: String? // "gym", "park", "track", etc.
    let inviteToLocation: Bool
    
    var coordinate: (Double, Double) {
        return (latitude, longitude)
    }
}

struct ChallengeInviteData: Codable {
    let challengeID: UUID
    let challengeName: String
    let challengeType: String
    let startDate: Date
    let endDate: Date
    let difficulty: String
    let participantCount: Int
    let description: String
}

struct AchievementShareData: Codable {
    let achievementID: UUID
    let title: String
    let description: String
    let category: String
    let iconName: String
    let unlockedAt: Date
    let rarity: String // "common", "rare", "epic", "legendary"
}

struct VoiceMessageData: Codable {
    let audioURL: String
    let duration: TimeInterval
    let waveformData: [Float]
    let transcript: String?
    let isTranscribed: Bool
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SystemMessageData: Codable {
    let type: SystemMessageType
    let message: String
    let actionUserID: UUID?
    let targetUserID: UUID?
    let metadata: [String: String]
}

enum SystemMessageType: String, CaseIterable, Codable {
    case userJoined = "user_joined"
    case userLeft = "user_left"
    case userAdded = "user_added"
    case userRemoved = "user_removed"
    case userPromoted = "user_promoted"
    case userDemoted = "user_demoted"
    case conversationCreated = "conversation_created"
    case conversationRenamed = "conversation_renamed"
    case settingsChanged = "settings_changed"
    case mediaShared = "media_shared"
    case challengeCreated = "challenge_created"
    case workoutCompleted = "workout_completed"
}

struct ReplyData: Codable {
    let originalMessageID: UUID
    let originalSenderID: UUID
    let originalContent: String
    let content: String
    let originalTimestamp: Date
}

struct LinkPreview: Codable {
    let url: String
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let faviconURL: String?
}

// MARK: - Message Reactions

struct MessageReaction: Identifiable, Codable {
    let id: UUID
    let messageID: UUID
    let userID: UUID
    let emoji: String
    let timestamp: Date
    
    init(messageID: UUID, userID: UUID, emoji: String) {
        self.id = UUID()
        self.messageID = messageID
        self.userID = userID
        self.emoji = emoji
        self.timestamp = Date()
    }
}

// Common reaction emojis
extension MessageReaction {
    static let commonEmojis = ["❤️", "👍", "👎", "😂", "😮", "😢", "🔥", "💪", "🎉", "👏"]
    static let fitnessEmojis = ["💪", "🏃‍♀️", "🔥", "⚡", "🏆", "🎯", "💦", "👟", "🏋️‍♀️", "🚀"]
}

// MARK: - Typing Indicators

struct TypingIndicator: Identifiable, Codable {
    let id: UUID
    let conversationID: UUID
    let userID: UUID
    let startedAt: Date
    let lastUpdated: Date
    
    init(conversationID: UUID, userID: UUID) {
        self.id = UUID()
        self.conversationID = conversationID
        self.userID = userID
        self.startedAt = Date()
        self.lastUpdated = Date()
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(lastUpdated) > 5.0 // 5 seconds timeout
    }
}

// MARK: - Message Search

struct MessageSearchResult: Identifiable {
    let id = UUID()
    let message: Message
    let conversation: Conversation
    let matchedText: String
    let context: [Message] // Messages before and after for context
}

struct MessageSearchQuery: Codable {
    let text: String
    let conversationID: UUID?
    let senderID: UUID?
    let contentType: MessageContentType?
    let dateRange: DateInterval?
    let hasMedia: Bool?
    let hasLinks: Bool?
    
    enum MessageContentType: String, CaseIterable, Codable {
        case text = "text"
        case media = "media"
        case workout = "workout"
        case location = "location"
        case challenge = "challenge"
        case achievement = "achievement"
        case voice = "voice"
    }
}

// MARK: - Extensions

extension Conversation {
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        
        switch type {
        case .direct:
            return "Direct Message"
        case .group:
            return "Group Chat"
        case .team:
            return "Team Chat"
        case .challenge:
            return "Challenge Chat"
        }
    }
    
    var participantCount: Int {
        return participants.count
    }
    
    func unreadCount(for userID: UUID) -> Int {
        return metadata.unreadCount[userID] ?? 0
    }
    
    func isMuted(by userID: UUID) -> Bool {
        return metadata.mutedBy.contains(userID)
    }
    
    func isPinned(by userID: UUID) -> Bool {
        return metadata.pinnedBy.contains(userID)
    }
    
    func isArchived(by userID: UUID) -> Bool {
        return metadata.archivedBy.contains(userID)
    }
    
    func lastRead(by userID: UUID) -> Date? {
        return metadata.lastReadTimestamp[userID]
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

extension Message {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var isEdited: Bool {
        return editedAt != nil
    }
    
    var isReply: Bool {
        return replyToMessageID != nil
    }
    
    func hasReaction(_ emoji: String, from userID: UUID) -> Bool {
        return reactions.contains { $0.emoji == emoji && $0.userID == userID }
    }
    
    func reactionCount(for emoji: String) -> Int {
        return reactions.filter { $0.emoji == emoji }.count
    }
    
    var uniqueReactions: [String: Int] {
        var counts: [String: Int] = [:]
        for reaction in reactions {
            counts[reaction.emoji, default: 0] += 1
        }
        return counts
    }
    
    var isDelivered: Bool {
        return !deliveredTo.isEmpty
    }
    
    var isRead: Bool {
        return !readBy.isEmpty
    }
    
    func isRead(by userID: UUID) -> Bool {
        return readBy[userID] != nil
    }
    
    func isDelivered(to userID: UUID) -> Bool {
        return deliveredTo[userID] != nil
    }
}
