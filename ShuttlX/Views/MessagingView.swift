//
//  MessagingView.swift
//  ShuttlX
//
//  Direct messaging and chat interface with real-time features
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct MessagingView: View {
    @StateObject private var messagingService = MessagingService.shared
    @EnvironmentObject var socialService: SocialService
    @State private var showingNewConversation = false
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status
                if messagingService.connectionStatus != .connected {
                    ConnectionStatusBar(status: messagingService.connectionStatus)
                }
                
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Conversations List
                if filteredConversations.isEmpty {
                    EmptyMessagingView(hasSearchText: !searchText.isEmpty)
                } else {
                    ConversationsList(
                        conversations: filteredConversations,
                        onConversationTap: openConversation
                    )
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewConversation = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView()
            }
        }
    }
    
    private var filteredConversations: [Conversation] {
        let conversations = messagingService.conversations
        
        if searchText.isEmpty {
            return conversations.sorted { $0.lastActivity > $1.lastActivity }
        } else {
            return conversations.filter { conversation in
                conversation.displayName.localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage?.content.displayText.localizedCaseInsensitiveContains(searchText) == true
            }.sorted { $0.lastActivity > $1.lastActivity }
        }
    }
    
    private func openConversation(_ conversation: Conversation) {
        messagingService.activeConversation = conversation
        // Navigation would be handled by parent view
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    let status: MessagingService.ConnectionStatus
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.caption)
            
            Text(status.displayText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
    }
    
    private var statusIcon: String {
        switch status {
        case .connected: return "wifi"
        case .connecting: return "wifi.exclamationmark"
        case .disconnected: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Conversations List

struct ConversationsList: View {
    let conversations: [Conversation]
    let onConversationTap: (Conversation) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(conversations, id: \.id) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        onTap: { onConversationTap(conversation) }
                    )
                    
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let onTap: () -> Void
    
    @StateObject private var messagingService = MessagingService.shared
    @State private var showingConversationOptions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ConversationAvatar(conversation: conversation)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if let lastMessage = conversation.lastMessage {
                                MessageStatusIcon(status: lastMessage.status)
                            }
                            
                            Text(conversation.timeAgo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        // Last message preview
                        if let lastMessage = conversation.lastMessage {
                            LastMessagePreview(message: lastMessage)
                        } else {
                            Text("No messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        Spacer()
                        
                        // Unread count and indicators
                        HStack(spacing: 8) {
                            if isTyping {
                                TypingIndicator()
                            }
                            
                            if unreadCount > 0 {
                                UnreadBadge(count: unreadCount)
                            }
                            
                            if conversation.isMuted(by: currentUserID) {
                                Image(systemName: "bell.slash.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            if conversation.isPinned(by: currentUserID) {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(conversation.isPinned(by: currentUserID) ? Color(.secondarySystemBackground) : Color.clear)
            .contextMenu {
                ConversationContextMenu(conversation: conversation)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var currentUserID: UUID {
        // Get from messaging service or user defaults
        return UUID() // Placeholder
    }
    
    private var unreadCount: Int {
        conversation.unreadCount(for: currentUserID)
    }
    
    private var isTyping: Bool {
        let typingUsers = messagingService.getTypingUsers(in: conversation.id)
        return !typingUsers.filter { $0 != currentUserID }.isEmpty
    }
}

// MARK: - Supporting Views

struct ConversationAvatar: View {
    let conversation: Conversation
    
    var body: some View {
        ZStack {
            if let imageURL = conversation.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray4)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(conversation.type.iconName))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: conversation.type.iconName)
                            .foregroundColor(.white)
                            .font(.title3)
                    )
            }
            
            // Online indicator for direct conversations
            if conversation.type == .direct {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 16, y: 16)
            }
        }
    }
}

struct LastMessagePreview: View {
    let message: Message
    
    var body: some View {
        HStack(spacing: 4) {
            if message.senderID == currentUserID {
                Text("You:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var currentUserID: UUID {
        // Get from messaging service or user defaults
        return UUID() // Placeholder
    }
}

struct MessageStatusIcon: View {
    let status: MessageStatus
    
    var body: some View {
        Image(systemName: status.iconName)
            .foregroundColor(statusColor)
            .font(.caption2)
    }
    
    private var statusColor: Color {
        switch status {
        case .sending: return .gray
        case .sent: return .gray
        case .delivered: return .blue
        case .read: return .blue
        case .failed: return .red
        }
    }
}

struct TypingIndicator: View {
    @State private var animateScale = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 4)
                    .scaleEffect(animateScale ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animateScale
                    )
            }
        }
        .onAppear {
            animateScale = true
        }
    }
}

struct UnreadBadge: View {
    let count: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: count > 99 ? 24 : 18, height: 18)
            
            Text("\(min(count, 99))")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct ConversationContextMenu: View {
    let conversation: Conversation
    @StateObject private var messagingService = MessagingService.shared
    
    var body: some View {
        Group {
            Button(action: { togglePin() }) {
                Label(
                    conversation.isPinned(by: currentUserID) ? "Unpin" : "Pin",
                    systemImage: conversation.isPinned(by: currentUserID) ? "pin.slash" : "pin"
                )
            }
            
            Button(action: { toggleMute() }) {
                Label(
                    conversation.isMuted(by: currentUserID) ? "Unmute" : "Mute",
                    systemImage: conversation.isMuted(by: currentUserID) ? "bell" : "bell.slash"
                )
            }
            
            Button(action: { markAsRead() }) {
                Label("Mark as Read", systemImage: "eye")
            }
            
            Button(action: { archiveConversation() }) {
                Label("Archive", systemImage: "archivebox")
            }
            
            Divider()
            
            Button(role: .destructive, action: { deleteConversation() }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var currentUserID: UUID {
        // Get from messaging service or user defaults
        return UUID() // Placeholder
    }
    
    private func togglePin() {
        Task {
            if conversation.isPinned(by: currentUserID) {
                await messagingService.unpinConversation(conversation.id, for: currentUserID)
            } else {
                await messagingService.pinConversation(conversation.id, for: currentUserID)
            }
        }
    }
    
    private func toggleMute() {
        Task {
            if conversation.isMuted(by: currentUserID) {
                await messagingService.unmuteConversation(conversation.id, for: currentUserID)
            } else {
                await messagingService.muteConversation(conversation.id, for: currentUserID)
            }
        }
    }
    
    private func markAsRead() {
        Task {
            await messagingService.markConversationAsRead(conversation.id)
        }
    }
    
    private func archiveConversation() {
        Task {
            await messagingService.archiveConversation(conversation.id, for: currentUserID)
        }
    }
    
    private func deleteConversation() {
        Task {
            await messagingService.deleteConversation(conversation.id)
        }
    }
}

// MARK: - Empty State

struct EmptyMessagingView: View {
    let hasSearchText: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: hasSearchText ? "magnifyingglass" : "message")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(hasSearchText ? "No Results" : "No Messages")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(hasSearchText ? 
                     "Try searching for a different term." :
                     "Start a conversation with your training partners and teammates.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if !hasSearchText {
                Button("Start New Conversation") {
                    // Action to start new conversation
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
    }
}

// MARK: - New Conversation View

struct NewConversationView: View {
    @EnvironmentObject var socialService: SocialService
    @StateObject private var messagingService = MessagingService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var selectedUsers: Set<UUID> = []
    @State private var conversationType: ConversationType = .direct
    
    var body: some View {
        NavigationView {
            VStack {
                // Conversation Type Picker
                Picker("Type", selection: $conversationType) {
                    Text("Direct").tag(ConversationType.direct)
                    Text("Group").tag(ConversationType.group)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                // Users List
                UsersList(
                    searchText: searchText,
                    selectedUsers: $selectedUsers,
                    maxSelection: conversationType.maxParticipants - 1
                )
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createConversation()
                    }
                    .disabled(selectedUsers.isEmpty)
                }
            }
        }
    }
    
    private func createConversation() {
        Task {
            let participants = Array(selectedUsers)
            let conversation = await messagingService.createGroupConversation(
                with: participants,
                type: conversationType
            )
            
            if conversation != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Users List

struct UsersList: View {
    let searchText: String
    @Binding var selectedUsers: Set<UUID>
    let maxSelection: Int
    
    @EnvironmentObject var socialService: SocialService
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers, id: \.id) { user in
                    UserSelectionRow(
                        user: user,
                        isSelected: selectedUsers.contains(user.id),
                        canSelect: selectedUsers.count < maxSelection || selectedUsers.contains(user.id),
                        onToggle: { toggleUser(user.id) }
                    )
                    
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
    }
    
    private var filteredUsers: [UserProfile] {
        let users = socialService.following // Use following list
        
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func toggleUser(_ userID: UUID) {
        if selectedUsers.contains(userID) {
            selectedUsers.remove(userID)
        } else if selectedUsers.count < maxSelection {
            selectedUsers.insert(userID)
        }
    }
}

struct UserSelectionRow: View {
    let user: UserProfile
    let isSelected: Bool
    let canSelect: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            )
                    }
                }
            }
            .padding()
            .opacity(canSelect ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect)
    }
}

// MARK: - Individual Chat View

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var messagingService = MessagingService.shared
    @State private var messageText = ""
    @State private var showingAttachments = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            MessagesListView(
                conversation: conversation,
                messages: messages
            )
            
            // Typing Indicator
            if !typingUsers.isEmpty {
                TypingIndicatorView(typingUsers: typingUsers)
            }
            
            // Message Input
            MessageInputView(
                messageText: $messageText,
                onSend: sendMessage,
                onAttachment: { showingAttachments = true }
            )
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { /* Show conversation info */ }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingAttachments) {
            AttachmentPicker { attachment in
                sendAttachment(attachment)
            }
        }
        .onAppear {
            messagingService.activeConversation = conversation
            Task {
                await messagingService.markConversationAsRead(conversation.id)
            }
        }
        .onDisappear {
            messagingService.activeConversation = nil
        }
    }
    
    private var messages: [Message] {
        messagingService.messages[conversation.id] ?? []
    }
    
    private var typingUsers: [UUID] {
        messagingService.getTypingUsers(in: conversation.id)
            .filter { $0 != currentUserID }
    }
    
    private var currentUserID: UUID {
        // Get from messaging service or user defaults
        return UUID() // Placeholder
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            let content = MessageContent.text(messageText)
            await messagingService.sendMessage(to: conversation.id, content: content)
            messageText = ""
        }
    }
    
    private func sendAttachment(_ attachment: MediaAttachment) {
        Task {
            let content = MessageContent.media([attachment])
            await messagingService.sendMessage(to: conversation.id, content: content)
        }
    }
}

// MARK: - Messages List View

struct MessagesListView: View {
    let conversation: Conversation
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(groupedMessages, id: \.id) { group in
                        MessageGroup(group: group)
                    }
                }
                .padding()
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private var groupedMessages: [MessageGroup] {
        // Group consecutive messages from same sender
        var groups: [MessageGroup] = []
        var currentGroup: [Message] = []
        var lastSenderID: UUID?
        
        for message in messages {
            if message.senderID != lastSenderID || 
               (currentGroup.last?.timestamp.timeIntervalSince(message.timestamp) ?? 0) > 300 { // 5 minutes
                if !currentGroup.isEmpty {
                    groups.append(MessageGroup(messages: currentGroup))
                }
                currentGroup = [message]
            } else {
                currentGroup.append(message)
            }
            lastSenderID = message.senderID
        }
        
        if !currentGroup.isEmpty {
            groups.append(MessageGroup(messages: currentGroup))
        }
        
        return groups
    }
    
    private func scrollToBottom(proxy: ScrollViewReader) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct MessageGroup: Identifiable {
    let id = UUID()
    let messages: [Message]
    
    var senderID: UUID {
        messages.first?.senderID ?? UUID()
    }
    
    var timestamp: Date {
        messages.first?.timestamp ?? Date()
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    let onAttachment: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 8) {
                // Attachment button
                Button(action: onAttachment) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                }
                
                // Text input
                HStack {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !messageText.isEmpty {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    let typingUsers: [UUID]
    
    var body: some View {
        HStack {
            TypingIndicator()
            
            Text(typingText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }
    
    private var typingText: String {
        if typingUsers.count == 1 {
            return "Someone is typing..."
        } else {
            return "\(typingUsers.count) people are typing..."
        }
    }
}

// MARK: - Attachment Picker

struct AttachmentPicker: View {
    let onSelection: (MediaAttachment) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Attachment picker placeholder")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
