//
//  MessagingService.swift
//  ShuttlX
//
//  Direct messaging and chat system service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import Combine
import CloudKit

@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()
    
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    @Published var messages: [UUID: [Message]] = [:]
    @Published var typingIndicators: [UUID: [TypingIndicator]] = [:]
    @Published var isLoading = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private var apiService: APIService?
    private let notificationService = NotificationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: UUID?
    
    // Real-time messaging simulation
    private var messageUpdateTimer: Timer?
    private var typingTimer: Timer?
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
        
        var displayText: String {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting..."
            case .disconnected: return "Disconnected"
            case .error(let message): return "Error: \(message)"
            }
        }
    }
    
    init() {
        setupRealTimeUpdates()
        loadConversations()
        startConnectionMonitoring()
    }
    
    deinit {
        messageUpdateTimer?.invalidate()
        typingTimer?.invalidate()
    }
    
    // MARK: - Configuration
    
    func configure(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - User Management
    
    func setCurrentUser(_ userID: UUID) {
        self.currentUserID = userID
        loadConversations()
    }
    
    // MARK: - Conversation Management
    
    func createDirectConversation(with userID: UUID) async -> Conversation? {
        guard let currentUserID = currentUserID else { return nil }
        
        // Check if conversation already exists
        if let existing = conversations.first(where: { 
            $0.type == .direct && 
            $0.participants.contains(currentUserID) && 
            $0.participants.contains(userID) 
        }) {
            return existing
        }
        
        let conversation = Conversation(type: .direct, participants: [currentUserID, userID])
        conversations.append(conversation)
        saveConversations()
        
        await syncConversationToCloudKit(conversation)
        return conversation
    }
    
    func createGroupConversation(name: String, participants: [UUID]) async -> Conversation? {
        guard let currentUserID = currentUserID else { return nil }
        
        var conversation = Conversation(type: .group, participants: participants + [currentUserID])
        conversation.name = name
        conversation.adminIDs = [currentUserID]
        
        conversations.append(conversation)
        saveConversations()
        
        await syncConversationToCloudKit(conversation)
        return conversation
    }
    
    func updateConversation(_ conversation: Conversation) async {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
            saveConversations()
            await syncConversationToCloudKit(conversation)
        }
    }
    
    func deleteConversation(_ conversationID: UUID) async {
        conversations.removeAll { $0.id == conversationID }
        messages.removeValue(forKey: conversationID)
        saveConversations()
        
        // Remove from CloudKit
        await deleteConversationFromCloudKit(conversationID)
    }
    
    func archiveConversation(_ conversationID: UUID, for userID: UUID) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            var conversation = conversations[index]
            conversation.metadata.archivedBy.append(userID)
            conversations[index] = conversation
            saveConversations()
        }
    }
    
    func muteConversation(_ conversationID: UUID, for userID: UUID) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            var conversation = conversations[index]
            if !conversation.metadata.mutedBy.contains(userID) {
                conversation.metadata.mutedBy.append(userID)
                conversations[index] = conversation
                saveConversations()
            }
        }
    }
    
    func unmuteConversation(_ conversationID: UUID, for userID: UUID) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            var conversation = conversations[index]
            conversation.metadata.mutedBy.removeAll { $0 == userID }
            conversations[index] = conversation
            saveConversations()
        }
    }
    
    // MARK: - Message Management
    
    func sendMessage(to conversationID: UUID, content: MessageContent) async -> Message? {
        guard let currentUserID = currentUserID else { return nil }
        
        let message = Message(conversationID: conversationID, senderID: currentUserID, content: content)
        
        // Add to local messages
        if messages[conversationID] == nil {
            messages[conversationID] = []
        }
        messages[conversationID]?.append(message)
        
        // Update conversation's last message and activity
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            var conversation = conversations[index]
            conversation.lastMessage = message
            conversation.lastActivity = Date()
            conversations[index] = conversation
        }
        
        // Simulate message delivery
        await simulateMessageDelivery(message)
        
        // Sync to CloudKit
        await syncMessageToCloudKit(message)
        
        // Send push notification to other participants
        await sendNotificationToParticipants(message)
        
        return message
    }
    
    func editMessage(_ messageID: UUID, newContent: MessageContent) async {
        for conversationID in messages.keys {
            if let index = messages[conversationID]?.firstIndex(where: { $0.id == messageID }) {
                var message = messages[conversationID]![index]
                message = Message(conversationID: message.conversationID, senderID: message.senderID, content: newContent)
                messages[conversationID]![index] = message
                
                await syncMessageToCloudKit(message)
                return
            }
        }
    }
    
    func deleteMessage(_ messageID: UUID) async {
        for conversationID in messages.keys {
            messages[conversationID]?.removeAll { $0.id == messageID }
        }
        
        await deleteMessageFromCloudKit(messageID)
    }
    
    func addReaction(to messageID: UUID, emoji: String) async {
        guard let currentUserID = currentUserID else { return }
        
        for conversationID in messages.keys {
            if let index = messages[conversationID]?.firstIndex(where: { $0.id == messageID }) {
                var message = messages[conversationID]![index]
                
                // Remove existing reaction from this user for this emoji
                message.reactions.removeAll { $0.userID == currentUserID && $0.emoji == emoji }
                
                // Add new reaction
                let reaction = MessageReaction(messageID: messageID, userID: currentUserID, emoji: emoji)
                message.reactions.append(reaction)
                
                messages[conversationID]![index] = message
                await syncMessageToCloudKit(message)
                return
            }
        }
    }
    
    func removeReaction(from messageID: UUID, emoji: String) async {
        guard let currentUserID = currentUserID else { return }
        
        for conversationID in messages.keys {
            if let index = messages[conversationID]?.firstIndex(where: { $0.id == messageID }) {
                var message = messages[conversationID]![index]
                message.reactions.removeAll { $0.userID == currentUserID && $0.emoji == emoji }
                messages[conversationID]![index] = message
                
                await syncMessageToCloudKit(message)
                return
            }
        }
    }
    
    func markMessageAsRead(_ messageID: UUID) async {
        guard let currentUserID = currentUserID else { return }
        
        for conversationID in messages.keys {
            if let index = messages[conversationID]?.firstIndex(where: { $0.id == messageID }) {
                var message = messages[conversationID]![index]
                message.readBy[currentUserID] = Date()
                messages[conversationID]![index] = message
                
                // Update conversation unread count
                if let convIndex = conversations.firstIndex(where: { $0.id == conversationID }) {
                    var conversation = conversations[convIndex]
                    conversation.metadata.unreadCount[currentUserID] = max(0, (conversation.metadata.unreadCount[currentUserID] ?? 0) - 1)
                    conversations[convIndex] = conversation
                }
                
                await syncMessageToCloudKit(message)
                return
            }
        }
    }
    
    func markConversationAsRead(_ conversationID: UUID) async {
        guard let currentUserID = currentUserID else { return }
        
        // Mark all messages as read
        if let conversationMessages = messages[conversationID] {
            for index in conversationMessages.indices {
                var message = conversationMessages[index]
                message.readBy[currentUserID] = Date()
                messages[conversationID]![index] = message
            }
        }
        
        // Reset unread count
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            var conversation = conversations[index]
            conversation.metadata.unreadCount[currentUserID] = 0
            conversation.metadata.lastReadTimestamp[currentUserID] = Date()
            conversations[index] = conversation
        }
    }
    
    // MARK: - Typing Indicators
    
    func startTyping(in conversationID: UUID) async {
        guard let currentUserID = currentUserID else { return }
        
        let indicator = TypingIndicator(conversationID: conversationID, userID: currentUserID)
        
        if typingIndicators[conversationID] == nil {
            typingIndicators[conversationID] = []
        }
        
        // Remove existing indicator for this user
        typingIndicators[conversationID]?.removeAll { $0.userID == currentUserID }
        
        // Add new indicator
        typingIndicators[conversationID]?.append(indicator)
        
        // Auto-stop typing after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await stopTyping(in: conversationID)
        }
    }
    
    func stopTyping(in conversationID: UUID) async {
        guard let currentUserID = currentUserID else { return }
        
        typingIndicators[conversationID]?.removeAll { $0.userID == currentUserID }
        
        if typingIndicators[conversationID]?.isEmpty == true {
            typingIndicators.removeValue(forKey: conversationID)
        }
    }
    
    func getTypingUsers(in conversationID: UUID) -> [UUID] {
        guard let indicators = typingIndicators[conversationID] else { return [] }
        let now = Date()
        
        return indicators
            .filter { !$0.isExpired }
            .map { $0.userID }
    }
    
    // MARK: - Message Search
    
    func searchMessages(_ query: MessageSearchQuery) async -> [MessageSearchResult] {
        var results: [MessageSearchResult] = []
        
        for conversation in conversations {
            if let conversationMessages = messages[conversation.id] {
                for message in conversationMessages {
                    if messageMatches(message, query: query) {
                        let context = getMessageContext(message, in: conversationMessages)
                        let result = MessageSearchResult(
                            message: message,
                            conversation: conversation,
                            matchedText: query.text,
                            context: context
                        )
                        results.append(result)
                    }
                }
            }
        }
        
        return results.sorted { $0.message.timestamp > $1.message.timestamp }
    }
    
    private func messageMatches(_ message: Message, query: MessageSearchQuery) -> Bool {
        // Filter by conversation
        if let conversationID = query.conversationID, message.conversationID != conversationID {
            return false
        }
        
        // Filter by sender
        if let senderID = query.senderID, message.senderID != senderID {
            return false
        }
        
        // Filter by date range
        if let dateRange = query.dateRange, !dateRange.contains(message.timestamp) {
            return false
        }
        
        // Filter by content type
        if let contentType = query.contentType {
            switch (contentType, message.content) {
            case (.text, .text), (.media, .media), (.workout, .workout),
                 (.location, .location), (.challenge, .challenge),
                 (.achievement, .achievement), (.voice, .voice):
                break
            default:
                return false
            }
        }
        
        // Filter by media presence
        if let hasMedia = query.hasMedia, message.content.hasMedia != hasMedia {
            return false
        }
        
        // Text search
        return message.content.displayText.localizedCaseInsensitiveContains(query.text)
    }
    
    private func getMessageContext(_ message: Message, in messages: [Message]) -> [Message] {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return [] }
        
        let contextRange = max(0, index - 2)...min(messages.count - 1, index + 2)
        return Array(messages[contextRange])
    }
    
    // MARK: - Data Loading
    
    func loadMessages(for conversationID: UUID) async {
        if messages[conversationID] == nil {
            isLoading = true
            
            // Simulate loading from CloudKit
            await simulateMessageLoading(conversationID)
            
            isLoading = false
        }
    }
    
    func loadMoreMessages(for conversationID: UUID) async {
        guard let existingMessages = messages[conversationID], !existingMessages.isEmpty else { return }
        
        // Simulate loading older messages
        await simulateOlderMessageLoading(conversationID)
    }
    
    // MARK: - Simulation Methods (Replace with real CloudKit implementation)
    
    private func simulateMessageLoading(_ conversationID: UUID) async {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Generate some sample messages
        let sampleMessages = generateSampleMessages(for: conversationID)
        messages[conversationID] = sampleMessages
    }
    
    private func simulateOlderMessageLoading(_ conversationID: UUID) async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Generate older messages
        let olderMessages = generateSampleMessages(for: conversationID, isOlder: true)
        if messages[conversationID] != nil {
            messages[conversationID]!.insert(contentsOf: olderMessages, at: 0)
        }
    }
    
    private func simulateMessageDelivery(_ message: Message) async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
        
        // Update message status
        for conversationID in messages.keys {
            if let index = messages[conversationID]?.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = messages[conversationID]![index]
                updatedMessage.status = .delivered
                messages[conversationID]![index] = updatedMessage
                break
            }
        }
    }
    
    private func generateSampleMessages(for conversationID: UUID, isOlder: Bool = false) -> [Message] {
        let baseDate = isOlder ? Date().addingTimeInterval(-86400 * 7) : Date().addingTimeInterval(-3600)
        let sampleTexts = [
            "Hey! How's your training going?",
            "Just finished a great shuttle run session! 💪",
            "Want to join me for a workout tomorrow?",
            "Check out this achievement I just unlocked!",
            "The weather is perfect for outdoor training today",
            "My heart rate zones look much better now",
            "Thanks for the motivation! 🔥"
        ]
        
        var messages: [Message] = []
        let messageCount = isOlder ? 10 : 5
        
        for i in 0..<messageCount {
            let content = MessageContent.text(sampleTexts.randomElement() ?? "Sample message")
            var message = Message(
                conversationID: conversationID,
                senderID: UUID(), // Random sender ID
                content: content
            )
            
            // Adjust timestamp
            let timeOffset = TimeInterval(i * -300) // 5 minutes apart
            message = Message(conversationID: conversationID, senderID: message.senderID, content: content)
            
            messages.append(message)
        }
        
        return messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Real-time Updates
    
    private func setupRealTimeUpdates() {
        messageUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { await self.checkForNewMessages() }
        }
        
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { await self.cleanupExpiredTypingIndicators() }
        }
    }
    
    private func checkForNewMessages() async {
        // In real implementation, this would check CloudKit for new messages
        connectionStatus = .connected
    }
    
    private func cleanupExpiredTypingIndicators() async {
        let now = Date()
        for conversationID in typingIndicators.keys {
            typingIndicators[conversationID]?.removeAll { indicator in
                now.timeIntervalSince(indicator.lastUpdated) > 5.0
            }
            
            if typingIndicators[conversationID]?.isEmpty == true {
                typingIndicators.removeValue(forKey: conversationID)
            }
        }
    }
    
    private func startConnectionMonitoring() {
        connectionStatus = .connecting
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            connectionStatus = .connected
        }
    }
    
    // MARK: - CloudKit Integration (Placeholder)
    
    private func syncConversationToCloudKit(_ conversation: Conversation) async {
        // Implementation would sync conversation to CloudKit
    }
    
    private func syncMessageToCloudKit(_ message: Message) async {
        // Implementation would sync message to CloudKit
    }
    
    private func deleteConversationFromCloudKit(_ conversationID: UUID) async {
        // Implementation would delete conversation from CloudKit
    }
    
    private func deleteMessageFromCloudKit(_ messageID: UUID) async {
        // Implementation would delete message from CloudKit
    }
    
    private func sendNotificationToParticipants(_ message: Message) async {
        // Implementation would send push notifications to conversation participants
        await notificationService.createSocialNotification(
            type: .directMessage,
            senderID: message.senderID,
            relatedID: message.conversationID.uuidString,
            customMessage: "New message: \(message.content.displayText)"
        )
    }
    
    // MARK: - Data Persistence
    
    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: "cached_conversations")
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: "cached_conversations"),
           let conversations = try? JSONDecoder().decode([Conversation].self, from: data) {
            self.conversations = conversations
        }
    }
    
    // MARK: - Utility Methods
    
    func getUnreadConversationsCount() -> Int {
        guard let currentUserID = currentUserID else { return 0 }
        
        return conversations.filter { conversation in
            let unreadCount = conversation.metadata.unreadCount[currentUserID] ?? 0
            return unreadCount > 0 && !conversation.isArchived(by: currentUserID)
        }.count
    }
    
    func getTotalUnreadCount() -> Int {
        guard let currentUserID = currentUserID else { return 0 }
        
        return conversations.reduce(0) { total, conversation in
            let unreadCount = conversation.metadata.unreadCount[currentUserID] ?? 0
            return total + (conversation.isArchived(by: currentUserID) ? 0 : unreadCount)
        }
    }
    
    func getConversations(excludingArchived: Bool = true) -> [Conversation] {
        guard let currentUserID = currentUserID else { return [] }
        
        if excludingArchived {
            return conversations.filter { !$0.isArchived(by: currentUserID) }
        } else {
            return conversations
        }
    }
    
    func getArchivedConversations() -> [Conversation] {
        guard let currentUserID = currentUserID else { return [] }
        
        return conversations.filter { $0.isArchived(by: currentUserID) }
    }
}
