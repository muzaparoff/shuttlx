//
//  HapticFeedbackManager.swift
//  ShuttlX MVP
//
//  Simplified haptic feedback for run-walk intervals
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import UIKit

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        impactFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Interval Training Haptics
    
    func intervalStart() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    func intervalTransition() {
        impactFeedback.impactOccurred()
    }
    
    func workoutComplete() {
        notificationFeedback.notificationOccurred(.success)
        
        // Double vibration for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.notificationFeedback.notificationOccurred(.success)
        }
    }
    
    func countdownTick() {
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.impactOccurred()
    }
}