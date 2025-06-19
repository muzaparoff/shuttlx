//
//  WatchWorkoutManager_Clean.swift
//  ShuttlXWatch Watch App
//
//  Complete clean implementation - Timer Fix and Sync System
//  Created on June 15, 2025
//

import Foundation
import HealthKit
import WatchKit
import Combine
import SwiftUI
import WatchConnectivity

// MARK: - Supporting Types
enum WorkoutPhase: String, CaseIterable {
    case ready = "ready"
    case work = "work"
    case rest = "rest"
    case completed = "completed"
}

struct WorkoutInterval: Identifiable, Codable {
    var id = UUID()
    let name: String
    let duration: TimeInterval // in seconds
    let type: IntervalType
    let description: String
    
    enum IntervalType: String, Codable, CaseIterable {
        case run = "run"
        case walk = "walk"
        
        var displayName: String {
            switch self {
            case .run: return "Run"
            case .walk: return "Walk"
            }
        }
        
        var color: Color {
            switch self {
            case .run: return .red
            case .walk: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .run: return "figure.run"
            case .walk: return "figure.walk"
            }
        }
    }
}

// MARK: - Workout Results for Data Sync
struct WorkoutResults: Codable {
    let workoutId: UUID
    let startDate: Date
    let endDate: Date
    let totalDuration: TimeInterval
    let activeCalories: Double
    let heartRate: Double
    let distance: Double
    let completedIntervals: Int
    let averageHeartRate: Double
    let maxHeartRate: Double
}

// CRITICAL FIX: Simple, reliable timer system for watchOS
class WatchWorkoutManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isWorkoutActive = false
    @Published var currentWorkout: HKWorkoutSession?
    @Published var currentBuilder: HKLiveWorkoutBuilder?
    
    // TIMER PROPERTIES (SIMPLIFIED)
    @Published var remainingIntervalTime: TimeInterval = 0
    @Published var currentInterval: WorkoutInterval?
    @Published var currentIntervalIndex = 0
    @Published var isWorkoutPaused = false
    
    // WORKOUT METRICS
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var totalDistance: Double = 0 // in meters
    @Published var elapsedTime: TimeInterval = 0
    
    // TRAINING PROGRAM DATA
    @Published var intervals: [WorkoutInterval] = []
    @Published var currentProgram: TrainingProgram?
    @Published var targetDistance: Double = 0 // in kilometers
    @Published var workoutPhase: WorkoutPhase = .ready
    
    // COMPUTED PROPERTIES
    var formattedRemainingTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDistance: String {
        let distanceKm = totalDistance / 1000.0
        return String(format: "%.2f km", distanceKm)
    }
    
    var formattedDistanceProgress: String {
        let current = totalDistance / 1000.0
        return String(format: "%.2f / %.1f km", current, targetDistance)
    }
    
    var formattedPace: String {
        guard totalDistance > 0 && elapsedTime > 0 else { return "--:--" }
        let distanceKm = totalDistance / 1000.0
        let paceSecondsPerKm = elapsedTime / distanceKm
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    var formattedSpeed: String {
        guard totalDistance > 0 && elapsedTime > 0 else { return "0.0 km/h" }
        let distanceKm = totalDistance / 1000.0
        let speedKmh = distanceKm / (elapsedTime / 3600.0)
        return String(format: "%.1f km/h", speedKmh)
    }
    
    var formattedIntervalTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var averageHeartRate: Double {
        return 120.0 // Placeholder for now - should be calculated from HealthKit data
    }
    
    var maxHeartRate: Double {
        return 150.0 // Placeholder for now - should be calculated from HealthKit data
    }
    
    var intervalProgress: Double {
        guard let current = currentInterval else { return 0.0 }
        let elapsed = current.duration - remainingIntervalTime
        return elapsed / current.duration
    }
    
    var distanceProgress: Double {
        guard targetDistance > 0 else { return 0.0 }
        let currentKm = totalDistance / 1000.0
        return min(currentKm / targetDistance, 1.0)
    }
    
    var distance: Double {
        return totalDistance / 1000.0 // Return distance in kilometers
    }
    
    var overallProgress: Double {
        guard !intervals.isEmpty else { return 0.0 }
        
        let completedIntervals = Double(currentIntervalIndex)
        let totalIntervals = Double(intervals.count)
        
        // Add current interval progress
        if let current = currentInterval {
            let currentProgress = (current.duration - remainingIntervalTime) / current.duration
            return (completedIntervals + currentProgress) / totalIntervals
        }
        
        return completedIntervals / totalIntervals
    }
    
    var currentActivityName: String {
        guard let interval = currentInterval else { return "READY" }
        switch interval.type {
        case .walk: return "WALK"
        case .run: return "RUN"
        }
    }
    
    var nextInterval: WorkoutInterval? {
        let nextIndex = currentIntervalIndex + 1
        guard nextIndex < intervals.count else { return nil }
        return intervals[nextIndex]
    }
    
    var totalIntervals: Int {
        return intervals.count
    }
    
    var isDistanceGoalReached: Bool {
        let currentKm = totalDistance / 1000.0
        return currentKm >= targetDistance
    }
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var intervalTimer: DispatchSourceTimer?
    private var startDate: Date?
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("⌚ [INIT] WatchWorkoutManager initialized")
        checkAuthorizationStatus()
    }
    
    // MARK: - CRITICAL FIX: SIMPLE TIMER SYSTEM
    func startWorkout(from program: TrainingProgram) {
        print("🚀 [TIMER-FIX] Starting workout: \(program.name)")
        
        // Stop any existing workout FIRST
        if isWorkoutActive {
            endWorkout()
        }
        
        // Set distance goal
        self.targetDistance = program.distance
        
        // Generate intervals (distance-based)
        let generatedIntervals = generateDistanceBasedIntervals(from: program)
        print("🚀 [TIMER-FIX] Generated \(generatedIntervals.count) intervals for \(program.distance)km goal")
        
        // CRITICAL: Set up workout state SYNCHRONOUSLY on main thread - no async!
        guard Thread.isMainThread else {
            DispatchQueue.main.sync {
                self.startWorkout(from: program)
            }
            return
        }
        
        // Set up workout state immediately
        self.intervals = generatedIntervals
        self.currentIntervalIndex = 0
        self.isWorkoutActive = true
        self.isWorkoutPaused = false
        self.startDate = Date()
        self.elapsedTime = 0
        self.totalDistance = 0
        
        // Set up first interval IMMEDIATELY
        if let firstInterval = generatedIntervals.first {
            self.currentInterval = firstInterval
            self.remainingIntervalTime = firstInterval.duration
            self.workoutPhase = getPhaseForIntervalType(firstInterval.type)
            
            print("✅ [TIMER-FIX] First interval initialized:")
            print("   - Name: \(firstInterval.name)")
            print("   - Type: \(firstInterval.type)")
            print("   - Duration: \(firstInterval.duration)s")
            print("   - remainingIntervalTime: \(self.remainingIntervalTime)")
            print("   - Target distance: \(self.targetDistance)km")
            
            // Start timer immediately
            startTimer()
            
            // CRITICAL: Force immediate UI update
            self.objectWillChange.send()
        }
        
        print("🏁 [TIMER-FIX] Workout started successfully")
    }
    
    // ENHANCED TIMER SYSTEM WITH RELIABILITY IMPROVEMENTS
    private func startTimer() {
        print("⏱️ [TIMER-ENHANCED] Starting enhanced timer system...")
        
        // Cancel any existing timer completely
        stopTimer()
        
        // Ensure we're on main thread for timer creation
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startTimer()
            }
            return
        }
        
        // Create new timer with enhanced reliability
        intervalTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        intervalTimer?.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(50))
        
        intervalTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.timerTick()
        }
        
        intervalTimer?.resume()
        
        // Immediate first update to show timer is working
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
        
        print("✅ [TIMER-ENHANCED] Enhanced timer started successfully")
        print("✅ [TIMER-ENHANCED] Initial remaining time: \(Int(remainingIntervalTime))s")
    }
    
    private func timerTick() {
        // Update elapsed time
        if let startDate = startDate {
            elapsedTime = Date().timeIntervalSince(startDate)
        }
        
        // Only countdown if workout is active and not paused
        guard isWorkoutActive && !isWorkoutPaused else { return }
        
        // Check distance goal first
        if isDistanceGoalReached {
            print("🎯 [TIMER] Distance goal reached!")
            endWorkout()
            return
        }
        
        // Countdown interval timer
        if remainingIntervalTime > 0 {
            remainingIntervalTime -= 1.0
            
            let remaining = Int(remainingIntervalTime)
            print("⏱️ [TIMER] \(currentActivityName): \(remaining)s remaining")
            
            // Force UI update
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        } else {
            // Move to next interval
            moveToNextInterval()
        }
    }
    
    private func moveToNextInterval() {
        print("🔄 [TIMER] Moving to next interval...")
        
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= intervals.count {
            print("🏁 [TIMER] All intervals completed!")
            endWorkout()
            return
        }
        
        // Set up next interval
        if currentIntervalIndex < intervals.count {
            let nextInterval = intervals[currentIntervalIndex]
            currentInterval = nextInterval
            remainingIntervalTime = nextInterval.duration
            
            print("📋 [TIMER] Next interval: \(nextInterval.name) (\(Int(nextInterval.duration))s)")
            
            // Play haptic feedback
            WKInterfaceDevice.current().play(.notification)
        }
    }
    
    private func stopTimer() {
        intervalTimer?.cancel()
        intervalTimer = nil
        print("⏹ [TIMER] Timer stopped")
    }
    
    func pauseWorkout() {
        guard isWorkoutActive else { return }
        
        isWorkoutPaused = true
        currentWorkout?.pause()
        print("⏸ [TIMER] Workout paused")
    }
    
    func resumeWorkout() {
        guard isWorkoutActive && isWorkoutPaused else { return }
        
        isWorkoutPaused = false
        currentWorkout?.resume()
        print("▶️ [TIMER] Workout resumed")
    }
    
    func skipToNextInterval() {
        guard isWorkoutActive else { return }
        
        print("⏭️ [TIMER] Manually skipping to next interval")
        moveToNextInterval()
    }
    
    func debugTimerState() {
        print("🐛 [DEBUG] Timer State:")
        print("  - isWorkoutActive: \(isWorkoutActive)")
        print("  - isWorkoutPaused: \(isWorkoutPaused)")
        print("  - remainingIntervalTime: \(remainingIntervalTime)")
        print("  - currentIntervalIndex: \(currentIntervalIndex)")
        print("  - intervals.count: \(intervals.count)")
        print("  - currentInterval: \(currentInterval?.name ?? "nil")")
        print("  - targetDistance: \(targetDistance)km")
        print("  - totalDistance: \(totalDistance)m")
        print("  - elapsedTime: \(elapsedTime)s")
    }
    
    func endWorkout() {
        print("🛑 [TIMER] Ending workout...")
        
        stopTimer()
        currentWorkout?.end()
        
        // Save workout data
        currentBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [TIMER] Workout saved successfully")
                } else {
                    print("❌ [TIMER] Error saving workout: \(error?.localizedDescription ?? "Unknown")")
                }
                self?.resetWorkoutState()
            }
        }
    }
    
    private func resetWorkoutState() {
        isWorkoutActive = false
        isWorkoutPaused = false
        currentWorkout = nil
        currentBuilder = nil
        currentInterval = nil
        remainingIntervalTime = 0
        currentIntervalIndex = 0
        elapsedTime = 0
        totalDistance = 0
        heartRate = 0
        activeCalories = 0
        workoutPhase = .ready
        print("🔄 [TIMER] Workout state reset")
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("❌ HealthKit not available")
            return 
        }
        
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount)
        ]
        
        let typesToRead: Set = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount),
            HKQuantityType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus()
                if success {
                    print("✅ HealthKit authorization granted")
                } else {
                    print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = healthStore.authorizationStatus(for: HKQuantityType.workoutType())
    }
    
    // MARK: - Interval Generation
    private func generateDistanceBasedIntervals(from program: TrainingProgram) -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Calculate intervals based on distance
        let walkDuration = TimeInterval(program.walkInterval * 60) // Convert minutes to seconds
        let runDuration = TimeInterval(program.runInterval * 60) // Convert minutes to seconds
        
        // Estimate how many intervals needed based on distance
        // Rough calculation: assume average speed of 6 km/h walking, 10 km/h running
        let totalTargetTime = program.distance * 60 * 60 / 8.0 // hours to seconds, average 8 km/h
        let cycleTime = walkDuration + runDuration
        let numberOfCycles = max(1, Int(totalTargetTime / cycleTime))
        
        print("🔢 [INTERVAL-GEN] Target distance: \(program.distance)km")
        print("🔢 [INTERVAL-GEN] Walk: \(walkDuration)s, Run: \(runDuration)s")
        print("🔢 [INTERVAL-GEN] Estimated cycles needed: \(numberOfCycles)")
        
        // Generate walk/run cycles
        for i in 1...numberOfCycles {
            // Walking interval
            intervals.append(WorkoutInterval(
                name: "Walk \(i)",
                duration: walkDuration,
                type: .walk,
                description: "Walking phase \(i)"
            ))
            
            // Running interval
            intervals.append(WorkoutInterval(
                name: "Run \(i)",
                duration: runDuration,
                type: .run,
                description: "Running phase \(i)"
            ))
        }
        
        print("✅ [INTERVAL-GEN] Generated \(intervals.count) intervals")
        return intervals
    }
    
    private func getPhaseForIntervalType(_ type: WorkoutInterval.IntervalType) -> WorkoutPhase {
        switch type {
        case .run: return .work
        case .walk: return .rest
        }
    }
    
    // MARK: - HealthKit Integration
    private func setupWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            session.delegate = self
            builder.delegate = self
            
            currentWorkout = session
            currentBuilder = builder
            
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Workout session started")
                    } else {
                        print("❌ Failed to start workout session: \(error?.localizedDescription ?? "Unknown")")
                    }
                }
            }
        } catch {
            print("❌ Failed to create workout session: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            print("⌚ Workout session state: \(toState.rawValue)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("❌ Workout session error: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMetrics(for: quantityType, statistics: statistics)
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    private func updateMetrics(for quantityType: HKQuantityType, statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        switch quantityType {
        case HKQuantityType(.heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            if let heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                self.heartRate = heartRate
            }
            
        case HKQuantityType(.activeEnergyBurned):
            let energyUnit = HKUnit.kilocalorie()
            if let calories = statistics.sumQuantity()?.doubleValue(for: energyUnit) {
                self.activeCalories = calories
            }
            
        case HKQuantityType(.distanceWalkingRunning):
            let distanceUnit = HKUnit.meter()
            if let distance = statistics.sumQuantity()?.doubleValue(for: distanceUnit) {
                self.totalDistance = distance
            }
            
        default:
            break
        }
    }
}
