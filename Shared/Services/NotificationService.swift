//
//  NotificationService.swift
//  ShuttlX
//
//  Comprehensive notification management service
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import UserNotifications
import Combine
import CloudKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [NotificationModel] = []
    @Published var unreadCount: Int = 0
    @Published var settings: NotificationSettings = .default
    @Published var isAuthorized: Bool = false
    
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    private var apiService: APIService?
    
    // Notification categories for interactive notifications
    private let notificationCategories: Set<UNNotificationCategory> = {
        var categories = Set<UNNotificationCategory>()
        
        // Social category with like and comment actions
        let socialActions = [
            UNNotificationAction(identifier: NotificationAction.like.rawValue,
                               title: NotificationAction.like.title,
                               options: []),
            UNNotificationAction(identifier: NotificationAction.comment.rawValue,
                               title: NotificationAction.comment.title,
                               options: [.foreground]),
            UNNotificationAction(identifier: NotificationAction.follow.rawValue,
                               title: NotificationAction.follow.title,
                               options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "SOCIAL_CATEGORY",
                                               actions: socialActions,
                                               intentIdentifiers: []))
        
        // Challenge category with accept/decline actions
        let challengeActions = [
            UNNotificationAction(identifier: NotificationAction.acceptChallenge.rawValue,
                               title: NotificationAction.acceptChallenge.title,
                               options: []),
            UNNotificationAction(identifier: NotificationAction.declineChallenge.rawValue,
                               title: NotificationAction.declineChallenge.title,
                               options: [.destructive])
        ]
        categories.insert(UNNotificationCategory(identifier: "CHALLENGE_CATEGORY",
                                               actions: challengeActions,
                                               intentIdentifiers: []))
        
        // Team category with join action
        let teamActions = [
            UNNotificationAction(identifier: NotificationAction.joinTeam.rawValue,
                               title: NotificationAction.joinTeam.title,
                               options: []),
            UNNotificationAction(identifier: NotificationAction.viewPost.rawValue,
                               title: NotificationAction.viewPost.title,
                               options: [.foreground])
        ]
        categories.insert(UNNotificationCategory(identifier: "TEAM_CATEGORY",
                                               actions: teamActions,
                                               intentIdentifiers: []))
        
        // Message category with reply action
        let messageActions = [
            UNNotificationAction(identifier: NotificationAction.reply.rawValue,
                               title: NotificationAction.reply.title,
                               options: [.foreground]),
            UNNotificationAction(identifier: NotificationAction.markAsRead.rawValue,
                               title: NotificationAction.markAsRead.title,
                               options: [])
        ]
        categories.insert(UNNotificationCategory(identifier: "MESSAGE_CATEGORY",
                                               actions: messageActions,
                                               intentIdentifiers: []))
        
        return categories
    }()
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
        loadNotifications()
        loadSettings()
        
        // Update unread count when notifications change
        $notifications
            .map { $0.unreadCount }
            .assign(to: &$unreadCount)
    }
    
    // MARK: - Configuration
    
    func configure(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.getNotificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(_ notification: NotificationModel) async {
        guard settings.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = settings.soundEnabled ? .default : nil
        content.badge = settings.badgeEnabled ? NSNumber(value: unreadCount + 1) : nil
        content.categoryIdentifier = getCategoryIdentifier(for: notification.type)
        
        // Add custom data
        var userInfo: [String: Any] = [
            "notificationId": notification.id.uuidString,
            "type": notification.type.rawValue
        ]
        
        if let senderID = notification.senderID {
            userInfo["senderId"] = senderID.uuidString
        }
        
        if let relatedID = notification.relatedID {
            userInfo["relatedId"] = relatedID
        }
        
        content.userInfo = userInfo
        
        // Create trigger (immediate delivery)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Error scheduling local notification: \(error)")
        }
    }
    
    func scheduleWorkoutReminder(at date: Date, workoutType: String) async {
        guard settings.fitnessNotifications && settings.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Workout Reminder"
        content.body = "Time for your \(workoutType) workout! Let's get moving! 💪"
        content.sound = settings.soundEnabled ? .default : nil
        content.categoryIdentifier = "FITNESS_CATEGORY"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "workout_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
        } catch {
            print("Error scheduling workout reminder: \(error)")
        }
    }
    
    // MARK: - Push Notifications
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let notificationData = parseRemoteNotification(userInfo) else { return }
        
        let notification = NotificationModel(
            type: notificationData.type,
            title: notificationData.title,
            message: notificationData.message,
            senderID: notificationData.senderID,
            relatedID: notificationData.relatedID
        )
        
        await addNotification(notification)
        
        // Update badge count
        if settings.badgeEnabled {
            await MainActor.run {
                UIApplication.shared.applicationIconBadgeNumber = self.unreadCount
            }
        }
    }
    
    private func parseRemoteNotification(_ userInfo: [AnyHashable: Any]) -> (type: NotificationType, title: String, message: String, senderID: UUID?, relatedID: String?)? {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let title = alert["title"] as? String,
              let body = alert["body"] as? String,
              let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return nil
        }
        
        let senderID = (userInfo["senderId"] as? String).flatMap { UUID(uuidString: $0) }
        let relatedID = userInfo["relatedId"] as? String
        
        return (type, title, body, senderID, relatedID)
    }
    
    // MARK: - Notification Management
    
    func addNotification(_ notification: NotificationModel) async {
        await MainActor.run {
            // Check for duplicates
            if !notifications.contains(where: { $0.id == notification.id }) {
                notifications.insert(notification, at: 0)
                
                // Limit to 1000 notifications
                if notifications.count > 1000 {
                    notifications = Array(notifications.prefix(1000))
                }
                
                saveNotifications()
            }
        }
        
        // Sync to CloudKit if needed
        await syncNotificationToCloudKit(notification)
    }
    
    func markAsRead(_ notificationID: UUID) async {
        await MainActor.run {
            if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
                var notification = notifications[index]
                notification = notification.withRead(true)
                notifications[index] = notification
                saveNotifications()
            }
        }
    }
    
    func markAllAsRead() async {
        await MainActor.run {
            for index in notifications.indices {
                var notification = notifications[index]
                if !notification.isRead {
                    notification = notification.withRead(true)
                    notifications[index] = notification
                }
            }
            saveNotifications()
        }
        
        // Reset badge count
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    func deleteNotification(_ notificationID: UUID) async {
        await MainActor.run {
            notifications.removeAll { $0.id == notificationID }
            saveNotifications()
        }
        
        // Remove from notification center
        center.removeDeliveredNotifications(withIdentifiers: [notificationID.uuidString])
    }
    
    func clearAllNotifications() async {
        await MainActor.run {
            notifications.removeAll()
            saveNotifications()
        }
        
        // Remove all from notification center
        center.removeAllDeliveredNotifications()
        
        // Reset badge count
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    // MARK: - Notification Creation Helpers
    
    func createSocialNotification(type: NotificationType, senderID: UUID, relatedID: String? = nil, customMessage: String? = nil) async {
        let title: String
        let message: String
        
        switch type {
        case .newFollower:
            title = "New Follower"
            message = customMessage ?? "Someone started following you!"
        case .postLiked:
            title = "Post Liked"
            message = customMessage ?? "Someone liked your post!"
        case .postCommented:
            title = "New Comment"
            message = customMessage ?? "Someone commented on your post!"
        case .userMentioned:
            title = "You were mentioned"
            message = customMessage ?? "You were mentioned in a post!"
        default:
            title = type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
            message = customMessage ?? "You have a new notification"
        }
        
        let notification = NotificationModel(
            type: type,
            title: title,
            message: message,
            senderID: senderID,
            relatedID: relatedID
        )
        
        await addNotification(notification)
        await scheduleLocalNotification(notification)
    }
    
    func createChallengeNotification(type: NotificationType, challengeID: String, challengeName: String, senderID: UUID? = nil) async {
        let title: String
        let message: String
        
        switch type {
        case .challengeInvite:
            title = "Challenge Invitation"
            message = "You've been invited to join \"\(challengeName)\"!"
        case .challengeStarted:
            title = "Challenge Started"
            message = "\"\(challengeName)\" has begun! Time to show what you've got!"
        case .challengeCompleted:
            title = "Challenge Completed"
            message = "Congratulations! You completed \"\(challengeName)\"!"
        case .challengeWon:
            title = "Challenge Won! 🏆"
            message = "Amazing! You won \"\(challengeName)\"!"
        default:
            title = "Challenge Update"
            message = "Update for \"\(challengeName)\""
        }
        
        let notification = NotificationModel(
            type: type,
            title: title,
            message: message,
            senderID: senderID,
            relatedID: challengeID
        )
        
        await addNotification(notification)
        await scheduleLocalNotification(notification)
    }
    
    func createAchievementNotification(achievementTitle: String, description: String) async {
        let notification = NotificationModel(
            type: .achievementUnlocked,
            title: "Achievement Unlocked! 🏅",
            message: "You earned \"\(achievementTitle)\" - \(description)"
        )
        
        await addNotification(notification)
        await scheduleLocalNotification(notification)
    }
    
    func createHealthNotification(type: NotificationType, message: String) async {
        let title: String
        
        switch type {
        case .recoveryAlert:
            title = "Recovery Alert"
        case .heartRateAlert:
            title = "Heart Rate Alert"
        case .goalAchieved:
            title = "Goal Achieved! 🎯"
        case .weeklyReport:
            title = "Weekly Fitness Report"
        case .monthlyReport:
            title = "Monthly Fitness Report"
        default:
            title = "Health Update"
        }
        
        let notification = NotificationModel(
            type: type,
            title: title,
            message: message
        )
        
        await addNotification(notification)
        await scheduleLocalNotification(notification)
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: NotificationSettings) async {
        await MainActor.run {
            self.settings = newSettings
            saveSettings()
        }
        
        if !newSettings.isEnabled {
            center.removeAllPendingNotificationRequests()
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "notification_settings")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "notification_settings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.settings = settings
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveNotifications() {
        let recentNotifications = Array(notifications.prefix(500)) // Keep last 500
        if let data = try? JSONEncoder().encode(recentNotifications) {
            UserDefaults.standard.set(data, forKey: "cached_notifications")
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: "cached_notifications"),
           let notifications = try? JSONDecoder().decode([NotificationModel].self, from: data) {
            self.notifications = notifications
        }
    }
    
    // MARK: - CloudKit Sync
    
    private func syncNotificationToCloudKit(_ notification: NotificationModel) async {
        // Implementation would sync important notifications to CloudKit
        // for cross-device synchronization
    }
    
    // MARK: - Helper Methods
    
    private func setupNotificationCategories() {
        center.setNotificationCategories(notificationCategories)
    }
    
    private func getCategoryIdentifier(for type: NotificationType) -> String {
        switch type {
        case .newFollower, .followAccepted, .postLiked, .postCommented, .userMentioned:
            return "SOCIAL_CATEGORY"
        case .challengeInvite, .challengeStarted, .challengeCompleted, .challengeWon:
            return "CHALLENGE_CATEGORY"
        case .teamInvite, .teamJoined, .teamChallengeCreated, .teamMemberJoined:
            return "TEAM_CATEGORY"
        case .directMessage:
            return "MESSAGE_CATEGORY"
        default:
            return "DEFAULT_CATEGORY"
        }
    }
    
    func getGroupedNotifications() -> [NotificationGroup] {
        return notifications.grouped()
    }
    
    func getNotifications(for types: [NotificationType]) -> [NotificationModel] {
        return notifications.filtered(by: types)
    }
    
    func isInQuietHours() -> Bool {
        guard settings.quietHoursEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
        
        guard let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
              let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }
        
        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes <= endMinutes
        } else {
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task {
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
    
    private func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        // Handle action-specific responses
        switch actionIdentifier {
        case NotificationAction.like.rawValue:
            await handleLikeAction(userInfo)
        case NotificationAction.follow.rawValue:
            await handleFollowAction(userInfo)
        case NotificationAction.acceptChallenge.rawValue:
            await handleAcceptChallengeAction(userInfo)
        case NotificationAction.declineChallenge.rawValue:
            await handleDeclineChallengeAction(userInfo)
        case NotificationAction.markAsRead.rawValue:
            await handleMarkAsReadAction(userInfo)
        default:
            // Default action (tap notification)
            await handleDefaultAction(userInfo)
        }
    }
    
    private func handleLikeAction(_ userInfo: [AnyHashable: Any]) async {
        // Implementation would handle like action
        print("Handling like action from notification")
    }
    
    private func handleFollowAction(_ userInfo: [AnyHashable: Any]) async {
        // Implementation would handle follow action
        print("Handling follow action from notification")
    }
    
    private func handleAcceptChallengeAction(_ userInfo: [AnyHashable: Any]) async {
        // Implementation would handle accept challenge action
        print("Handling accept challenge action from notification")
    }
    
    private func handleDeclineChallengeAction(_ userInfo: [AnyHashable: Any]) async {
        // Implementation would handle decline challenge action
        print("Handling decline challenge action from notification")
    }
    
    private func handleMarkAsReadAction(_ userInfo: [AnyHashable: Any]) async {
        if let notificationIdString = userInfo["notificationId"] as? String,
           let notificationId = UUID(uuidString: notificationIdString) {
            await markAsRead(notificationId)
        }
    }
    
    private func handleDefaultAction(_ userInfo: [AnyHashable: Any]) async {
        // Implementation would navigate to appropriate screen
        print("Handling default notification action")
    }
}
