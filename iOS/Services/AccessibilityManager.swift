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
struct AccessibilitySettings: Codable {
    var isVoiceOverEnabled: Bool = UIAccessibility.isVoiceOverRunning
    var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled
    var isReduceTransparencyEnabled: Bool = UIAccessibility.isReduceTransparencyEnabled
    var isIncreaseContrastEnabled: Bool = UIAccessibility.isDarkerSystemColorsEnabled
    var isDifferentiateWithoutColorEnabled: Bool = UIAccessibility.shouldDifferentiateWithoutColor
    var isAssistiveTouchEnabled: Bool = UIAccessibility.isAssistiveTouchRunning
    var isInvertColorsEnabled: Bool = UIAccessibility.isInvertColorsEnabled
    var preferredContentSizeCategory: String = UIApplication.shared.preferredContentSizeCategory.rawValue
    
    // Custom accessibility features
    var enableHapticNavigation: Bool = true
    var enableAudioDescriptions: Bool = true
    var enableSimplifiedInterface: Bool = false
    var enableLargeTextMode: Bool = false
    var enableHighContrastMode: Bool = false
    var workoutAnnouncementFrequency: AnnouncementFrequency = .normal
    
    enum AnnouncementFrequency: String, Codable, CaseIterable {
        case minimal, normal, frequent, verbose
        
        var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .normal: return "Normal"
            case .frequent: return "Frequent"
            case .verbose: return "Verbose"
            }
        }
        
        var interval: TimeInterval {
            switch self {
            case .minimal: return 60 // Every minute
            case .normal: return 30  // Every 30 seconds
            case .frequent: return 15 // Every 15 seconds
            case .verbose: return 5   // Every 5 seconds
            }
        }
    }
}

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
    @Published var settings = AccessibilitySettings()
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
            print("🔊 Accessibility: \\(message)")
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
            return "Starting \\(type) workout. Get ready!"
        case .workoutEnd(let duration):
            return "Workout completed in \\(duration). Great job!"
        case .intervalChange(let current, let next):
            var message = "Now: \\(current)"
            if let next = next {
                message += ". Next: \\(next)"
            }
            return message
        case .progress(let completed, let total, let timeRemaining):
            return "Completed \\(completed) of \\(total) intervals. \\(timeRemaining) remaining."
        case .heartRate(let current, let zone):
            return "Heart rate: \\(current) beats per minute. \\(zone) zone."
        case .pace(let current, let target):
            var message = "Current pace: \\(current)"
            if let target = target {
                message += ". Target: \\(target)"
            }
            return message
        case .distance(let current, let total):
            return "Distance: \\(current) of \\(total)"
        case .navigation(let instruction):
            return instruction
        case .achievement(let title):
            return "Achievement unlocked: \\(title)"
        case .warning(let message):
            return "Warning: \\(message)"
        case .error(let message):
            return "Error: \\(message)"
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
