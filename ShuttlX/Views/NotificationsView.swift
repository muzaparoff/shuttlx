//
//  NotificationsView.swift
//  ShuttlX
//
//  Comprehensive notifications interface with filtering and management
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct NotificationsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @EnvironmentObject var socialService: SocialService
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingSettings = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                NotificationFilterBar(selectedFilter: $selectedFilter)
                
                // Notifications List
                if filteredNotifications.isEmpty {
                    EmptyNotificationsView(filter: selectedFilter)
                } else {
                    NotificationsList(
                        notifications: filteredNotifications,
                        onNotificationTap: handleNotificationTap,
                        onMarkAsRead: markNotificationAsRead,
                        onDelete: deleteNotification
                    )
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if notificationService.unreadCount > 0 {
                            Button("Mark All Read") {
                                Task {
                                    await notificationService.markAllAsRead()
                                }
                            }
                            .font(.subheadline)
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
            }
        }
    }
    
    private var filteredNotifications: [NotificationModel] {
        switch selectedFilter {
        case .all:
            return notificationService.notifications
        case .unread:
            return notificationService.notifications.filter { !$0.isRead }
        case .social:
            return notificationService.getNotifications(for: [
                .newFollower, .followAccepted, .postLiked, .postCommented, .userMentioned
            ])
        case .challenges:
            return notificationService.getNotifications(for: [
                .challengeInvite, .challengeStarted, .challengeCompleted, .challengeWon
            ])
        case .achievements:
            return notificationService.getNotifications(for: [
                .achievementUnlocked, .badgeEarned, .levelUp, .personalRecord
            ])
        case .fitness:
            return notificationService.getNotifications(for: [
                .workoutReminder, .goalAchieved, .recoveryAlert, .heartRateAlert
            ])
        }
    }
    
    private func handleNotificationTap(_ notification: NotificationModel) {
        Task {
            await markNotificationAsRead(notification)
            
            // Handle navigation based on notification type
            switch notification.type {
            case .postLiked, .postCommented, .userMentioned:
                // Navigate to social feed
                break
            case .challengeInvite:
                // Navigate to challenge details
                break
            case .achievementUnlocked:
                // Navigate to achievements
                break
            case .workoutReminder:
                // Navigate to workout
                break
            default:
                break
            }
        }
    }
    
    private func markNotificationAsRead(_ notification: NotificationModel) async {
        await notificationService.markAsRead(notification.id)
    }
    
    private func deleteNotification(_ notification: NotificationModel) {
        Task {
            await notificationService.deleteNotification(notification.id)
        }
    }
}

// MARK: - Filter Bar

struct NotificationFilterBar: View {
    @Binding var selectedFilter: NotificationFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notifications List

struct NotificationsList: View {
    let notifications: [NotificationModel]
    let onNotificationTap: (NotificationModel) -> Void
    let onMarkAsRead: (NotificationModel) async -> Void
    let onDelete: (NotificationModel) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupedNotifications, id: \.id) { group in
                    if group.notifications.count > 1 {
                        GroupedNotificationCard(
                            group: group,
                            onTap: { notification in
                                onNotificationTap(notification)
                            },
                            onMarkAsRead: onMarkAsRead,
                            onDelete: onDelete
                        )
                    } else if let notification = group.notifications.first {
                        NotificationCard(
                            notification: notification,
                            onTap: { onNotificationTap(notification) },
                            onMarkAsRead: { await onMarkAsRead(notification) },
                            onDelete: { onDelete(notification) }
                        )
                    }
                    
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
    }
    
    private var groupedNotifications: [NotificationGroup] {
        return notifications.grouped()
    }
}

// MARK: - Notification Cards

struct NotificationCard: View {
    let notification: NotificationModel
    let onTap: () -> Void
    let onMarkAsRead: () async -> Void
    let onDelete: () -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(notification.type.color).opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .foregroundColor(Color(notification.type.color))
                        .font(.title3)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notification.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(notification.isRead ? Color.clear : Color(.secondarySystemBackground))
            .contextMenu {
                Button(action: { Task { await onMarkAsRead() } }) {
                    Label(notification.isRead ? "Mark as Unread" : "Mark as Read", systemImage: "eye")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GroupedNotificationCard: View {
    let group: NotificationGroup
    let onTap: (NotificationModel) -> Void
    let onMarkAsRead: (NotificationModel) async -> Void
    let onDelete: (NotificationModel) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Group header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(group.type.color).opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: group.type.iconName)
                            .foregroundColor(Color(group.type.color))
                            .font(.title3)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(group.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(group.latestTimestamp.timeAgoShort)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(group.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Expand arrow
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded notifications
            if isExpanded {
                ForEach(group.notifications, id: \.id) { notification in
                    NotificationCard(
                        notification: notification,
                        onTap: { onTap(notification) },
                        onMarkAsRead: { await onMarkAsRead(notification) },
                        onDelete: { onDelete(notification) }
                    )
                    .padding(.leading, 20)
                    
                    if notification.id != group.notifications.last?.id {
                        Divider()
                            .padding(.leading, 88)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyNotificationsView: View {
    let filter: NotificationFilter
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: emptyStateIcon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all, .unread: return "bell.slash"
        case .social: return "person.3"
        case .challenges: return "flag"
        case .achievements: return "medal"
        case .fitness: return "heart"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Notifications"
        case .unread: return "All Caught Up!"
        case .social: return "No Social Activity"
        case .challenges: return "No Challenge Updates"
        case .achievements: return "No New Achievements"
        case .fitness: return "No Fitness Alerts"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "You'll see notifications here when you have new activity."
        case .unread: return "You're up to date with all your notifications."
        case .social: return "Follow friends and join the community to see social notifications."
        case .challenges: return "Join challenges to receive updates and progress notifications."
        case .achievements: return "Complete workouts and reach goals to unlock achievements."
        case .fitness: return "Your fitness reminders and health alerts will appear here."
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var settings: NotificationSettings
    
    init() {
        _settings = State(initialValue: NotificationService.shared.settings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("General") {
                    Toggle("Enable Notifications", isOn: $settings.isEnabled)
                    
                    if settings.isEnabled {
                        Toggle("Sound", isOn: $settings.soundEnabled)
                        Toggle("Badge Count", isOn: $settings.badgeEnabled)
                        Toggle("Show Previews", isOn: $settings.previewEnabled)
                    }
                }
                
                if settings.isEnabled {
                    Section("Categories") {
                        Toggle("Social", isOn: $settings.socialNotifications)
                        Toggle("Challenges", isOn: $settings.challengeNotifications)
                        Toggle("Teams", isOn: $settings.teamNotifications)
                        Toggle("Achievements", isOn: $settings.achievementNotifications)
                        Toggle("Fitness", isOn: $settings.fitnessNotifications)
                        Toggle("System", isOn: $settings.systemNotifications)
                    }
                    
                    Section("Quiet Hours") {
                        Toggle("Enable Quiet Hours", isOn: $settings.quietHoursEnabled)
                        
                        if settings.quietHoursEnabled {
                            DatePicker("Start Time", selection: $settings.quietHoursStart, displayedComponents: .hourAndMinute)
                            DatePicker("End Time", selection: $settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                        }
                    }
                    
                    Section {
                        Button("Clear All Notifications") {
                            Task {
                                await notificationService.clearAllNotifications()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await notificationService.updateSettings(settings)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum NotificationFilter: CaseIterable {
    case all
    case unread
    case social
    case challenges
    case achievements
    case fitness
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .social: return "Social"
        case .challenges: return "Challenges"
        case .achievements: return "Achievements"
        case .fitness: return "Fitness"
        }
    }
}

// MARK: - Extensions

extension Date {
    var timeAgoShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
