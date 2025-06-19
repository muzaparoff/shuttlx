//
//  IntervalTimerService.swift
//  ShuttlX
//
//  Created by ShuttlX MVP on 6/9/25.
//

import Foundation
import SwiftUI
import Combine

/// Core service for managing run-walk interval training
@MainActor
class IntervalTimerService: ObservableObject {
    @Published var currentWorkout: IntervalWorkout?
    @Published var currentPhase: IntervalPhase = .running
    @Published var remainingTime: TimeInterval = 0
    @Published var isActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var completedIntervals: Int = 0
    
    private var timer: Timer?
    private var workoutStartTime: Date?
    
    // MARK: - Workout Control
    
    func startWorkout(_ workout: IntervalWorkout) {
        currentWorkout = workout
        currentPhase = .running
        remainingTime = workout.runDuration // Start with first run interval
        completedIntervals = 0
        isActive = true
        isPaused = false
        workoutStartTime = Date()
        
        startTimer()
        
        // Haptic feedback for workout start
        HapticFeedbackManager.shared.playRunStartFeedback()
    }
    
    func pauseWorkout() {
        isPaused = true
        stopTimer()
        HapticFeedbackManager.shared.playWarningFeedback()
    }
    
    func resumeWorkout() {
        isPaused = false
        startTimer()
        HapticFeedbackManager.shared.playLightImpact()
    }
    
    func stopWorkout() {
        isActive = false
        isPaused = false
        stopTimer()
        
        // Save workout session if it was meaningful
        if let workout = currentWorkout, completedIntervals > 0 {
            saveWorkoutSession(workout)
        }
        
        currentWorkout = nil
        HapticFeedbackManager.shared.playWorkoutCompleteFeedback()
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        guard !isPaused else { return }
        
        remainingTime -= 1
        
        // Check if current phase is complete
        if remainingTime <= 0 {
            advanceToNextPhase()
        }
    }
    
    private func advanceToNextPhase() {
        guard let workout = currentWorkout else { return }
        
        switch currentPhase {
        case .running:
            // Switch to walking
            currentPhase = .walking
            remainingTime = workout.walkDuration
            completedIntervals += 1
            HapticFeedbackManager.shared.playWalkStartFeedback()
            
        case .walking:
            // Check if workout should continue
            let elapsedTime = Date().timeIntervalSince(workoutStartTime ?? Date())
            if elapsedTime >= workout.totalDuration {
                // Workout complete
                currentPhase = .completed
                stopWorkout()
            } else {
                // Start next running interval
                currentPhase = .running
                remainingTime = workout.runDuration
                HapticFeedbackManager.shared.playRunStartFeedback()
            }
            
        case .completed:
            stopWorkout()
        }
    }
    
    // MARK: - Workout Session Saving
    
    private func saveWorkoutSession(_ workout: IntervalWorkout) {
        let session = WorkoutSession(
            workout: workout,
            steps: 0, // Will be filled by HealthKit data
            distance: 0,
            calories: 0,
            avgHR: 0,
            maxHR: 0
        )
        
        // Save to UserDefaults for now (in real app, use Core Data)
        saveSessionToDefaults(session)
    }
    
    private func saveSessionToDefaults(_ session: WorkoutSession) {
        var sessions = getStoredSessions()
        sessions.append(session)
        
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "WorkoutSessions")
        }
    }
    
    func getStoredSessions() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: "WorkoutSessions"),
              let sessions = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    // MARK: - Helper Properties
    
    var isRunning: Bool {
        currentPhase == .running
    }
    
    var isWalking: Bool {
        currentPhase == .walking
    }
    
    var totalElapsedTime: TimeInterval {
        workoutStartTime?.timeIntervalSinceNow.magnitude ?? 0
    }
    
    var progressPercentage: Double {
        guard let workout = currentWorkout else { return 0 }
        return totalElapsedTime / workout.totalDuration
    }
}
