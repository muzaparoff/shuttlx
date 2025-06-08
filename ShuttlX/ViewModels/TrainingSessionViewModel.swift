//
//  TrainingSessionViewModel.swift
//  ShuttlX
//
//  Comprehensive workout execution view model with real-time tracking
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI
import CoreLocation
import HealthKit
import Combine

@MainActor
class TrainingSessionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isWorkoutActive = false
    @Published var currentIntervalIndex = 0
    @Published var currentIntervalTime: TimeInterval = 0
    @Published var totalElapsedTime: TimeInterval = 0
    @Published var caloriesBurned = 0
    @Published var distanceCovered: Double?
    @Published var averagePace: Double?
    @Published var currentHeartRate = 0
    @Published var averageHeartRate = 0
    @Published var maxHeartRate = 0
    @Published var currentHeartRateZone: HeartRateZone?
    @Published var heartRateData: [HeartRateDataPoint] = []
    @Published var currentCoachingTip: CoachingTip?
    @Published var heartRateAlert: HeartRateAlert?
    
    // MARK: - Properties
    let workout: WorkoutConfiguration
    private var workoutTimer: Timer?
    private var startTime: Date?
    private var pauseTime: Date?
    private var totalPausedTime: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let healthManager = HealthManager.shared
    private let audioCoachingManager = AudioCoachingManager.shared
    private let settingsService = SettingsService.shared
    private let aiFormAnalysisService = AIFormAnalysisService.shared
    
    // MARK: - Computed Properties
    var currentInterval: WorkoutInterval? {
        guard currentIntervalIndex < workout.intervals.count else { return nil }
        return workout.intervals[currentIntervalIndex]
    }
    
    var nextInterval: WorkoutInterval? {
        let nextIndex = currentIntervalIndex + 1
        guard nextIndex < workout.intervals.count else { return nil }
        return workout.intervals[nextIndex]
    }
    
    var currentPhase: String {
        guard let interval = currentInterval else { return "Completed" }
        return "\(interval.type.displayName) Phase"
    }
    
    var overallProgress: Double {
        guard !workout.intervals.isEmpty else { return 0 }
        
        let completedTime = workout.intervals.prefix(currentIntervalIndex).reduce(0) { $0 + $1.duration }
        let currentIntervalProgress = currentInterval?.duration ?? 0 > 0 ? 
            currentIntervalTime / (currentInterval?.duration ?? 1) : 0
        let currentIntervalTime = (currentInterval?.duration ?? 0) * currentIntervalProgress
        
        return (completedTime + currentIntervalTime) / workout.duration
    }
    
    var currentIntervalProgress: Double {
        guard let interval = currentInterval, interval.duration > 0 else { return 0 }
        return min(currentIntervalTime / interval.duration, 1.0)
    }
    
    var currentIntensityColor: Color {
        currentInterval?.intensity.color ?? .blue
    }
    
    var formattedCurrentIntervalTime: String {
        guard let interval = currentInterval else { return "00:00" }
        let remainingTime = max(0, interval.duration - currentIntervalTime)
        return formatDuration(remainingTime)
    }
    
    var formattedTotalTime: String {
        formatDuration(totalElapsedTime)
    }
    
    var canGoToPreviousInterval: Bool {
        currentIntervalIndex > 0
    }
    
    var canGoToNextInterval: Bool {
        currentIntervalIndex < workout.intervals.count - 1
    }
    
    var heartRateAlertMessage: String {
        heartRateAlert?.message ?? ""
    }
    
    // MARK: - Initialization
    init(workout: WorkoutConfiguration) {
        self.workout = workout
        setupSubscriptions()
    }
    
    // MARK: - Workout Control
    func startWorkout() {
        guard !isWorkoutActive else { return }
        
        isWorkoutActive = true
        startTime = Date()
        currentIntervalIndex = 0
        currentIntervalTime = 0
        totalElapsedTime = 0
        
        startWorkoutTimer()
        startHealthTracking()
        startAudioCoaching()
        
        // Reset metrics
        caloriesBurned = 0
        distanceCovered = 0
        averagePace = nil
        currentHeartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        heartRateData.removeAll()
        
        logWorkoutEvent("Workout started: \(workout.name)")
    }
    
    func pauseWorkout() {
        guard isWorkoutActive else { return }
        
        isWorkoutActive = false
        pauseTime = Date()
        
        stopWorkoutTimer()
        pauseHealthTracking()
        pauseAudioCoaching()
        
        logWorkoutEvent("Workout paused")
    }
    
    func resumeWorkout() {
        guard !isWorkoutActive else { return }
        
        isWorkoutActive = true
        
        // Calculate paused duration
        if let pauseTime = pauseTime {
            totalPausedTime += Date().timeIntervalSince(pauseTime)
            self.pauseTime = nil
        }
        
        startWorkoutTimer()
        resumeHealthTracking()
        resumeAudioCoaching()
        
        logWorkoutEvent("Workout resumed")
    }
    
    func endWorkout() {
        isWorkoutActive = false
        
        stopWorkoutTimer()
        stopHealthTracking()
        stopAudioCoaching()
        
        saveWorkoutSession()
        logWorkoutEvent("Workout completed")
    }
    
    func goToNextInterval() {
        guard canGoToNextInterval else { return }
        
        currentIntervalIndex += 1
        currentIntervalTime = 0
        
        announceIntervalTransition()
        updateCoachingTip()
        
        logWorkoutEvent("Advanced to interval \(currentIntervalIndex + 1)")
    }
    
    func goToPreviousInterval() {
        guard canGoToPreviousInterval else { return }
        
        currentIntervalIndex -= 1
        currentIntervalTime = 0
        
        announceIntervalTransition()
        updateCoachingTip()
        
        logWorkoutEvent("Returned to interval \(currentIntervalIndex + 1)")
    }
    
    // MARK: - Timer Management
    private func startWorkoutTimer() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWorkoutTimer()
            }
        }
    }
    
    private func stopWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }
    
    private func updateWorkoutTimer() {
        guard isWorkoutActive, let interval = currentInterval else { return }
        
        currentIntervalTime += 0.1
        
        if let startTime = startTime {
            totalElapsedTime = Date().timeIntervalSince(startTime) - totalPausedTime
        }
        
        // Check if current interval is complete
        if currentIntervalTime >= interval.duration {
            if canGoToNextInterval {
                goToNextInterval()
            } else {
                // Workout complete
                endWorkout()
            }
        }
        
        // Update metrics periodically
        if Int(currentIntervalTime * 10) % 10 == 0 { // Every second
            updateMetrics()
        }
    }
    
    // MARK: - Health Tracking
    private func startHealthTracking() {
        healthManager.startWorkoutSession(for: workout.type)
    }
    
    private func pauseHealthTracking() {
        healthManager.pauseWorkoutSession()
    }
    
    private func resumeHealthTracking() {
        healthManager.resumeWorkoutSession()
    }
    
    private func stopHealthTracking() {
        healthManager.endWorkoutSession()
    }
    
    // MARK: - Audio Coaching
    private func startAudioCoaching() {
        guard workout.audioCoaching.enabled else { return }
        audioCoachingManager.startWorkoutCoaching(for: workout)
    }
    
    private func pauseAudioCoaching() {
        audioCoachingManager.pauseCoaching()
    }
    
    private func resumeAudioCoaching() {
        audioCoachingManager.resumeCoaching()
    }
    
    private func stopAudioCoaching() {
        audioCoachingManager.stopCoaching()
    }
    
    private func announceIntervalTransition() {
        guard workout.audioCoaching.enabled && workout.audioCoaching.intervalAnnouncements else { return }
        
        if let interval = currentInterval {
            let announcement = "Starting \(interval.type.displayName.lowercased()) phase"
            audioCoachingManager.announceMessage(announcement)
        }
    }
    
    // MARK: - Metrics Updates
    private func updateMetrics() {
        updateCalories()
        updateDistance()
        updatePace()
        updateHeartRateData()
        checkHeartRateAlerts()
    }
    
    private func updateCalories() {
        // Calculate calories based on intensity and duration
        let baseCaloriesPerMinute = 10.0
        let minutes = totalElapsedTime / 60.0
        
        let intensityMultiplier: Double
        if let intensity = currentInterval?.intensity {
            switch intensity {
            case .veryLight: intensityMultiplier = 0.8
            case .light: intensityMultiplier = 1.0
            case .moderate: intensityMultiplier = 1.3
            case .vigorous: intensityMultiplier = 1.6
            case .maximal: intensityMultiplier = 2.0
            }
        } else {
            intensityMultiplier = 1.0
        }
        
        caloriesBurned = Int(minutes * baseCaloriesPerMinute * intensityMultiplier)
    }
    
    private func updateDistance() {
        // For GPS-based workouts, get actual distance from location manager
        if workout.type.usesGPS {
            // This would integrate with actual GPS tracking
            distanceCovered = totalElapsedTime * 0.002 // Mock calculation
        }
    }
    
    private func updatePace() {
        if let distance = distanceCovered, distance > 0 {
            averagePace = totalElapsedTime / distance // seconds per meter
        }
    }
    
    private func updateHeartRateData() {
        // Get current heart rate from HealthKit
        if let currentHR = healthManager.currentHeartRate {
            currentHeartRate = Int(currentHR)
            
            // Update average and max
            if heartRateData.isEmpty {
                averageHeartRate = currentHeartRate
                maxHeartRate = currentHeartRate
            } else {
                let totalHR = heartRateData.reduce(0) { $0 + $1.value }
                averageHeartRate = Int((totalHR + currentHeartRate) / (heartRateData.count + 1))
                maxHeartRate = max(maxHeartRate, currentHeartRate)
            }
            
            // Add to data points
            let dataPoint = HeartRateDataPoint(
                timestamp: Date(),
                value: currentHeartRate
            )
            heartRateData.append(dataPoint)
            
            // Keep only last 50 data points for graph
            if heartRateData.count > 50 {
                heartRateData.removeFirst()
            }
            
            // Update heart rate zone
            updateHeartRateZone()
        }
    }
    
    private func updateHeartRateZone() {
        let zones = healthManager.heartRateZones
        currentHeartRateZone = zones.first { zone in
            currentHeartRate >= zone.minHeartRate && currentHeartRate <= zone.maxHeartRate
        }
    }
    
    private func checkHeartRateAlerts() {
        let thresholds = settingsService.settings.health.alertThresholds
        
        if currentHeartRate > thresholds.maxHeartRate {
            heartRateAlert = HeartRateAlert(
                type: .tooHigh,
                message: "Heart rate is above your maximum threshold (\(thresholds.maxHeartRate) BPM). Consider slowing down."
            )
        } else if currentHeartRate < thresholds.minHeartRate && totalElapsedTime > 300 { // After 5 minutes
            heartRateAlert = HeartRateAlert(
                type: .tooLow,
                message: "Heart rate is below your minimum threshold (\(thresholds.minHeartRate) BPM). Consider increasing intensity."
            )
        } else {
            heartRateAlert = nil
        }
    }
    
    // MARK: - Coaching Tips
    private func updateCoachingTip() {
        guard settingsService.settings.ai.realTimeCoaching else { return }
        
        Task {
            do {
                let tip = try await generateContextualCoachingTip()
                currentCoachingTip = tip
            } catch {
                print("Failed to generate coaching tip: \(error)")
            }
        }
    }
    
    private func generateContextualCoachingTip() async throws -> CoachingTip? {
        let context = WorkoutContext(
            currentInterval: currentInterval,
            intervalProgress: currentIntervalProgress,
            overallProgress: overallProgress,
            heartRate: currentHeartRate,
            heartRateZone: currentHeartRateZone,
            pace: averagePace,
            fatigue: calculateFatigueLevel()
        )
        
        return try await aiFormAnalysisService.generateCoachingTip(for: context)
    }
    
    private func calculateFatigueLevel() -> Double {
        // Simple fatigue calculation based on heart rate and duration
        let hrFatigue = Double(currentHeartRate) / 200.0 // Normalize to 0-1
        let durationFatigue = totalElapsedTime / workout.duration
        return (hrFatigue + durationFatigue) / 2.0
    }
    
    // MARK: - Workout Session Saving
    private func saveWorkoutSession() {
        let session = TrainingSession(
            id: UUID(),
            workoutType: SimpleWorkoutType.shuttleRun, // Convert from WorkoutConfiguration
            startTime: startTime ?? Date(),
            endTime: Date(),
            duration: totalElapsedTime,
            intervals: workout.intervals.count,
            completedIntervals: currentIntervalIndex,
            averageHeartRate: Double(averageHeartRate),
            maxHeartRate: Double(maxHeartRate),
            caloriesBurned: Double(caloriesBurned),
            totalDistance: distanceCovered,
            averagePace: averagePace,
            achievements: [], // Calculate achievements
            notes: "",
            weather: nil,
            location: nil
        )
        
        // Save to local storage and sync to cloud
        Task {
            do {
                try await saveTrainingSession(session)
                
                // Post notification for other services
                NotificationCenter.default.post(
                    name: .workoutCompleted,
                    object: session
                )
            } catch {
                print("Failed to save training session: \(error)")
            }
        }
    }
    
    // MARK: - Subscriptions
    private func setupSubscriptions() {
        // Listen for heart rate updates
        healthManager.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                if let hr = heartRate {
                    self?.currentHeartRate = Int(hr)
                }
            }
            .store(in: &cancellables)
        
        // Listen for coaching messages
        audioCoachingManager.$currentMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if let message = message {
                    self?.currentCoachingTip = CoachingTip(
                        title: "Audio Coach",
                        message: message,
                        type: .motivation
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Utility Methods
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
    
    private func logWorkoutEvent(_ message: String) {
        print("[TrainingSession] \(message)")
    }
    
    private func saveTrainingSession(_ session: TrainingSession) async throws {
        // Implementation would save to Core Data or CloudKit
        print("Saving training session: \(session.id)")
    }
}

// MARK: - Supporting Models

struct HeartRateDataPoint {
    let timestamp: Date
    let value: Int
}

struct CoachingTip {
    let title: String
    let message: String
    let type: CoachingTipType
    
    enum CoachingTipType {
        case technique, motivation, pacing, recovery
    }
}

struct HeartRateAlert {
    let type: AlertType
    let message: String
    
    enum AlertType {
        case tooHigh, tooLow, irregularRhythm
    }
}

struct WorkoutContext {
    let currentInterval: WorkoutInterval?
    let intervalProgress: Double
    let overallProgress: Double
    let heartRate: Int
    let heartRateZone: HeartRateZone?
    let pace: Double?
    let fatigue: Double
}

// MARK: - Notification Names

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
    static let workoutPaused = Notification.Name("workoutPaused")
    static let workoutResumed = Notification.Name("workoutResumed")
}
