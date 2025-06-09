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
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingSettings = false
    @Environment(\.presentationMode) var presentationMode
    @State private var notifications: [NotificationModel] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                NotificationFilterBar(selectedFilter: $selectedFilter)
                
                // Notifications List
                if filteredNotifications.isEmpty {
                    EmptyNotificationsView(filter: selectedFilter)
                } else {
                    SimpleNotificationsList(
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
                        if unreadCount > 0 {
                            Button("Mark All Read") {
                                markAllAsRead()
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
            .onAppear {
                loadNotifications()
            }
        }
    }
    
    private var filteredNotifications: [NotificationModel] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.isRead }
        case .workout:
            return notifications.filter { $0.category == .workout }
        case .health:
            return notifications.filter { $0.category == .health }
        case .achievements:
            return notifications.filter { $0.category == .achievement }
        case .goals:
            return notifications.filter { $0.category == .goal }
        }
    }
    
    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private func loadNotifications() {
        // Create some sample notifications for MVP
        notifications = [
            NotificationModel(title: "Workout Reminder", body: "Time for your morning run!", category: .workout),
            NotificationModel(title: "Health Check", body: "Remember to stay hydrated", category: .health),
            NotificationModel(title: "Goal Achievement", body: "You've reached your daily step goal!", category: .goal),
            NotificationModel(title: "New Achievement", body: "Congratulations! You've unlocked a new badge", category: .achievement)
        ]
    }
    
    private func handleNotificationTap(_ notification: NotificationModel) {
        markNotificationAsRead(notification)
        // Handle navigation based on notification category
        switch notification.category {
        case .workout:
            // Navigate to workout dashboard
            break
        case .achievement:
            // Navigate to achievements
            break
        case .health:
            // Navigate to health stats
            break
        case .goal:
            // Navigate to goals
            break
        }
    }
    
    private func markNotificationAsRead(_ notification: NotificationModel) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
    }
    
    private func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }
    
    private func deleteNotification(_ notification: NotificationModel) {
        notifications.removeAll { $0.id == notification.id }
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

// MARK: - Simple Notifications List

struct SimpleNotificationsList: View {
    let notifications: [NotificationModel]
    let onNotificationTap: (NotificationModel) -> Void
    let onMarkAsRead: (NotificationModel) -> Void
    let onDelete: (NotificationModel) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications, id: \.id) { notification in
                    SimpleNotificationCard(
                        notification: notification,
                        onTap: { onNotificationTap(notification) },
                        onMarkAsRead: { onMarkAsRead(notification) },
                        onDelete: { onDelete(notification) }
                    )
                    
                    if notification.id != notifications.last?.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
        }
    }
}

// MARK: - Simple Notification Card

struct SimpleNotificationCard: View {
    let notification: NotificationModel
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(notification.category.icon.isEmpty ? "blue" : "blue").opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.category.icon)
                        .foregroundColor(.blue)
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
                        
                        Text(notification.timestamp.timeAgoShort)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.body)
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
                Button(action: onMarkAsRead) {
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
        case .workout: return "figure.run"
        case .health: return "heart"
        case .achievements: return "medal"
        case .goals: return "target"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Notifications"
        case .unread: return "All Caught Up!"
        case .workout: return "No Workout Notifications"
        case .health: return "No Health Notifications"
        case .achievements: return "No New Achievements"
        case .goals: return "No Goal Updates"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "You'll see notifications here when you have new activity."
        case .unread: return "You're up to date with all your notifications."
        case .workout: return "Your workout reminders and fitness notifications will appear here."
        case .health: return "Your health reminders and alerts will appear here."
        case .achievements: return "Complete workouts and reach goals to unlock achievements."
        case .goals: return "Your goal progress and completion notifications will appear here."
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
                    }
                }
                
                if settings.isEnabled {
                    Section("Categories") {
                        Toggle("Workout Reminders", isOn: $settings.workoutReminders)
                        Toggle("Health Reminders", isOn: $settings.healthReminders)
                        Toggle("Goal Notifications", isOn: $settings.goalNotifications)
                        Toggle("Achievements", isOn: $settings.achievementNotifications)
                    }
                    
                    Section("Quiet Hours") {
                        Toggle("Enable Quiet Hours", isOn: $settings.quietHoursEnabled)
                        
                        if settings.quietHoursEnabled {
                            HStack {
                                Text("Start Time")
                                Spacer()
                                Text(settings.quietStartTime)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("End Time")
                                Spacer()
                                Text(settings.quietEndTime)
                                    .foregroundColor(.secondary)
                            }
                        }
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
                        notificationService.settings = settings
                        presentationMode.wrappedValue.dismiss()
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
    case workout
    case health
    case achievements
    case goals
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .workout: return "Workout"
        case .health: return "Health"
        case .achievements: return "Achievements"
        case .goals: return "Goals"
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
