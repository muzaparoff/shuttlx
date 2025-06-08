//
//  AccessibilityManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import UIKit
import SwiftUI
import Combine

// MARK: - Accessibility Configuration
// AccessibilitySettings struct definition is in Models/SettingsModels.swift
// AnnouncementFrequency enum definition is in Models/SettingsModels.swift

// MARK: - Accessibility Announcement Types
enum AccessibilityAnnouncement {
    case workoutStart(type: String)
    case workoutEnd(duration: String)
    case intervalChange(current: String, next: String?)
    case progress(completed: Int, total: Int, timeRemaining: String)
    case heartRate(current: Int, zone: String)
    case pace(current: String, target: String?)
    case distance(current: String, total: String)
    case navigation(instruction: String)
    case achievement(title: String)
    case warning(message: String)
    case error(message: String)
    
    var priority: AccessibilityAnnouncementPriority {
        switch self {
        case .workoutStart, .workoutEnd: return .high
        case .intervalChange: return .high
        case .warning, .error: return .high
        case .achievement: return .medium
        case .navigation: return .medium
        case .progress, .heartRate, .pace, .distance: return .low
        }
    }
}

// MARK: - Accessibility Manager
@MainActor
class AccessibilityManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var settings = AccessibilitySettings.default
    @Published var isVoiceOverActive: Bool = UIAccessibility.isVoiceOverRunning
    @Published var isReduceMotionActive: Bool = UIAccessibility.isReduceMotionEnabled
    @Published var contentSizeCategory: ContentSizeCategory = .large
    @Published var isHighContrastMode: Bool = false
    @Published var isSimplifiedInterface: Bool = false
    
    // MARK: - Private Properties
    private var announcementQueue: [AccessibilityAnnouncement] = []
    private var isProcessingAnnouncements = false
    private var lastAnnouncementTime: [String: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadSettings()
        setupAccessibilityObservers()
        updateSystemSettings()
    }
    
    // MARK: - Public Methods
    func updateSettings(_ newSettings: AccessibilitySettings) {
        settings = newSettings
        saveSettings()
        applyAccessibilityChanges()
    }
    
    func announce(_ announcement: AccessibilityAnnouncement, force: Bool = false) {
        guard settings.enableAudioDescriptions || force else { return }
        
        // Check if we should throttle this announcement type
        let announcementKey = String(describing: announcement)
        if !force && shouldThrottleAnnouncement(key: announcementKey) {
            return
        }
        
        // Add to queue based on priority
        switch announcement.priority {
        case .high:
            // Clear lower priority announcements and add immediately
            announcementQueue.removeAll { $0.priority == .low }
            announcementQueue.insert(announcement, at: 0)
        case .medium:
            // Insert before low priority announcements
            if let lastHighIndex = announcementQueue.lastIndex(where: { $0.priority == .high }) {
                announcementQueue.insert(announcement, at: lastHighIndex + 1)
            } else {
                announcementQueue.insert(announcement, at: 0)
            }
        case .low:
            // Add to end of queue
            announcementQueue.append(announcement)
        }
        
        processAnnouncementQueue()
    }
    
    func announceWorkoutStart(type: String) {
        announce(.workoutStart(type: type), force: true)
    }
    
    func announceWorkoutEnd(duration: String) {
        announce(.workoutEnd(duration: duration), force: true)
    }
    
    func announceIntervalChange(current: String, next: String?) {
        announce(.intervalChange(current: current, next: next))
    }
    
    func announceProgress(completed: Int, total: Int, timeRemaining: String) {
        announce(.progress(completed: completed, total: total, timeRemaining: timeRemaining))
    }
    
    func announceHeartRate(current: Int, zone: String) {
        announce(.heartRate(current: current, zone: zone))
    }
    
    func announcePace(current: String, target: String? = nil) {
        announce(.pace(current: current, target: target))
    }
    
    func announceDistance(current: String, total: String) {
        announce(.distance(current: current, total: total))
    }
    
    func announceNavigation(instruction: String) {
        announce(.navigation(instruction: instruction))
    }
    
    func announceAchievement(title: String) {
        announce(.achievement(title: title))
    }
    
    func announceWarning(message: String) {
        announce(.warning(message: message), force: true)
    }
    
    func announceError(message: String) {
        announce(.error(message: message), force: true)
    }
    
    func clearAnnouncements() {
        announcementQueue.removeAll()
        isProcessingAnnouncements = false
    }
    
    // MARK: - Haptic Feedback
    func provideHapticFeedback(for event: HapticEvent) {
        guard settings.enableHapticNavigation else { return }
        
        switch event {
        case .intervalStart:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .intervalEnd:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .workoutComplete:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .achievement:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .navigation:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    // MARK: - Interface Adaptations
    func getAdaptedFont(for textStyle: Font.TextStyle, size: CGFloat? = nil) -> Font {
        if settings.isIncreaseContrastEnabled || settings.enableLargeTextMode {
            let adjustedSize = (size ?? 17) * (settings.enableLargeTextMode ? 1.2 : 1.0)
            return .system(size: adjustedSize, weight: .medium, design: .default)
        }
        
        return .system(textStyle, design: .default)
    }
    
    func getAdaptedColor(primary: Color, secondary: Color) -> Color {
        if settings.isIncreaseContrastEnabled || settings.enableHighContrastMode {
            return primary
        }
        return secondary
    }
    
    func getAdaptedOpacity() -> Double {
        if settings.isReduceTransparencyEnabled {
            return 1.0
        }
        return 0.8
    }
    
    func shouldUseSimplifiedInterface() -> Bool {
        return settings.enableSimplifiedInterface || settings.isVoiceOverEnabled
    }
    
    func shouldReduceAnimations() -> Bool {
        return settings.isReduceMotionEnabled
    }
    
    // MARK: - VoiceOver Support
    func setAccessibilityLabel(_ label: String, for view: Any) {
        if let uiView = view as? UIView {
            uiView.accessibilityLabel = label
        }
    }
    
    func setAccessibilityHint(_ hint: String, for view: Any) {
        if let uiView = view as? UIView {
            uiView.accessibilityHint = hint
        }
    }
    
    func setAccessibilityTraits(_ traits: UIAccessibilityTraits, for view: Any) {
        if let uiView = view as? UIView {
            uiView.accessibilityTraits = traits
        }
    }
    
    func makeAccessibilityElement(label: String, hint: String? = nil, traits: UIAccessibilityTraits = .none) -> AccessibilityProperties {
        return AccessibilityProperties(
            label: label,
            hint: hint,
            traits: traits
        )
    }
    
    // MARK: - Private Methods
    private func setupAccessibilityObservers() {
        // Observe VoiceOver changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverActive = UIAccessibility.isVoiceOverRunning
            self?.settings.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
            self?.applyAccessibilityChanges()
        }
        
        // Observe reduce motion changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceMotionActive = UIAccessibility.isReduceMotionEnabled
            self?.settings.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
        
        // Observe content size changes
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateContentSizeCategory()
        }
        
        // Observe contrast changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.settings.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        }
    }
    
    private func updateSystemSettings() {
        settings.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        settings.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        settings.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        settings.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        settings.isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        settings.isAssistiveTouchEnabled = UIAccessibility.isAssistiveTouchRunning
        settings.isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
        updateContentSizeCategory()
    }
    
    private func updateContentSizeCategory() {
        let category = UIApplication.shared.preferredContentSizeCategory
        settings.preferredContentSizeCategory = category.rawValue
        
        // Map to SwiftUI content size category
        switch category {
        case .extraSmall: contentSizeCategory = .extraSmall
        case .small: contentSizeCategory = .small
        case .medium: contentSizeCategory = .medium
        case .large: contentSizeCategory = .large
        case .extraLarge: contentSizeCategory = .extraLarge
        case .extraExtraLarge: contentSizeCategory = .extraExtraLarge
        case .extraExtraExtraLarge: contentSizeCategory = .extraExtraExtraLarge
        case .accessibilityMedium: contentSizeCategory = .accessibilityMedium
        case .accessibilityLarge: contentSizeCategory = .accessibilityLarge
        case .accessibilityExtraLarge: contentSizeCategory = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: contentSizeCategory = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: contentSizeCategory = .accessibilityExtraExtraExtraLarge
        default: contentSizeCategory = .large
        }
    }
    
    private func applyAccessibilityChanges() {
        isSimplifiedInterface = shouldUseSimplifiedInterface()
        isHighContrastMode = settings.enableHighContrastMode || settings.isIncreaseContrastEnabled
        
        // Apply changes to the interface
        saveSettings()
    }
    
    private func processAnnouncementQueue() {
        guard !isProcessingAnnouncements && !announcementQueue.isEmpty else { return }
        
        isProcessingAnnouncements = true
        let announcement = announcementQueue.removeFirst()
        
        let message = generateAnnouncementMessage(for: announcement)
        
        // Update throttling
        let announcementKey = String(describing: announcement)
        lastAnnouncementTime[announcementKey] = Date()
        
        // Use VoiceOver if available, otherwise use speech synthesis
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: message)
        } else {
            // Fallback to speech synthesis (would integrate with AudioCoachingManager)
            print("🔊 Accessibility: \(message)")
        }
        
        // Process next announcement after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isProcessingAnnouncements = false
            self.processAnnouncementQueue()
        }
    }
    
    private func generateAnnouncementMessage(for announcement: AccessibilityAnnouncement) -> String {
        switch announcement {
        case .workoutStart(let type):
            return "Starting \(type) workout. Get ready!"
        case .workoutEnd(let duration):
            return "Workout completed in \(duration). Great job!"
        case .intervalChange(let current, let next):
            var message = "Now: \(current)"
            if let next = next {
                message += ". Next: \(next)"
            }
            return message
        case .progress(let completed, let total, let timeRemaining):
            return "Completed \(completed) of \(total) intervals. \(timeRemaining) remaining."
        case .heartRate(let current, let zone):
            return "Heart rate: \(current) beats per minute. \(zone) zone."
        case .pace(let current, let target):
            var message = "Current pace: \(current)"
            if let target = target {
                message += ". Target: \(target)"
            }
            return message
        case .distance(let current, let total):
            return "Distance: \(current) of \(total)"
        case .navigation(let instruction):
            return instruction
        case .achievement(let title):
            return "Achievement unlocked: \(title)"
        case .warning(let message):
            return "Warning: \(message)"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private func shouldThrottleAnnouncement(key: String) -> Bool {
        guard let lastTime = lastAnnouncementTime[key] else { return false }
        let timeSinceLastAnnouncement = Date().timeIntervalSince(lastTime)
        return timeSinceLastAnnouncement < settings.workoutAnnouncementFrequency.interval
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "AccessibilitySettings")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "AccessibilitySettings"),
           let savedSettings = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            settings = savedSettings
        }
        updateSystemSettings()
    }
}

// MARK: - Supporting Types
struct AccessibilityProperties {
    let label: String
    let hint: String?
    let traits: UIAccessibilityTraits
}

enum HapticEvent {
    case intervalStart
    case intervalEnd
    case workoutComplete
    case achievement
    case warning
    case error
    case navigation
    case selection
}

enum AccessibilityAnnouncementPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    
    static func < (lhs: AccessibilityAnnouncementPriority, rhs: AccessibilityAnnouncementPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SwiftUI Accessibility Modifiers
extension View {
    func accessibilityConfiguration(_ config: AccessibilityProperties) -> some View {
        self
            .accessibilityLabel(config.label)
            .accessibilityHint(config.hint ?? "")
            .accessibilityAddTraits(config.traits)
    }
    
    func adaptiveFont(_ manager: AccessibilityManager, style: Font.TextStyle = .body, size: CGFloat? = nil) -> some View {
        self.font(manager.getAdaptedFont(for: style, size: size))
    }
    
    func adaptiveColor(_ manager: AccessibilityManager, primary: Color, secondary: Color) -> some View {
        self.foregroundColor(manager.getAdaptedColor(primary: primary, secondary: secondary))
    }
    
    func adaptiveOpacity(_ manager: AccessibilityManager) -> some View {
        self.opacity(manager.getAdaptedOpacity())
    }
    
    func reducedMotion(_ manager: AccessibilityManager) -> some View {
        self.animation(manager.shouldReduceAnimations() ? .none : .default, value: UUID())
    }
}

// MARK: - Social Accessibility Announcements
enum SocialAccessibilityAnnouncement {
    case messageReceived(from: String, preview: String)
    case challengeInvitation(title: String, from: String)
    case teamInvitation(teamName: String, from: String)
    case achievementEarned(title: String)
    case badgeEarned(title: String)
    case levelUp(level: Int)
    case streakMilestone(days: Int)
    case leaderboardPosition(rank: Int, category: String)
    case challengeProgress(challenge: String, progress: Int, total: Int)
    case teamUpdate(action: String, teamName: String)
    case friendOnline(name: String)
    case workoutBuddyJoined(name: String)
    case socialInteraction(type: String, from: String)
    
    var priority: AccessibilityAnnouncementPriority {
        switch self {
        case .challengeInvitation, .teamInvitation: return .high
        case .messageReceived: return .medium
        case .achievementEarned, .badgeEarned, .levelUp: return .medium
        case .streakMilestone, .leaderboardPosition: return .low
        case .challengeProgress, .teamUpdate: return .low
        case .friendOnline, .workoutBuddyJoined: return .low
        case .socialInteraction: return .low
        }
    }
    
    var announcement: String {
        switch self {
        case .messageReceived(let from, let preview):
            return "New message from \(from): \(preview)"
        case .challengeInvitation(let title, let from):
            return "Challenge invitation: \(title) from \(from)"
        case .teamInvitation(let teamName, let from):
            return "Team invitation to join \(teamName) from \(from)"
        case .achievementEarned(let title):
            return "Achievement earned: \(title)"
        case .badgeEarned(let title):
            return "Badge earned: \(title)"
        case .levelUp(let level):
            return "Level up! You are now level \(level)"
        case .streakMilestone(let days):
            return "Streak milestone reached: \(days) days"
        case .leaderboardPosition(let rank, let category):
            return "Leaderboard position: Rank \(rank) in \(category)"
        case .challengeProgress(let challenge, let progress, let total):
            return "Challenge progress: \(challenge), \(progress) of \(total) completed"
        case .teamUpdate(let action, let teamName):
            return "Team update: \(action) in \(teamName)"
        case .friendOnline(let name):
            return "\(name) is now online"
        case .workoutBuddyJoined(let name):
            return "\(name) joined your workout"
        case .socialInteraction(let type, let from):
            return "\(type) from \(from)"
        }
    }
}

// MARK: - Enhanced Social Accessibility Methods
extension AccessibilityManager {
    
    func announceSocialUpdate(_ announcement: SocialAccessibilityAnnouncement, force: Bool = false) {
        guard settings.enableAudioDescriptions || force else { return }
        
        // Convert to main accessibility announcement
        let accessibilityAnnouncement: AccessibilityAnnouncement
        
        switch announcement {
        case .achievementEarned(let title):
            accessibilityAnnouncement = .achievement(title: title)
        case .messageReceived, .challengeInvitation, .teamInvitation:
            // Handle as navigation instruction for high priority
            accessibilityAnnouncement = .navigation(instruction: announcement.announcement)
        default:
            // Handle as general navigation instruction
            accessibilityAnnouncement = .navigation(instruction: announcement.announcement)
        }
        
        announce(accessibilityAnnouncement, force: force)
    }
    
    func configureViewForAccessibility(_ view: UIView, 
                                     label: String, 
                                     hint: String? = nil, 
                                     traits: UIAccessibilityTraits = []) {
        view.isAccessibilityElement = true
        view.accessibilityLabel = label
        view.accessibilityHint = hint
        view.accessibilityTraits = traits
        
        // Apply high contrast if enabled
        if settings.isHighContrastMode {
            applyHighContrastStyling(to: view)
        }
        
        // Apply large text scaling if needed
        if settings.enableLargeTextMode {
            applyLargeTextStyling(to: view)
        }
    }
    
    func createAccessibilityCustomAction(name: String, 
                                       target: Any, 
                                       selector: Selector) -> UIAccessibilityCustomAction {
        return UIAccessibilityCustomAction(name: name, target: target, selector: selector)
    }
    
    func announcePageChange(to pageName: String) {
        if isVoiceOverActive {
            UIAccessibility.post(notification: .screenChanged, argument: "Navigated to \(pageName)")
        }
    }
    
    func announceLayoutChange(description: String) {
        if isVoiceOverActive {
            UIAccessibility.post(notification: .layoutChanged, argument: description)
        }
    }
    
    func focusOnElement(_ element: Any) {
        if isVoiceOverActive {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    // MARK: - Social UI Accessibility Helpers
    
    func makeChallengeRowAccessible(_ view: UIView, challenge: Challenge, userProgress: Double) {
        let progressText = String(format: "%.0f%% complete", userProgress * 100)
        let label = "\(challenge.title), \(challenge.description), \(progressText)"
        let hint = "Double tap to view challenge details"
        
        configureViewForAccessibility(view, label: label, hint: hint, traits: .button)
    }
    
    func makeTeamMemberRowAccessible(_ view: UIView, member: User, role: String, isOnline: Bool) {
        let onlineStatus = isOnline ? "online" : "offline"
        let label = "\(member.displayName), \(role), \(onlineStatus)"
        let hint = "Double tap to view member profile"
        
        configureViewForAccessibility(view, label: label, hint: hint, traits: .button)
    }
    
    func makeLeaderboardRowAccessible(_ view: UIView, rank: Int, user: User, value: String, category: String) {
        let label = "Rank \(rank), \(user.displayName), \(value) \(category)"
        let hint = "Double tap to view user profile"
        
        configureViewForAccessibility(view, label: label, hint: hint, traits: .button)
    }
    
    func makeMessageRowAccessible(_ view: UIView, message: Message, sender: User, timestamp: Date) {
        let timeString = formatTimeForAccessibility(timestamp)
        let messagePreview = getMessagePreview(message)
        let label = "Message from \(sender.displayName), \(timeString), \(messagePreview)"
        let hint = "Double tap to view full message"
        
        configureViewForAccessibility(view, label: label, hint: hint, traits: .button)
    }
    
    func makeBadgeAccessible(_ view: UIView, badge: Badge) {
        let earnedDate = formatDateForAccessibility(badge.earnedAt)
        let label = "\(badge.title) badge, earned \(earnedDate), \(badge.description)"
        let hint = "Badge earned for achievement"
        
        configureViewForAccessibility(view, label: label, hint: hint, traits: .image)
    }
    
    func makeWorkoutStatsAccessible(_ view: UIView, stats: [String: Any]) {
        var statsText = "Workout statistics: "
        for (key, value) in stats {
            statsText += "\(key): \(value), "
        }
        statsText = String(statsText.dropLast(2)) // Remove last comma and space
        
        configureViewForAccessibility(view, label: statsText, hint: nil, traits: .staticText)
    }
    
    // MARK: - Accessibility Styling
    
    private func applyHighContrastStyling(to view: UIView) {
        // Apply high contrast colors and borders
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor.label.cgColor
        
        if let button = view as? UIButton {
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = .systemBackground
        }
    }
    
    private func applyLargeTextStyling(to view: UIView) {
        // Scale fonts for better readability
        if let label = view as? UILabel {
            let currentFont = label.font ?? UIFont.systemFont(ofSize: 17)
            label.font = currentFont.withSize(currentFont.pointSize * 1.3)
            label.adjustsFontForContentSizeCategory = true
        }
        
        if let button = view as? UIButton {
            if let currentFont = button.titleLabel?.font {
                button.titleLabel?.font = currentFont.withSize(currentFont.pointSize * 1.3)
            }
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private func formatTimeForAccessibility(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatDateForAccessibility(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getMessagePreview(_ message: Message) -> String {
        switch message.content {
        case .text(let text):
            return String(text.prefix(50)) + (text.count > 50 ? "..." : "")
        case .workout(let workout):
            return "Shared workout: \(workout.name)"
        case .media(let media):
            switch media.type {
            case .image: return "Shared an image"
            case .video: return "Shared a video"
            case .audio: return "Shared an audio message"
            case .file: return "Shared a file"
            }
        case .achievement(let achievement):
            return "Shared achievement: \(achievement.title)"
        case .challenge(let challenge):
            return "Shared challenge: \(challenge.title)"
        case .system(let systemMessage):
            return systemMessage.message
        }
    }
    
    // MARK: - VoiceOver Navigation Gestures
    
    func setupCustomVoiceOverGestures(for view: UIView) {
        // Set up custom gestures for enhanced navigation
        let swipeUpAction = UIAccessibilityCustomAction(
            name: "Show more options",
            target: self,
            selector: #selector(handleSwipeUpGesture)
        )
        
        let swipeDownAction = UIAccessibilityCustomAction(
            name: "Hide options",
            target: self,
            selector: #selector(handleSwipeDownGesture)
        )
        
        view.accessibilityCustomActions = [swipeUpAction, swipeDownAction]
    }
    
    @objc private func handleSwipeUpGesture() -> Bool {
        // Handle custom swipe up gesture
        announceLayoutChange(description: "More options available")
        return true
    }
    
    @objc private func handleSwipeDownGesture() -> Bool {
        // Handle custom swipe down gesture
        announceLayoutChange(description: "Options hidden")
        return true
    }
    
    // MARK: - Accessibility Testing Support
    
    func generateAccessibilityReport() -> [String: Any] {
        return [
            "voiceOverEnabled": isVoiceOverActive,
            "reduceMotionEnabled": isReduceMotionActive,
            "contentSizeCategory": contentSizeCategory.rawValue,
            "highContrastMode": isHighContrastMode,
            "simplifiedInterface": isSimplifiedInterface,
            "customSettings": [
                "hapticNavigation": settings.enableHapticNavigation,
                "audioDescriptions": settings.enableAudioDescriptions,
                "announcementFrequency": settings.workoutAnnouncementFrequency.rawValue
            ]
        ]
    }
}
