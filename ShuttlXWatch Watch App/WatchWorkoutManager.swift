//
//  WatchWorkoutManager.swift
//  ShuttlXWatch Watch App
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import HealthKit
import WatchKit
import Combine
import SwiftUI
import WatchConnectivity

@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isWorkoutActive = false
    @Published var currentWorkout: HKWorkoutSession?
    @Published var currentBuilder: HKLiveWorkoutBuilder?
    
    // Workout Metrics
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentInterval: WorkoutInterval?
    @Published var remainingIntervalTime: TimeInterval = 0
    
    // Workout State
    @Published var workoutPhase: WorkoutPhase = .ready
    @Published var intervals: [WorkoutInterval] = []
    @Published var currentIntervalIndex = 0
    @Published var isWorkoutPaused = false
    
    // MARK: - Enhanced Metrics (Apple Fitness-style)
    @Published var averageSpeed: Double = 0 // km/h
    @Published var currentPace: Double = 0 // min/km  
    @Published var averageHeartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var stepCount: Int = 0
    @Published var totalDistance: Double = 0 // in meters
    
    // Computed properties for beautiful display
    var formattedPace: String {
        guard currentPace > 0 && currentPace < 60 else { return "--:--" }
        let minutes = Int(currentPace)
        let seconds = Int((currentPace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedSpeed: String {
        if averageSpeed < 1 { return "--" }
        return String(format: "%.1f", averageSpeed)
    }
    
    var overallProgress: Double {
        guard !intervals.isEmpty else { return 0 }
        return Double(currentIntervalIndex) / Double(intervals.count)
    }
    
    var totalIntervals: Int {
        return intervals.count
    }
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var workoutTimer: Timer?
    private var intervalTimer: Timer?
    private var startDate: Date?
    private var lastHeartRateUpdate: Date?
    private var heartRateHistory: [Double] = []
    private var lastDistanceUpdate: Double = 0
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("⌚ [DEBUG] WatchWorkoutManager init called")
        checkAuthorizationStatus()
        print("⌚ [DEBUG] WatchWorkoutManager initialized with auth status: \(authorizationStatus.rawValue)")
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
    
    // MARK: - Workout Management
    func startWorkout(from program: TrainingProgram) {
        print("🏃‍♂️ [DEBUG] startWorkout(from:) called with program: \(program.name)")
        print("🏃‍♂️ [DEBUG] Program details - run: \(program.runInterval)min, walk: \(program.walkInterval)min, total: \(program.totalDuration)min")
        
        // Convert TrainingProgram to WorkoutInterval array
        let intervals = generateIntervals(from: program)
        print("🏃‍♂️ [DEBUG] Generated \(intervals.count) intervals")
        
        startWorkout(with: intervals)
        print("🏃‍♂️ [DEBUG] Called startWorkout(with intervals)")
    }
    
    private func generateIntervals(from program: TrainingProgram) -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        print("🔧 [INTERVAL-GEN] Generating intervals for '\(program.name)'")
        print("🔧 [INTERVAL-GEN] Program: run=\(program.runInterval)min, walk=\(program.walkInterval)min")
        
        // NO WARMUP - Start directly with intervals
        // Calculate number of cycles (aim for 10 cycles)
        let numberOfCycles = 10
        
        print("🔧 [INTERVAL-GEN] Will create \(numberOfCycles) cycles")
        
        // Add walk/run intervals (WALK FIRST as requested)
        for i in 0..<numberOfCycles {
            // Walk interval FIRST
            let walkDuration = program.walkInterval * 60
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Walk \(i + 1)",
                type: .rest,
                duration: walkDuration,
                targetHeartRateZone: .easy
            ))
            print("🔧 [INTERVAL-GEN] Added Walk \(i + 1): \(walkDuration)s (\(program.walkInterval)min)")
            
            // Run interval AFTER walk
            let runDuration = program.runInterval * 60
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Run \(i + 1)",
                type: .work,
                duration: runDuration,
                targetHeartRateZone: program.targetHeartRateZone
            ))
            print("🔧 [INTERVAL-GEN] Added Run \(i + 1): \(runDuration)s (\(program.runInterval)min)")
        }
        
        // NO COOLDOWN - End with last run interval
        
        print("🔧 [INTERVAL-GEN] Generated \(intervals.count) intervals:")
        for (index, interval) in intervals.enumerated() {
            let minutes = Int(interval.duration) / 60
            let seconds = Int(interval.duration) % 60
            print("   \(index + 1). \(interval.name) (\(interval.type.rawValue)) - \(minutes):\(String(format: "%02d", seconds))")
        }
        
        return intervals
    }
    
    func startWorkout(with intervals: [WorkoutInterval]) {
        print("🚀 [START-WORKOUT] Starting workout with \(intervals.count) intervals")
        
        // Prevent multiple concurrent workouts
        guard !isWorkoutActive else { 
            print("❌ [START-WORKOUT] Workout already active - stopping existing first")
            endWorkout()
            return
        }
        
        // Validate we have intervals
        guard !intervals.isEmpty else {
            print("❌ [START-WORKOUT] No intervals provided!")
            return
        }
        
        // Stop any existing timers
        stopTimers()
        
        // Set up workout state SYNCHRONOUSLY on main thread
        self.intervals = intervals
        self.currentIntervalIndex = 0
        self.isWorkoutActive = true
        self.isWorkoutPaused = false
        self.startDate = Date()
        
        // Reset metrics
        heartRate = 0
        activeCalories = 0
        distance = 0
        elapsedTime = 0
        
        // Set up first interval IMMEDIATELY
        let firstInterval = intervals[0]
        self.currentInterval = firstInterval
        self.remainingIntervalTime = firstInterval.duration
        
        print("✅ [START-WORKOUT] Setting up first interval:")
        print("   - Interval: \(firstInterval.name)")
        print("   - Type: \(firstInterval.type)")
        print("   - Duration: \(firstInterval.duration)s")
        print("   - remainingIntervalTime set to: \(self.remainingIntervalTime)")
        print("   - Expected formatted time: \(self.formattedRemainingTime)")
        
        // Set workout phase
        switch firstInterval.type {
        case .warmup: self.workoutPhase = .warming
        case .work: self.workoutPhase = .working
        case .rest: self.workoutPhase = .resting
        case .cooldown: self.workoutPhase = .cooling
        }
        
        print("✅ [START-WORKOUT] Initial setup complete:")
        print("   - Interval: \(firstInterval.name) (\(firstInterval.duration)s)")
        print("   - Remaining: \(self.remainingIntervalTime)s")
        print("   - Phase: \(self.workoutPhase)")
        print("   - formattedRemainingTime: \(self.formattedRemainingTime)")
        
        // Force immediate UI update
        self.objectWillChange.send()
        print("✅ [START-WORKOUT] Initial objectWillChange sent")
        
        // Force a second UI update after a short delay to ensure UI refreshes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
            print("✅ [START-WORKOUT] Delayed objectWillChange sent")
        }
        
        // Start timers IMMEDIATELY
        print("✅ [START-WORKOUT] About to start timers...")
        startWorkoutTimer()
        startIntervalTimer()
        print("✅ [START-WORKOUT] Timers started")
        playHapticFeedback(.start)
        
        print("✅ [START-WORKOUT] Workout started successfully!")
        print("   - isActive: \(self.isWorkoutActive)")
        print("   - Timer running: \(self.intervalTimer != nil)")
        
        // Start HealthKit session in background (non-blocking)
        startHealthKitSessionInBackground()
    }
    
    func pauseWorkout() {
        guard isWorkoutActive, !isWorkoutPaused else { 
            print("❌ Cannot pause: workout not active or already paused")
            return 
        }
        
        currentWorkout?.pause()
        isWorkoutPaused = true
        workoutPhase = .paused
        stopTimers()
        playHapticFeedback(.notification)
        print("⏸ Workout paused")
    }
    
    func resumeWorkout() {
        guard isWorkoutActive, isWorkoutPaused else { 
            print("❌ Cannot resume: workout not active or not paused")
            return 
        }
        
        currentWorkout?.resume()
        isWorkoutPaused = false
        workoutPhase = getCurrentPhase()
        startWorkoutTimer()
        startIntervalTimer()
        playHapticFeedback(.start)
        print("▶️ Workout resumed")
    }
    
    func endWorkout() {
        guard isWorkoutActive else { 
            print("❌ Cannot end workout: no active workout")
            return 
        }
        
        print("🛑 Ending workout...")
        
        // Stop timers immediately
        stopTimers()
        
        // End the workout session
        currentWorkout?.end()
        
        // End data collection
        currentBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error ending workout collection: \(error.localizedDescription)")
                }
                self?.finalizeWorkout()
            }
        }
    }
    
    func skipToNextInterval() {
        guard isWorkoutActive else {
            print("❌ Cannot skip interval: no active workout")
            return
        }
        
        guard currentIntervalIndex < intervals.count - 1 else {
            print("❌ Cannot skip interval: already at last interval")
            endWorkout()
            return
        }
        
        print("⏭ Skipping to next interval...")
        moveToNextInterval()
    }
    
    @MainActor
    private func moveToNextInterval() {
        print("🔄 [NEXT-INTERVAL] Moving to next interval...")
        
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= intervals.count {
            print("🏁 [NEXT-INTERVAL] All intervals completed!")
            endWorkout()
            return
        }
        
        // Setup next interval
        if let nextInterval = getCurrentInterval() {
            self.currentInterval = nextInterval
            self.remainingIntervalTime = nextInterval.duration
            print("📋 [NEXT-INTERVAL] Next interval: \(nextInterval.type.displayName) (\(formatTime(nextInterval.duration)))")
            print("📋 [NEXT-INTERVAL] remainingIntervalTime set to: \(self.remainingIntervalTime)")
            
            // Update workout phase based on interval type
            switch nextInterval.type {
            case .rest:
                workoutPhase = .resting
            case .work:
                workoutPhase = .working
            case .warmup:
                workoutPhase = .warming
            case .cooldown:
                workoutPhase = .cooling
            }
            
            // Force UI update
            self.objectWillChange.send()
            
            // Play haptic feedback for interval change
            playHapticFeedback(.notification)
            
            // Start timer for new interval
            startIntervalTimer()
        }
    }
    
    private func finalizeWorkout() {
        print("🏁 Finalizing workout...")
        
        // Save workout data before resetting
        saveWorkoutData()
        
        // Reset state
        isWorkoutActive = false
        isWorkoutPaused = false
        workoutPhase = .completed
        currentWorkout = nil
        currentBuilder = nil
        currentInterval = nil
        currentIntervalIndex = 0
        stopTimers()
        resetMetrics()
        playHapticFeedback(.success)
        
        print("✅ Workout finalized")
    }
    
    private func saveWorkoutData() {
        print("💾 Saving workout data...")
        
        guard let startDate = startDate else {
            print("❌ Cannot save workout: no start date")
            return
        }
        
        // Save workout results for syncing back to iPhone
        let results = WorkoutResults(
            workoutId: UUID(),
            startDate: startDate,
            endDate: Date(),
            totalDuration: elapsedTime,
            activeCalories: activeCalories,
            heartRate: heartRate,
            distance: distance,
            completedIntervals: currentIntervalIndex,
            averageHeartRate: heartRate, // TODO: Calculate actual average
            maxHeartRate: heartRate // TODO: Track actual max
        )
        
        do {
            // Store for later sync to iPhone
            let data = try JSONEncoder().encode(results)
            UserDefaults.standard.set(data, forKey: "lastWorkoutResults")
            
            // Also save to a list of all completed workouts
            var allWorkouts: [WorkoutResults] = []
            if let existingData = UserDefaults.standard.data(forKey: "completedWorkouts"),
               let existing = try? JSONDecoder().decode([WorkoutResults].self, from: existingData) {
                allWorkouts = existing
            }
            allWorkouts.append(results)
            
            // Keep only last 50 workouts to prevent excessive storage
            if allWorkouts.count > 50 {
                allWorkouts = Array(allWorkouts.suffix(50))
            }
            
            let allWorkoutsData = try JSONEncoder().encode(allWorkouts)
            UserDefaults.standard.set(allWorkoutsData, forKey: "completedWorkouts")
            
            // Try to send workout results to iPhone immediately
            sendWorkoutResultsToPhone(results)
            
            // Try to save to HealthKit if we have a workout builder
            if let builder = currentBuilder {
                builder.finishWorkout { [weak self] (workout, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Failed to save workout to HealthKit: \(error.localizedDescription)")
                        } else if let workout = workout {
                            print("✅ Workout saved to HealthKit successfully")
                            print("   - Duration: \(workout.duration)s")
                            print("   - Calories: \(self?.activeCalories ?? 0)")
                            print("   - Distance: \(self?.distance ?? 0)m")
                        }
                    }
                }
            }
            
            print("✅ Workout data saved successfully")
            print("   - Duration: \(elapsedTime)s")
            print("   - Calories: \(activeCalories)")
            print("   - Intervals completed: \(currentIntervalIndex)/\(intervals.count)")
            print("   - Distance: \(distance)m")
            
        } catch {
            print("❌ Failed to save workout data: \(error.localizedDescription)")
        }
    }
    
    private func sendWorkoutResultsToPhone(_ results: WorkoutResults) {
        // Try to send workout results to iPhone via WatchConnectivity
        guard WCSession.default.isReachable else {
            print("⌚ iPhone not reachable, workout results saved locally")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(results)
            let message = ["workoutResults": data]
            
            WCSession.default.sendMessage(message, replyHandler: { reply in
                DispatchQueue.main.async {
                    print("⌚ ✅ Workout results sent to iPhone successfully: \(reply)")
                }
            }) { error in
                DispatchQueue.main.async {
                    print("⌚ ❌ Failed to send workout results to iPhone: \(error.localizedDescription)")
                }
            }
        } catch {
            print("⌚ ❌ Failed to encode workout results for iPhone: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Interval Timer Management (Simplified and Reliable)
    private func startIntervalTimer() {
        print("⏱️ [INTERVAL-TIMER] Starting interval timer...")
        print("⏱️ [INTERVAL-TIMER] Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // Stop any existing timer first
        intervalTimer?.invalidate()
        intervalTimer = nil
        print("⏱️ [INTERVAL-TIMER] Cleared existing timer")
        
        // Validate we can start the timer
        guard isWorkoutActive && currentIntervalIndex < intervals.count else {
            print("❌ [INTERVAL-TIMER] Cannot start - invalid state")
            print("   - isActive: \(isWorkoutActive)")
            print("   - currentIndex: \(currentIntervalIndex)")
            print("   - intervals count: \(intervals.count)")
            return
        }
        
        print("⏱️ [INTERVAL-TIMER] State validation passed")
        print("⏱️ [INTERVAL-TIMER] About to create timer...")
        
        // Create and start the timer - FIXED: Proper async context for @MainActor
        intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            print("⏱️ [TIMER-FIRED] Timer callback fired! Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
            // Since class is @MainActor, we need to call from main actor context
            Task { @MainActor in
                self?.handleIntervalTimerTick(timer)
            }
        }
        
        // BACKUP: Also add immediate tick to ensure timer starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let timer = self.intervalTimer, timer.isValid {
                print("⏱️ [TIMER-BACKUP] Triggering backup timer tick to ensure startup")
                Task { @MainActor in
                    self.handleIntervalTimerTick(timer)
                }
            }
        }
        
        // Add to RunLoop for watchOS reliability
        if let timer = intervalTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("⏱️ [INTERVAL-TIMER] Timer added to RunLoop successfully")
            print("⏱️ [INTERVAL-TIMER] Timer valid: \(timer.isValid)")
            print("⏱️ [INTERVAL-TIMER] Timer interval: \(timer.timeInterval)")
        } else {
            print("❌ [INTERVAL-TIMER] Failed to create timer!")
            return
        }
        
        print("✅ [INTERVAL-TIMER] Timer started successfully")
        print("   - Current time: \(remainingIntervalTime)s")
        print("   - Current interval: \(currentInterval?.name ?? "nil")")
        print("   - Timer object: \(intervalTimer != nil ? "EXISTS" : "NIL")")
    }
    
    private func handleIntervalTimerTick(_ timer: Timer) {
        print("⏱️ [TIMER-TICK] === TICK START ===")
        print("⏱️ [TIMER-TICK] Timer valid: \(timer.isValid)")
        print("⏱️ [TIMER-TICK] Workout active: \(isWorkoutActive)")
        print("⏱️ [TIMER-TICK] Workout paused: \(isWorkoutPaused)")
        print("⏱️ [TIMER-TICK] Remaining time BEFORE: \(remainingIntervalTime)")
        
        // Validate timer should continue
        guard timer.isValid && isWorkoutActive && !isWorkoutPaused else {
            print("❌ [TIMER-TICK] Guard failed - stopping timer")
            print("   - timer.isValid: \(timer.isValid)")
            print("   - isWorkoutActive: \(isWorkoutActive)")
            print("   - isWorkoutPaused: \(isWorkoutPaused)")
            if !isWorkoutActive {
                timer.invalidate()
                intervalTimer = nil
            }
            return
        }
        
        // Validate we have a current interval
        guard let currentInterval = currentInterval else {
            print("❌ [TIMER-TICK] No current interval - stopping timer")
            timer.invalidate()
            intervalTimer = nil
            return
        }
        
        print("⏱️ [TIMER-TICK] Current interval: \(currentInterval.name)")
        
        // Decrement remaining time
        if remainingIntervalTime > 0 {
            print("⏱️ [TIMER-TICK] Decrementing time from \(remainingIntervalTime)")
            remainingIntervalTime -= 1.0
            print("⏱️ [TIMER-TICK] New remaining time: \(remainingIntervalTime)")
            
            // Log progress for important intervals
            let remaining = Int(remainingIntervalTime)
            if remaining % 10 == 0 || remaining <= 5 {
                print("⏱️ [TIMER-TICK] \(remaining)s remaining for '\(currentInterval.name)'")
            }
            
            // Force immediate UI update with async dispatch to main
            print("⏱️ [TIMER-TICK] Sending objectWillChange...")
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            print("⏱️ [TIMER-TICK] objectWillChange dispatched to main")
        } else {
            print("⏱️ [TIMER-TICK] remainingIntervalTime is already 0 or negative")
        }
        
        print("⏱️ [TIMER-TICK] Remaining time AFTER: \(remainingIntervalTime)")
        print("⏱️ [TIMER-TICK] === TICK END ===")
        
        // Check if interval completed
        if remainingIntervalTime <= 0 {
            print("✅ [TIMER-TICK] Interval '\(currentInterval.name)' completed!")
            
            // Stop current timer
            timer.invalidate()
            intervalTimer = nil
            
            // Move to next interval
            moveToNextInterval()
        }
    }
    
    private func getCurrentPhase() -> WorkoutPhase {
        guard currentIntervalIndex < intervals.count else { return .completed }
        
        let interval = intervals[currentIntervalIndex]
        switch interval.type {
        case .warmup: return .warming
        case .work: return .working
        case .rest: return .resting
        case .cooldown: return .cooling
        }
    }
    
    // MARK: - Timer Management (SIMPLIFIED & FIXED)
    private func startWorkoutTimer() {
        // Stop any existing timer
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        print("🚀 [TIMER-FIX] Starting workout timer...")
        
        // Create simplified timer for watchOS
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                self?.handleWorkoutTimerTick(timer)
            }
        }
        
        // Add to RunLoop for watchOS reliability
        if let timer = workoutTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("✅ [TIMER-FIX] Workout timer started successfully")
    }
    
    @MainActor
    private func handleWorkoutTimerTick(_ timer: Timer) {
        guard timer.isValid && isWorkoutActive else {
            if !isWorkoutActive {
                timer.invalidate()
                workoutTimer = nil
            }
            return
        }
        
        // Update elapsed time
        updateElapsedTime()
        
        // Force UI update 
        objectWillChange.send()
        
        // Debug every 30 seconds
        let elapsed = Int(elapsedTime)
        if elapsed % 30 == 0 || elapsed <= 5 {
            print("🚀 [TIMER-FIX] Workout timer: \(formattedElapsedTime) elapsed")
        }
    }
    
    private func updateElapsedTime() {
        guard let startDate = startDate else { return }
        elapsedTime = Date().timeIntervalSince(startDate)
        
        // Enhanced metrics calculations (Apple Fitness-style)
        updateMetricsCalculations()
        
        // Use enhanced calorie calculation if HealthKit data isn't available
        if activeCalories < 10 { // HealthKit hasn't provided data yet
            activeCalories = calculateEstimatedCalories()
        }
    }
    
    private func stopTimers() {
        workoutTimer?.invalidate()
        intervalTimer?.invalidate()
        workoutTimer = nil
        intervalTimer = nil
        print("⏹ Timers stopped")
    }
    
    private func resetMetrics() {
        heartRate = 0
        activeCalories = 0
        distance = 0
        elapsedTime = 0
        // NOTE: Do NOT reset remainingIntervalTime here - it's a timer state, not a workout metric
        print("🔄 Metrics reset (preserved remainingIntervalTime: \(remainingIntervalTime)s)")
    }
    
    // MARK: - Additional Computed Properties
    var nextInterval: WorkoutInterval? {
        let nextIndex = currentIntervalIndex + 1
        guard nextIndex < intervals.count else { return nil }
        return intervals[nextIndex]
    }
    
    var intervalProgress: Double {
        guard let interval = getCurrentInterval() else { return 0.0 }
        let elapsed = interval.duration - remainingIntervalTime
        return elapsed / interval.duration
    }
    
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
    
    var formattedIntervalTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Haptic Feedback
    private func playHapticFeedback(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    // MARK: - Helper Methods
    private func getCurrentInterval() -> WorkoutInterval? {
        guard currentIntervalIndex < intervals.count else { return nil }
        return intervals[currentIntervalIndex]
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
                self.isWorkoutPaused = false
            case .paused:
                self.isWorkoutPaused = true
            case .ended:
                self.finalizeWorkout()
            default:
                break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("❌ Workout session failed: \(error.localizedDescription)")
            self.finalizeWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        DispatchQueue.main.async {
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                
                let statistics = workoutBuilder.statistics(for: quantityType)
                
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                    
                case HKQuantityType(.activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeCalories = statistics?.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                    
                case HKQuantityType(.distanceWalkingRunning):
                    let distanceUnit = HKUnit.meter()
                    self.distance = statistics?.sumQuantity()?.doubleValue(for: distanceUnit) ?? 0
                    
                default:
                    break
                }
            }
        }
    }
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - Supporting Models
struct WorkoutInterval: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: IntervalType
    let duration: TimeInterval // in seconds
    let targetHeartRateZone: HeartRateZone
    
    enum IntervalType: String, Codable {
        case warmup, work, rest, cooldown
        
        var displayName: String {
            switch self {
            case .warmup: return "Warm Up"
            case .work: return "Work"
            case .rest: return "Rest"
            case .cooldown: return "Cool Down"
            }
        }
        
        var icon: String {
            switch self {
            case .warmup: return "flame"
            case .work: return "bolt.fill"
            case .rest: return "pause.fill"
            case .cooldown: return "leaf.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .warmup: return .yellow
            case .work: return .red
            case .rest: return .green
            case .cooldown: return .blue
            }
        }
    }
}

enum WorkoutPhase: String, CaseIterable {
    case ready, warming, working, resting, cooling, paused, completed
    
    var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .warming: return "Warm Up"
        case .working: return "Work"
        case .resting: return "Rest"
        case .cooling: return "Cool Down"
        case .paused: return "Paused"
        case .completed: return "Complete"
        }
    }
    
    var color: Color {
        switch self {
        case .ready: return .blue
        case .warming: return .yellow
        case .working: return .red
        case .resting: return .green
        case .cooling: return .purple
        case .paused: return .orange
        case .completed: return .gray
        }
    }
}

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

// MARK: - DEBUG Functions (for testing timer fixes)
extension WatchWorkoutManager {
    
    // CRITICAL FIX: Simple timer-only workout (bypasses HealthKit completely)
    func startSimpleTimerOnlyWorkout(from program: TrainingProgram) {
        print("🆘 [SIMPLE-TIMER] Starting timer-only workout (no HealthKit)")
        
        // Stop any existing workout
        if isWorkoutActive {
            endWorkout()
        }
        
        // Generate intervals
        let intervals = generateIntervals(from: program)
        print("🆘 [SIMPLE-TIMER] Generated \(intervals.count) intervals")
        
        // Set up basic state
        self.intervals = intervals
        self.currentIntervalIndex = 0
        self.isWorkoutActive = true
        self.isWorkoutPaused = false
        self.startDate = Date()
        self.workoutPhase = .warming
        
        // Set up first interval
        if let firstInterval = intervals.first {
            self.currentInterval = firstInterval
            self.remainingIntervalTime = firstInterval.duration
            
            print("🆘 [SIMPLE-TIMER] First interval: \(firstInterval.name) for \(firstInterval.duration)s")
            print("🆘 [SIMPLE-TIMER] remainingIntervalTime set to: \(self.remainingIntervalTime)")
        }
        
        // Force UI update
        self.objectWillChange.send()
        
        // Start simple timers only
        print("🆘 [SIMPLE-TIMER] Starting simple timers...")
        self.startSimpleBackupTimer()
        self.startWorkoutTimer()
        
        print("✅ [SIMPLE-TIMER] Simple timer-only workout started successfully!")
        print("📊 [SIMPLE-TIMER] State: isActive=\(self.isWorkoutActive), interval=\(self.currentInterval?.name ?? "nil"), remaining=\(self.remainingIntervalTime)s")
    }
}

// MARK: - Simple Backup Timer (for reliability)
extension WatchWorkoutManager {
    private func startSimpleBackupTimer() {
        print("🆘 [BACKUP-TIMER] Starting simple backup timer...")
        
        // Create a simple timer that updates UI every second regardless of HealthKit
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSimpleBackupMetrics()
            }
        }
        
        print("✅ [BACKUP-TIMER] Simple backup timer started")
    }
    
    @MainActor
    private func updateSimpleBackupMetrics() {
        // Update elapsed time
        updateElapsedTime()
        
        // Simulate basic metrics if HealthKit is not providing them
        if activeCalories == 0 {
            activeCalories += 0.2 // Roughly 12 calories per minute
        }
        
        if distance == 0 {
            distance += 2.0 // Roughly 2 meters per second for moderate pace
        }
        
        if heartRate == 0 {
            heartRate = Double.random(in: 120...150) // Simulated heart rate
        }
        
        // Force UI update
        objectWillChange.send()
    }
}

// MARK: - HealthKit Background Session (non-blocking)
extension WatchWorkoutManager {
    private func startHealthKitSessionInBackground() {
        print("🏃‍♂️ [HEALTHKIT-BG] Starting HealthKit session in background...")
        
        Task {
            do {
                // Create workout configuration
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .mixedCardio
                configuration.locationType = .outdoor
                
                // Create workout session
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                
                // Enable data collection
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                
                // Set delegates
                session.delegate = self
                builder.delegate = self
                
                // Start session on background thread
                let startDate = Date()
                session.startActivity(with: startDate)
                builder.beginCollection(withStart: startDate) { success, error in
                    if let error = error {
                        print("❌ [HEALTHKIT-BG] Failed to begin data collection: \(error.localizedDescription)")
                    } else if success {
                        print("✅ [HEALTHKIT-BG] Data collection started successfully")
                    }
                }
                
                // Update main thread
                await MainActor.run {
                    self.currentWorkout = session
                    self.currentBuilder = builder
                    print("✅ [HEALTHKIT-BG] HealthKit session started successfully")
                }
                
            } catch {
                await MainActor.run {
                    print("❌ [HEALTHKIT-BG] Failed to start HealthKit session: \(error.localizedDescription)")
                    // Continue with timer-only workout
                }
            }
        }
    }
    
    // MARK: - Enhanced Metrics Calculations (Apple Fitness-style)
    private func updateMetricsCalculations() {
        // Update heart rate statistics
        if self.heartRate > 0 {
            heartRateHistory.append(self.heartRate)
            
            // Keep last 60 readings (1 minute of data)
            if heartRateHistory.count > 60 {
                heartRateHistory.removeFirst()
            }
            
            // Calculate average and max
            self.averageHeartRate = heartRateHistory.reduce(0, +) / Double(heartRateHistory.count)
            self.maxHeartRate = max(self.maxHeartRate, self.heartRate)
        }
        
        // Update speed and pace calculations
        updateSpeedAndPace()
        
        // Update total distance tracking
        self.totalDistance = self.distance
    }
    
    private func updateSpeedAndPace() {
        guard elapsedTime > 0 else { return }
        
        // Calculate average speed (km/h)
        let distanceInKm = self.distance / 1000.0
        let timeInHours = self.elapsedTime / 3600.0
        
        if timeInHours > 0 {
            averageSpeed = distanceInKm / timeInHours
        }
        
        // Calculate current pace (min/km)
        if self.distance > 0 && self.elapsedTime > 0 {
            let elapsedMinutes = self.elapsedTime / 60.0
            currentPace = elapsedMinutes / distanceInKm
        }
    }
    
    private func calculateEstimatedCalories() -> Double {
        // Enhanced calorie calculation based on multiple factors
        guard self.elapsedTime > 0 else { return 0 }
        
        let timeInMinutes = self.elapsedTime / 60.0
        let _ = self.distance / 1000.0 // Distance in km (may be used in future enhancements)
        
        // Base calculation: METs * weight * time
        // Running: 8-12 METs, Walking: 3-4 METs
        let averageMETs = 7.0 // Mixed running/walking
        let estimatedWeight = 70.0 // kg (average)
        
        let baseCals = averageMETs * estimatedWeight * (timeInMinutes / 60.0)
        
        // Adjust for heart rate if available
        var hrMultiplier = 1.0
        if self.averageHeartRate > 0 {
            // Higher heart rate = more calories
            let hrZone = self.averageHeartRate / 180.0 // Rough zone calculation
            hrMultiplier = 0.8 + (hrZone * 0.4) // 0.8 to 1.2 multiplier
        }
        
        return baseCals * hrMultiplier
    }
}
