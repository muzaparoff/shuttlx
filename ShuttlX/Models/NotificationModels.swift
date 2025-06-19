//
//  NotificationModels.swift
//  ShuttlX
//
//  MVP notification models for fitness app
//  Created by ShuttlX on 6/5/25.
//

import Foundation

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var isEnabled: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    
    // MVP fitness notification types
    var workoutReminders: Bool = true
    var healthReminders: Bool = true
    var goalNotifications: Bool = true
    var achievementNotifications: Bool = true
    
    // Quiet hours
    var quietHoursEnabled: Bool = false
    var quietStartTime: String = "22:00"
    var quietEndTime: String = "07:00"
    
    init() {
        // Default values already set above
    }
}

// MARK: - Simple Notification Model for MVP

struct SimpleNotification: Identifiable, Codable {
    var id = UUID()
    let title: String
    let body: String
    let category: NotificationCategory
    let timestamp: Date
    var isRead: Bool = false
    
    init(title: String, body: String, category: NotificationCategory) {
        self.title = title
        self.body = body
        self.category = category
        self.timestamp = Date()
    }
}

// MARK: - Notification Categories for MVP

enum NotificationCategory: String, CaseIterable, Codable {
    case workout = "workout"
    case health = "health"
    case goal = "goal"
    case achievement = "achievement"
    
    var displayName: String {
        switch self {
        case .workout:
            return "Workout Reminders"
        case .health:
            return "Health Reminders"
        case .goal:
            return "Goal Updates"
        case .achievement:
            return "Achievements"
        }
    }
    
    var icon: String {
        switch self {
        case .workout:
            return "figure.run"
        case .health:
            return "heart.fill"
        case .goal:
            return "target"
        case .achievement:
            return "trophy.fill"
        }
    }
}

// MARK: - Type Aliases and Groups for View Compatibility

typealias NotificationModel = SimpleNotification

struct NotificationGroup: Identifiable {
    let id = UUID()
    let title: String
    let notifications: [NotificationModel]
    let date: Date
    
    init(title: String, notifications: [NotificationModel]) {
        self.title = title
        self.notifications = notifications
        self.date = notifications.first?.timestamp ?? Date()
    }
}