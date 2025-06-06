import Foundation
import Combine
import Network

@MainActor
class RealTimeMessagingService: ObservableObject {
    static let shared = RealTimeMessagingService()
    
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var conversations: [Conversation] = []
    @Published var unreadMessagesCount: Int = 0
    @Published var typingIndicators: [UUID: Set<UUID>] = [:] // ConversationID -> Set of UserIDs
    @Published var onlineUsers: Set<UUID> = []
    
    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var typingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var apiService: APIService?
    
    // Message queues for offline support
    private var pendingMessages: [Message] = []
    private var messageRetryQueue: [Message] = []
    
    // Reconnection settings
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 2.0
    
    enum ConnectionStatus {
        case connecting
        case connected
        case disconnected
        case reconnecting
        case error(String)
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
        
        setupNetworkMonitoring()
        loadCachedConversations()
    }
    
    func configure(with apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard connectionStatus != .connected && connectionStatus != .connecting else { return }
        guard let apiService = apiService else {
            connectionStatus = .error("API Service not configured")
            return
        }
        
        connectionStatus = .connecting
        
        guard let baseURL = URL(string: apiService.baseURL),
              let wsURL = URL(string: "wss://\(baseURL.host ?? "api.shuttlx.app")/ws/messaging") else {
            connectionStatus = .error("Invalid WebSocket URL")
            return
        }
        
        var request = URLRequest(url: wsURL)
        if let token = apiService.getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        startListening()
        startHeartbeat()
        
        connectionStatus = .connected
        reconnectAttempts = 0
        
        // Send pending messages
        sendPendingMessages()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        
        stopHeartbeat()
        stopReconnectTimer()
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionStatus = .error("Max reconnection attempts reached")
            return
        }
        
        connectionStatus = .reconnecting
        reconnectAttempts += 1
        
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                self.connect()
            }
        }
    }
    
    // MARK: - Message Listening
    
    private func startListening() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    await self?.handleWebSocketMessage(message)
                    self?.startListening() // Continue listening
                    
                case .failure(let error):
                    self?.handleWebSocketError(error)
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await processTextMessage(text)
        case .data(let data):
            await processBinaryMessage(data)
        @unknown default:
            print("Unknown WebSocket message type")
        }
    }
    
    private func processTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            await processMessageEnvelope(envelope)
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func processBinaryMessage(_ data: Data) async {
        // Handle binary messages (e.g., media, file transfers)
        // Implementation depends on your protocol
    }
    
    private func processMessageEnvelope(_ envelope: MessageEnvelope) async {
        switch envelope.type {
        case .message:
            await handleNewMessage(envelope)
        case .messageStatus:
            await handleMessageStatus(envelope)
        case .typing:
            await handleTypingIndicator(envelope)
        case .userPresence:
            await handleUserPresence(envelope)
        case .conversationUpdate:
            await handleConversationUpdate(envelope)
        case .reaction:
            await handleMessageReaction(envelope)
        }
    }
    
    // MARK: - Message Handling
    
    private func handleNewMessage(_ envelope: MessageEnvelope) async {
        guard let messageData = envelope.data,
              let message = try? JSONDecoder().decode(Message.self, from: messageData) else {
            return
        }
        
        // Update conversation with new message
        if let conversationIndex = conversations.firstIndex(where: { $0.id == message.conversationID }) {
            conversations[conversationIndex].lastMessage = message
            conversations[conversationIndex].lastActivity = message.timestamp
            
            // Update unread count if message is from someone else
            if message.senderID != getCurrentUserID() {
                updateUnreadCount(for: message.conversationID, increment: true)
            }
        }
        
        // Cache message locally
        await cacheMessage(message)
        
        // Send delivery confirmation
        await sendMessageStatus(messageID: message.id, status: .delivered)
        
        // Trigger haptic feedback for important messages
        triggerHapticFeedback(for: message)
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: message
        )
    }
    
    private func handleMessageStatus(_ envelope: MessageEnvelope) async {
        guard let statusData = envelope.data,
              let statusUpdate = try? JSONDecoder().decode(MessageStatusUpdate.self, from: statusData) else {
            return
        }
        
        // Update message status in cache
        await updateMessageStatus(messageID: statusUpdate.messageID, status: statusUpdate.status)
    }
    
    private func handleTypingIndicator(_ envelope: MessageEnvelope) async {
        guard let typingData = envelope.data,
              let typingIndicator = try? JSONDecoder().decode(TypingIndicator.self, from: typingData) else {
            return
        }
        
        if typingIndicator.isTyping {
            var usersTyping = typingIndicators[typingIndicator.conversationID] ?? Set<UUID>()
            usersTyping.insert(typingIndicator.userID)
            typingIndicators[typingIndicator.conversationID] = usersTyping
        } else {
            typingIndicators[typingIndicator.conversationID]?.remove(typingIndicator.userID)
            if typingIndicators[typingIndicator.conversationID]?.isEmpty == true {
                typingIndicators.removeValue(forKey: typingIndicator.conversationID)
            }
        }
    }
    
    private func handleUserPresence(_ envelope: MessageEnvelope) async {
        guard let presenceData = envelope.data,
              let presence = try? JSONDecoder().decode(UserPresence.self, from: presenceData) else {
            return
        }
        
        if presence.isOnline {
            onlineUsers.insert(presence.userID)
        } else {
            onlineUsers.remove(presence.userID)
        }
    }
    
    private func handleConversationUpdate(_ envelope: MessageEnvelope) async {
        guard let conversationData = envelope.data,
              let updatedConversation = try? JSONDecoder().decode(Conversation.self, from: conversationData) else {
            return
        }
        
        if let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
            conversations[index] = updatedConversation
        } else {
            conversations.append(updatedConversation)
        }
        
        await cacheConversation(updatedConversation)
    }
    
    private func handleMessageReaction(_ envelope: MessageEnvelope) async {
        guard let reactionData = envelope.data,
              let reaction = try? JSONDecoder().decode(MessageReactionUpdate.self, from: reactionData) else {
            return
        }
        
        // Update message reaction in cache
        await updateMessageReaction(messageID: reaction.messageID, reaction: reaction.reaction)
    }
    
    // MARK: - Sending Messages
    
    func sendMessage(_ message: Message) async {
        // Add to pending queue if offline
        if connectionStatus != .connected {
            pendingMessages.append(message)
            await cacheMessage(message)
            return
        }
        
        let envelope = MessageEnvelope(
            type: .message,
            data: try? JSONEncoder().encode(message)
        )
        
        await sendMessageEnvelope(envelope)
        await cacheMessage(message)
    }
    
    func sendTypingIndicator(conversationID: UUID, isTyping: Bool) async {
        let indicator = TypingIndicator(
            conversationID: conversationID,
            userID: getCurrentUserID(),
            isTyping: isTyping
        )
        
        let envelope = MessageEnvelope(
            type: .typing,
            data: try? JSONEncoder().encode(indicator)
        )
        
        await sendMessageEnvelope(envelope)
    }
    
    func markMessageAsRead(_ messageID: UUID) async {
        let statusUpdate = MessageStatusUpdate(
            messageID: messageID,
            status: .read,
            userID: getCurrentUserID()
        )
        
        let envelope = MessageEnvelope(
            type: .messageStatus,
            data: try? JSONEncoder().encode(statusUpdate)
        )
        
        await sendMessageEnvelope(envelope)
    }
    
    func sendMessageReaction(messageID: UUID, reaction: MessageReaction) async {
        let reactionUpdate = MessageReactionUpdate(
            messageID: messageID,
            reaction: reaction
        )
        
        let envelope = MessageEnvelope(
            type: .reaction,
            data: try? JSONEncoder().encode(reactionUpdate)
        )
        
        await sendMessageEnvelope(envelope)
    }
    
    private func sendMessageEnvelope(_ envelope: MessageEnvelope) async {
        guard let webSocketTask = webSocketTask,
              let data = try? JSONEncoder().encode(envelope),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        do {
            try await webSocketTask.send(.string(jsonString))
        } catch {
            // Add to retry queue
            if let messageData = envelope.data,
               let message = try? JSONDecoder().decode(Message.self, from: messageData) {
                messageRetryQueue.append(message)
            }
            
            // Trigger reconnection if needed
            if connectionStatus == .connected {
                reconnect()
            }
        }
    }
    
    // MARK: - Pending Messages
    
    private func sendPendingMessages() {
        let messages = pendingMessages
        pendingMessages.removeAll()
        
        Task {
            for message in messages {
                await sendMessage(message)
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied && self?.connectionStatus == .disconnected {
                    self?.connect()
                } else if path.status != .satisfied && self?.connectionStatus == .connected {
                    self?.connectionStatus = .disconnected
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await self.sendHeartbeat()
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() async {
        let heartbeat = MessageEnvelope(type: .heartbeat, data: nil)
        await sendMessageEnvelope(heartbeat)
    }
    
    // MARK: - Helper Methods
    
    private func handleWebSocketError(_ error: Error) {
        print("WebSocket error: \(error)")
        connectionStatus = .error(error.localizedDescription)
        reconnect()
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func getAuthToken() -> String? {
        return apiService?.getAuthToken()
    }
    
    private func getCurrentUserID() -> UUID {
        return apiService?.getCurrentUserId() ?? UUID()
    }
    
    private func updateUnreadCount(for conversationID: UUID, increment: Bool) {
        if increment {
            unreadMessagesCount += 1
        } else {
            unreadMessagesCount = max(0, unreadMessagesCount - 1)
        }
    }
    
    private func triggerHapticFeedback(for message: Message) {
        // Implement haptic feedback based on message importance
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Caching
    
    private func loadCachedConversations() {
        // Load conversations from local cache
        // Implementation would use Core Data or similar
    }
    
    private func cacheMessage(_ message: Message) async {
        // Cache message locally for offline access
        // Implementation would use Core Data or similar
    }
    
    private func cacheConversation(_ conversation: Conversation) async {
        // Cache conversation locally
        // Implementation would use Core Data or similar
    }
    
    private func updateMessageStatus(messageID: UUID, status: MessageStatus) async {
        // Update cached message status
        // Implementation would update local cache
    }
    
    private func updateMessageReaction(messageID: UUID, reaction: MessageReaction) async {
        // Update cached message reaction
        // Implementation would update local cache
    }
}

// MARK: - Supporting Models

struct MessageEnvelope: Codable {
    let type: MessageType
    let data: Data?
    let timestamp: Date
    
    init(type: MessageType, data: Data?) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

enum MessageType: String, Codable {
    case message
    case messageStatus
    case typing
    case userPresence
    case conversationUpdate
    case reaction
    case heartbeat
}

struct MessageStatusUpdate: Codable {
    let messageID: UUID
    let status: MessageStatus
    let userID: UUID
    let timestamp: Date
    
    init(messageID: UUID, status: MessageStatus, userID: UUID) {
        self.messageID = messageID
        self.status = status
        self.userID = userID
        self.timestamp = Date()
    }
}

struct TypingIndicator: Codable {
    let conversationID: UUID
    let userID: UUID
    let isTyping: Bool
    let timestamp: Date
    
    init(conversationID: UUID, userID: UUID, isTyping: Bool) {
        self.conversationID = conversationID
        self.userID = userID
        self.isTyping = isTyping
        self.timestamp = Date()
    }
}

struct UserPresence: Codable {
    let userID: UUID
    let isOnline: Bool
    let lastSeen: Date?
    let status: String?
    
    init(userID: UUID, isOnline: Bool, lastSeen: Date? = nil, status: String? = nil) {
        self.userID = userID
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.status = status
    }
}

struct MessageReactionUpdate: Codable {
    let messageID: UUID
    let reaction: MessageReaction
    let timestamp: Date
    
    init(messageID: UUID, reaction: MessageReaction) {
        self.messageID = messageID
        self.reaction = reaction
        self.timestamp = Date()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
    static let messageStatusUpdated = Notification.Name("messageStatusUpdated")
    static let conversationUpdated = Notification.Name("conversationUpdated")
}

// MARK: - API Integration
    
extension RealTimeMessagingService {
    func loadConversations() async throws {
        guard let apiService = apiService else {
            throw MessagingError.apiServiceNotConfigured
        }
        
        let response = try await apiService.getConversations()
        conversations = response.conversations
        unreadMessagesCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    func createConversation(with participants: [UUID]) async throws -> Conversation {
        guard let apiService = apiService else {
            throw MessagingError.apiServiceNotConfigured
        }
        
        let response = try await apiService.createConversation(participants: participants)
        conversations.append(response.conversation)
        return response.conversation
    }
    
    func loadMessages(for conversationID: UUID) async throws -> [Message] {
        guard let apiService = apiService else {
            throw MessagingError.apiServiceNotConfigured
        }
        
        let response = try await apiService.getMessages(conversationId: conversationID)
        return response.messages
    }
}

// MARK: - Messaging Errors

enum MessagingError: LocalizedError {
    case apiServiceNotConfigured
    case connectionFailed
    case messageDeliveryFailed
    case invalidMessage
    
    var errorDescription: String? {
        switch self {
        case .apiServiceNotConfigured:
            return "API Service not configured"
        case .connectionFailed:
            return "Failed to connect to messaging service"
        case .messageDeliveryFailed:
            return "Failed to deliver message"
        case .invalidMessage:
            return "Invalid message format"
        }
    }
}
