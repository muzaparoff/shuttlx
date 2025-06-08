#if canImport(UIKit)
import UIKit
#endif
import CoreHaptics

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private var hapticEngine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    // Impact feedback generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    // Notification feedback generator
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Selection feedback generator
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    private init() {
        setupHapticEngine()
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }
        
        supportsHaptics = true
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
            supportsHaptics = false
        }
        
        // Handle engine stop/reset
        hapticEngine?.stoppedHandler = { reason in
            print("Haptic engine stopped: \(reason)")
        }
        
        hapticEngine?.resetHandler = {
            print("Haptic engine reset")
            do {
                try self.hapticEngine?.start()
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for gamification events
        NotificationCenter.default.addObserver(
            forName: .xpAwarded,
            object: nil,
            queue: .main
        ) { notification in
            if let reward = notification.object as? Reward {
                self.playXPAwardedFeedback(reward)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .levelUp,
            object: nil,
            queue: .main
        ) { _ in
            self.playLevelUpFeedback()
        }
        
        NotificationCenter.default.addObserver(
            forName: .badgeEarned,
            object: nil,
            queue: .main
        ) { _ in
            self.playBadgeEarnedFeedback()
        }
        
        NotificationCenter.default.addObserver(
            forName: .achievementEarned,
            object: nil,
            queue: .main
        ) { _ in
            self.playAchievementEarnedFeedback()
        }
        
        NotificationCenter.default.addObserver(
            forName: .newMessageReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? Message {
                self.playMessageReceivedFeedback(message)
            }
        }
    }
    
    // MARK: - Basic Feedback Types
    
    func playLightImpact() {
        lightImpact.impactOccurred()
    }
    
    func playMediumImpact() {
        mediumImpact.impactOccurred()
    }
    
    func playHeavyImpact() {
        heavyImpact.impactOccurred()
    }
    
    func playSelection() {
        selectionFeedback.selectionChanged()
    }
    
    func playSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func playWarning() {
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func playError() {
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Workout Feedback
    
    func playWorkoutStartFeedback() {
        guard supportsHaptics else {
            playMediumImpact()
            return
        }
        
        let pattern = createWorkoutStartPattern()
        playCustomPattern(pattern)
    }
    
    func playWorkoutPauseFeedback() {
        playMediumImpact()
    }
    
    func playWorkoutResumeFeedback() {
        playLightImpact()
    }
    
    func playWorkoutCompleteFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createWorkoutCompletePattern()
        playCustomPattern(pattern)
    }
    
    func playIntervalTransitionFeedback() {
        playLightImpact()
    }
    
    func playRestPeriodFeedback() {
        guard supportsHaptics else {
            playMediumImpact()
            return
        }
        
        let pattern = createRestPeriodPattern()
        playCustomPattern(pattern)
    }
    
    func playPersonalRecordFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createPersonalRecordPattern()
        playCustomPattern(pattern)
    }
    
    // MARK: - Social Feedback
    
    func playMessageReceivedFeedback(_ message: Message) {
        // Different feedback based on message importance
        switch message.content {
        case .text:
            playLightImpact()
        case .workout:
            playMediumImpact()
        case .media:
            playMediumImpact()
        case .achievement:
            playSuccess()
        case .challenge:
            playMediumImpact()
        case .system:
            playSelection()
        }
    }
    
    func playMessageSentFeedback() {
        playSelection()
    }
    
    func playReactionFeedback() {
        playLightImpact()
    }
    
    func playInvitationReceivedFeedback() {
        guard supportsHaptics else {
            playWarning()
            return
        }
        
        let pattern = createInvitationPattern()
        playCustomPattern(pattern)
    }
    
    func playChallengeJoinedFeedback() {
        playMediumImpact()
    }
    
    func playTeamJoinedFeedback() {
        playSuccess()
    }
    
    // MARK: - Gamification Feedback
    
    func playXPAwardedFeedback(_ reward: Reward) {
        if reward.isMultiplier {
            // Special feedback for multiplied XP
            guard supportsHaptics else {
                playSuccess()
                return
            }
            
            let pattern = createMultiplierXPPattern()
            playCustomPattern(pattern)
        } else {
            playLightImpact()
        }
    }
    
    func playLevelUpFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createLevelUpPattern()
        playCustomPattern(pattern)
    }
    
    func playBadgeEarnedFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createBadgeEarnedPattern()
        playCustomPattern(pattern)
    }
    
    func playAchievementEarnedFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createAchievementPattern()
        playCustomPattern(pattern)
    }
    
    func playStreakMilestoneFeedback() {
        guard supportsHaptics else {
            playSuccess()
            return
        }
        
        let pattern = createStreakMilestonePattern()
        playCustomPattern(pattern)
    }
    
    // MARK: - Navigation Feedback
    
    func playTabSelectionFeedback() {
        playSelection()
    }
    
    func playButtonTapFeedback() {
        playLightImpact()
    }
    
    func playToggleFeedback() {
        playSelection()
    }
    
    func playSliderFeedback() {
        playSelection()
    }
    
    func playScrollFeedback() {
        // Very subtle feedback for continuous scrolling
        playSelection()
    }
    
    func playRefreshFeedback() {
        playMediumImpact()
    }
    
    // MARK: - Form Feedback
    
    func playFormValidationErrorFeedback() {
        playError()
    }
    
    func playFormSubmissionFeedback() {
        playSuccess()
    }
    
    func playFieldFocusFeedback() {
        playSelection()
    }
    
    // MARK: - Custom Haptic Patterns
    
    private func createWorkoutStartPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.2)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create workout start pattern: \(error)")
            return nil
        }
    }
    
    private func createWorkoutCompletePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ], relativeTime: 0, duration: 0.3),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.4),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0.5),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.6)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create workout complete pattern: \(error)")
            return nil
        }
    }
    
    private func createLevelUpPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.2),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0.3, duration: 0.5)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create level up pattern: \(error)")
            return nil
        }
    }
    
    private func createBadgeEarnedPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0.05),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.1)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create badge earned pattern: \(error)")
            return nil
        }
    }
    
    private func createAchievementPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0, duration: 0.2),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.25),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ], relativeTime: 0.3, duration: 0.7)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create achievement pattern: \(error)")
            return nil
        }
    }
    
    private func createPersonalRecordPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.2),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.4)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create personal record pattern: \(error)")
            return nil
        }
    }
    
    private func createRestPeriodPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ], relativeTime: 0, duration: 1.0)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create rest period pattern: \(error)")
            return nil
        }
    }
    
    private func createInvitationPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0.2)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create invitation pattern: \(error)")
            return nil
        }
    }
    
    private func createMultiplierXPPattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.05),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.1)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create multiplier XP pattern: \(error)")
            return nil
        }
    }
    
    private func createStreakMilestonePattern() -> CHHapticPattern? {
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.1),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ], relativeTime: 0.2),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ], relativeTime: 0.3),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ], relativeTime: 0.4)
        ]
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create streak milestone pattern: \(error)")
            return nil
        }
    }
    
    // MARK: - Pattern Playback
    
    private func playCustomPattern(_ pattern: CHHapticPattern?) {
        guard let pattern = pattern,
              let hapticEngine = hapticEngine else {
            return
        }
        
        do {
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hapticEngine?.stop()
    }
}
