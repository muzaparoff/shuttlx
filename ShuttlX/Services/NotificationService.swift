//
//  NotificationService.swift
//  ShuttlX
//
//  MVP-focused notification management service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import UserNotifications
import Combine
import UIKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var unreadCount: Int = 0
    @Published var isAuthorized: Bool = false
    @Published var settings = NotificationSettings()
    
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // Simple notification categories for MVP fitness notifications
    private let notificationCategories: Set<UNNotificationCategory> = {
        var categories = Set<UNNotificationCategory>()
        
        // Workout reminder category
        let workoutActions = [
            UNNotificationAction(identifier: "START_WORKOUT",
                               title: "Start Workout",
                               options: [.foreground]),
            UNNotificationAction(identifier: "DISMISS",
                               title: "Dismiss",
                               options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "WORKOUT_REMINDER",
                                               actions: workoutActions,
                                               intentIdentifiers: []))
        
        // Health reminder category
        let healthActions = [
            UNNotificationAction(identifier: "VIEW_STATS",
                               title: "View Stats",
                               options: [.foreground]),
            UNNotificationAction(identifier: "DISMISS",
                               title: "Dismiss",
                               options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "HEALTH_REMINDER",
                                               actions: healthActions,
                                               intentIdentifiers: []))
        
        return categories
    }()
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
        loadSettings()
    }
    
    // MARK: - Configuration
    
    private func setupNotificationCategories() {
        center.setNotificationCategories(notificationCategories)
    }
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    func checkPermissionStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleWorkoutReminder(title: String, body: String, timeInterval: TimeInterval) async {
        guard settings.workoutReminders && settings.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "WORKOUT_REMINDER"
        content.sound = settings.soundEnabled ? .default : nil
        content.badge = settings.badgeEnabled ? NSNumber(value: unreadCount + 1) : nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            print("🔔 Workout reminder scheduled for \(timeInterval) seconds")
        } catch {
            print("❌ Failed to schedule workout reminder: \(error)")
        }
    }
    
    func scheduleHealthReminder(title: String, body: String, at date: Date) async {
        guard settings.healthReminders && settings.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "HEALTH_REMINDER"
        content.sound = settings.soundEnabled ? .default : nil
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            print("🔔 Health reminder scheduled for \(date)")
        } catch {
            print("❌ Failed to schedule health reminder: \(error)")
        }
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        unreadCount = 0
        updateAppBadge()
    }
    
    func cancelNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    // MARK: - Badge Management
    
    private func updateAppBadge() {
        if settings.badgeEnabled {
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(unreadCount) { error in
                    if let error = error {
                        print("Failed to set badge count: \(error)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = unreadCount
            }
        } else {
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { error in
                    if let error = error {
                        print("Failed to clear badge count: \(error)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    func clearBadge() {
        unreadCount = 0
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("Failed to clear badge count: \(error)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: NotificationSettings) {
        settings = newSettings
        saveSettings()
        
        if !newSettings.isEnabled {
            cancelAllNotifications()
        }
        
        updateAppBadge()
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "notification_settings")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "notification_settings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.settings = settings
        }
    }
    
    // MARK: - Fitness Notifications
    
    func scheduleWorkoutGoalReminder() async {
        await scheduleWorkoutReminder(
            title: "Time for Your Workout! 🏃‍♂️",
            body: "You've got this! Let's crush today's fitness goals.",
            timeInterval: 60 // 1 minute for testing
        )
    }
    
    func scheduleHydrationReminder() async {
        await scheduleHealthReminder(
            title: "Stay Hydrated! 💧",
            body: "Don't forget to drink water and stay healthy.",
            at: Date().addingTimeInterval(2 * 60 * 60) // 2 hours from now
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case "START_WORKOUT":
            // Navigate to workout selection
            print("🏃‍♂️ User wants to start workout")
            
        case "VIEW_STATS":
            // Navigate to stats view
            print("📊 User wants to view stats")
            
        case "DISMISS", UNNotificationDefaultActionIdentifier:
            // Just dismiss
            print("🔕 Notification dismissed")
            
        default:
            break
        }
        
        completionHandler()
    }
}
