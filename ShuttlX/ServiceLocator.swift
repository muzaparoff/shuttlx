//
//  ServiceLocator.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/7/25.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
class ServiceLocator: ObservableObject {
    static let shared = ServiceLocator()
    
    // Core MVP Services that are included in project
    lazy var healthManager = HealthManager()
    lazy var watchManager = WatchConnectivityManager()
    lazy var settingsService = SettingsService()
    lazy var notificationService = NotificationService()
    
    // Temporary inline services until files are added to Xcode target
    lazy var intervalTimer = TemporaryIntervalTimer()
    lazy var hapticManager = TemporaryHapticManager()
    lazy var socialService = TemporarySocialService()
    
    private init() {}
}

// MARK: - Temporary Services (until files added to Xcode target)

// Temporary IntervalWorkout definition
struct IntervalWorkout: Identifiable {
    let id = UUID()
    let name: String
    let runDuration: TimeInterval
    let walkDuration: TimeInterval
    let totalIntervals: Int
    
    static let beginner = IntervalWorkout(name: "Beginner", runDuration: 60, walkDuration: 90, totalIntervals: 8)
    static let intermediate = IntervalWorkout(name: "Intermediate", runDuration: 90, walkDuration: 60, totalIntervals: 10)
    static let advanced = IntervalWorkout(name: "Advanced", runDuration: 120, walkDuration: 60, totalIntervals: 12)
}

class TemporaryIntervalTimer: ObservableObject {
    @Published var isActive = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentPhase: TemporaryPhase = .warmup
    @Published var remainingTime: TimeInterval = 0
    @Published var currentWorkout: IntervalWorkout?
    
    func startWorkout() {
        isActive = true
        currentPhase = .running
    }
    
    func startWorkout(_ workout: IntervalWorkout) {
        currentWorkout = workout
        startWorkout()
    }
    
    func pauseWorkout() {
        isActive = false
    }
    
    func stopWorkout() {
        isActive = false
        currentPhase = .warmup
        timeRemaining = 0
        remainingTime = 0
        currentWorkout = nil
    }
}

enum TemporaryPhase {
    case warmup, running, walking, cooldown, completed
}

class TemporaryHapticManager: ObservableObject {
    static let shared = TemporaryHapticManager()
    
    func play() {
        // Simple haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    func playSuccess() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    
    func playError() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}

class TemporarySocialService: ObservableObject {
    @Published var isConnected = false
    var currentUserProfile: TemporarySocialProfile? = TemporarySocialProfile.default
    
    func connect() async {
        isConnected = false
    }
    
    func disconnect() {
        isConnected = false
    }
}

struct TemporarySocialProfile {
    let displayName = "Runner"
    static let `default` = TemporarySocialProfile()
}