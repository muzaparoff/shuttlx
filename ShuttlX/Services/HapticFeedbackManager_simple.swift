//
//  HapticFeedbackManager.swift
//  ShuttlX
//
//  Created by ShuttlX MVP on 6/9/25.
//

import UIKit
import CoreHaptics

/// Simple haptic feedback manager for run-walk interval training
class HapticFeedbackManager: ObservableObject {
    static let shared = HapticFeedbackManager()
    
    private var hapticEngine: CHHapticEngine?
    
    private init() {
        setupHapticEngine()
    }
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }
    
    // MARK: - Interval Training Haptics
    
    /// Play feedback when switching from walk to run
    func playRunStartFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
    
    /// Play feedback when switching from run to walk
    func playWalkStartFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Play feedback for workout completion
    func playWorkoutCompleteFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Double tap for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact.impactOccurred()
        }
    }
    
    /// Play light feedback for general UI interactions
    func playLightImpact() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Play warning feedback for pause/stop
    func playWarningFeedback() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }
    
    /// Play success feedback
    func playSuccessFeedback() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
}
