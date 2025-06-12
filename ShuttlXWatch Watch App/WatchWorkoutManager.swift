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
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var workoutTimer: Timer?
    private var intervalTimer: Timer?
    private var startDate: Date?
    
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
        
        // Add warmup
        intervals.append(WorkoutInterval(
            id: UUID(),
            name: "Warm Up",
            type: .warmup,
            duration: 300, // 5 minutes
            targetHeartRateZone: .easy
        ))
        
        // Calculate number of run/walk cycles based on total duration
        let totalWorkoutTime = program.totalDuration * 60 // convert to seconds
        let warmupCooldownTime: TimeInterval = 600 // 10 minutes total
        let availableTime = totalWorkoutTime - warmupCooldownTime
        let cycleTime = (program.runInterval + program.walkInterval) * 60 // convert to seconds
        let numberOfCycles = Int(availableTime / cycleTime)
        
        // Add run/walk intervals
        for i in 0..<numberOfCycles {
            // Run interval
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Run \(i + 1)",
                type: .work,
                duration: program.runInterval * 60,
                targetHeartRateZone: program.targetHeartRateZone
            ))
            
            // Walk interval (except after the last run)
            if i < numberOfCycles - 1 {
                intervals.append(WorkoutInterval(
                    id: UUID(),
                    name: "Walk \(i + 1)",
                    type: .rest,
                    duration: program.walkInterval * 60,
                    targetHeartRateZone: .easy
                ))
            }
        }
        
        // Add cooldown
        intervals.append(WorkoutInterval(
            id: UUID(),
            name: "Cool Down",
            type: .cooldown,
            duration: 300, // 5 minutes
            targetHeartRateZone: .easy
        ))
        
        return intervals
    }
    
    func startWorkout(with intervals: [WorkoutInterval]) {
        print("🏃‍♂️ [DEBUG] startWorkout(with intervals) called with \(intervals.count) intervals")
        print("🏃‍♂️ [DEBUG] Current isWorkoutActive: \(isWorkoutActive)")
        
        guard !isWorkoutActive else { 
            print("❌ [DEBUG] Workout already active - returning early")
            return 
        }
        
        print("🏃‍♂️ [DEBUG] Starting workout with \(intervals.count) intervals")
        print("🏃‍♂️ [DEBUG] Authorization status: \(authorizationStatus.rawValue)")
        
        // Check authorization status but don't block if not authorized
        if authorizationStatus != .sharingAuthorized {
            print("⚠️ HealthKit not fully authorized (\(authorizationStatus.rawValue)), but continuing workout...")
        }
        
        self.intervals = intervals
        self.currentIntervalIndex = 0
        self.workoutPhase = .warming
        
        // Reset metrics but DON'T reset interval time yet
        heartRate = 0
        activeCalories = 0
        distance = 0
        elapsedTime = 0
        // remainingIntervalTime will be set by startIntervalTimer()
        
        // Set up first interval IMMEDIATELY on main thread
        if let firstInterval = intervals.first {
            self.currentInterval = firstInterval
            self.remainingIntervalTime = firstInterval.duration
            print("🚀 [TIMER-INIT-FIX] First interval setup: \(firstInterval.name) - \(firstInterval.type.displayName) for \(firstInterval.duration)s")
            print("🚀 [TIMER-INIT-FIX] remainingIntervalTime set to: \(self.remainingIntervalTime)")
            print("🚀 [TIMER-INIT-FIX] Formatted time should show: \(self.formattedRemainingTime)")
            
            // Update workout phase for first interval
            switch firstInterval.type {
            case .warmup: self.workoutPhase = .warming
            case .work: self.workoutPhase = .working
            case .rest: self.workoutPhase = .resting
            case .cooldown: self.workoutPhase = .cooling
            }
            
            // Force immediate UI update
            self.objectWillChange.send()
            
            print("✅ [TIMER-INIT-FIX] First interval fully configured")
        } else {
            print("❌ [TIMER-INIT-FIX] No intervals available!")
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .outdoor
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            session.delegate = self
            builder.delegate = self
            
            currentWorkout = session
            currentBuilder = builder
            
            // Start the session first
            session.startActivity(with: Date())
            
            // Set initial state
            self.isWorkoutActive = true
            self.isWorkoutPaused = false
            self.startDate = Date()
            
            // Start timers immediately (don't wait for HealthKit)
            self.startWorkoutTimer()
            self.startIntervalTimer()
            self.playHapticFeedback(.start)
            
            print("✅ [TIMER-DEBUG] Workout started successfully with timers active")
            print("📊 [TIMER-DEBUG] Workout state: isActive=\(self.isWorkoutActive), isPaused=\(self.isWorkoutPaused)")
            print("📊 [TIMER-DEBUG] Current interval: \(self.currentIntervalIndex + 1)/\(self.intervals.count)")
            print("⏱ [TIMER-DEBUG] First interval: \(self.currentInterval?.name ?? "unknown") for \(self.remainingIntervalTime)s")
            
            // Begin HealthKit data collection
            builder.beginCollection(withStart: Date()) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Workout HealthKit collection started successfully")
                    } else {
                        print("⚠️ HealthKit collection failed but workout continues: \(error?.localizedDescription ?? "Unknown error")")
                        // Don't finalize workout - let it continue even if HealthKit fails
                    }
                }
            }
        } catch {
            print("❌ Failed to start workout: \(error)")
            finalizeWorkout()
        }
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
    
    // MARK: - Interval Management (SIMPLIFIED & FIXED)
    private func startIntervalTimer() {
        print("🚀 [TIMER-FIX] startIntervalTimer() called")
        
        guard currentIntervalIndex < intervals.count else { 
            print("❌ [TIMER-FIX] Cannot start interval timer: index out of bounds")
            endWorkout()
            return 
        }
        
        // Stop any existing interval timer FIRST
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        // Get current interval
        let interval = intervals[currentIntervalIndex]
        guard interval.duration > 0 else {
            print("❌ [TIMER-FIX] Invalid interval duration: \(interval.duration)")
            moveToNextInterval()
            return
        }
        
        print("🚀 [TIMER-FIX] Setting up interval: \(interval.name) for \(interval.duration)s")
        
        // Set properties synchronously on main thread
        currentInterval = interval
        remainingIntervalTime = interval.duration
        
        // Update workout phase
        switch interval.type {
        case .warmup: workoutPhase = .warming
        case .work: workoutPhase = .working
        case .rest: workoutPhase = .resting
        case .cooldown: workoutPhase = .cooling
        }
        
        // Force immediate UI update
        objectWillChange.send()
        
        // Create simplified timer for watchOS
        intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                self?.handleIntervalTimerTick(timer)
            }
        }
        
        // Add to RunLoop for watchOS reliability
        if let timer = intervalTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("✅ [TIMER-FIX] Interval timer started successfully")
    }
    
    @MainActor
    private func handleIntervalTimerTick(_ timer: Timer) {
        // Verify timer is still valid and workout is active
        guard timer.isValid && isWorkoutActive && !isWorkoutPaused else {
            if !isWorkoutActive {
                timer.invalidate()
                intervalTimer = nil
            }
            return
        }
        
        // Decrement timer
        remainingIntervalTime = max(0, remainingIntervalTime - 1.0)
        
        // Debug output for critical intervals
        let remaining = Int(remainingIntervalTime)
        if remaining % 5 == 0 || remaining <= 10 {
            print("⏱️ [TIMER-FIX] \(remaining)s remaining for '\(currentInterval?.name ?? "unknown")'")
        }
        
        // Force UI update
        objectWillChange.send()
        
        // Check if interval is complete
        if remainingIntervalTime <= 0 {
            print("✅ [TIMER-FIX] Interval completed! Moving to next interval...")
            timer.invalidate()
            intervalTimer = nil
            remainingIntervalTime = 0
            
            // Move to next interval
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.moveToNextInterval()
            }
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
        remainingIntervalTime = 0
        print("🔄 Metrics reset")
    }
    
    // MARK: - Helper Methods
    private func createIntervals(from program: TrainingProgram) -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Add warmup
        intervals.append(WorkoutInterval(
            id: UUID(),
            name: "Warmup",
            type: .warmup,
            duration: 60, // 1 minute warmup
            targetHeartRateZone: .recovery
        ))
        
        // Calculate number of cycles
        let cycleTime = program.runInterval * 60 + program.walkInterval * 60 // Convert to seconds
        let totalWorkoutTime = program.totalDuration * 60 - 120 // Minus warmup and cooldown
        let numberOfCycles = Int(totalWorkoutTime / cycleTime)
        
        // Add run/walk cycles
        for i in 0..<numberOfCycles {
            // Run interval
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Run \(i + 1)",
                type: .work,
                duration: program.runInterval * 60,
                targetHeartRateZone: program.targetHeartRateZone
            ))
            
            // Walk interval
            intervals.append(WorkoutInterval(
                id: UUID(),
                name: "Walk \(i + 1)",
                type: .rest,
                duration: program.walkInterval * 60,
                targetHeartRateZone: .recovery
            ))
        }
        
        // Add cooldown
        intervals.append(WorkoutInterval(
            id: UUID(),
            name: "Cooldown",
            type: .cooldown,
            duration: 60, // 1 minute cooldown
            targetHeartRateZone: .recovery
        ))
        
        print("🏃‍♂️ Created \(intervals.count) intervals for \(program.name)")
        return intervals
    }
    
    // MARK: - Haptic Feedback
    private func playHapticFeedback(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    // MARK: - Debug Functions for Timer Testing
    func startQuickTimerTest() {
        print("🧪 [DEBUG-TIMER-TEST] Starting quick 10-second timer test...")
        
        // Create a simple test interval
        let testInterval = WorkoutInterval(
            id: UUID(),
            name: "Quick Test",
            type: .work,
            duration: 10, // 10 seconds for quick testing
            targetHeartRateZone: .moderate
        )
        
        // Reset state
        self.intervals = [testInterval]
        self.currentIntervalIndex = 0
        self.workoutPhase = .working
        self.isWorkoutActive = true
        self.isWorkoutPaused = false
        self.startDate = Date()
        
        // Set up the test interval
        self.currentInterval = testInterval
        self.remainingIntervalTime = testInterval.duration
        
        print("🧪 [DEBUG-TIMER-TEST] Test interval configured: \(testInterval.duration)s")
        print("🧪 [DEBUG-TIMER-TEST] remainingIntervalTime: \(self.remainingIntervalTime)")
        print("🧪 [DEBUG-TIMER-TEST] Formatted time: \(self.formattedRemainingTime)")
        
        // Force UI update
        self.objectWillChange.send()
        
        // Start both timers
        self.startWorkoutTimer()
        self.startIntervalTimer()
        
        print("✅ [DEBUG-TIMER-TEST] Quick timer test started - watch for countdown!")
    }
    
    func getTimerDebugInfo() -> String {
        let info = """
        📊 Timer Debug Info:
        • Workout Active: \(isWorkoutActive)
        • Workout Paused: \(isWorkoutPaused)
        • Current Interval: \(currentInterval?.name ?? "none")
        • Remaining Time: \(remainingIntervalTime)s
        • Formatted Time: \(formattedRemainingTime)
        • Elapsed Time: \(formattedElapsedTime)
        • Workout Timer Valid: \(workoutTimer?.isValid ?? false)
        • Interval Timer Valid: \(intervalTimer?.isValid ?? false)
        • Intervals Count: \(intervals.count)
        • Current Index: \(currentIntervalIndex)
        • Workout Phase: \(workoutPhase.rawValue)
        """
        return info
    }

    // MARK: - Computed Properties
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedRemainingTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var totalIntervals: Int {
        return intervals.count
    }
    
    var nextInterval: WorkoutInterval? {
        let nextIndex = currentIntervalIndex + 1
        guard nextIndex < intervals.count else { return nil }
        return intervals[nextIndex]
    }
    
    var overallProgress: Double {
        guard intervals.count > 0 else { return 0.0 }
        return Double(currentIntervalIndex) / Double(intervals.count)
    }
    
    var intervalProgress: Double {
        guard let interval = getCurrentInterval() else { return 0.0 }
        let elapsed = interval.duration - remainingIntervalTime
        return elapsed / interval.duration
    }
    
    var averageHeartRate: Double {
        // For now, return current heart rate as average
        // TODO: Implement proper average calculation
        return heartRate
    }
    
    var maxHeartRate: Double {
        // For now, return current heart rate as max
        // TODO: Implement proper max tracking
        return heartRate
    }
    
    var formattedIntervalTime: String {
        let minutes = Int(remainingIntervalTime) / 60
        let seconds = Int(remainingIntervalTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedPace: String {
        guard distance > 0 && elapsedTime > 0 else { return "--:--" }
        let pacePerKm = (elapsedTime / 60.0) / (distance / 1000.0) // minutes per km
        let minutes = Int(pacePerKm)
        let seconds = Int((pacePerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
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
    func startQuickTest() {
        print("🧪 [DEBUG-TEST] Starting quick timer test...")
        
        let testIntervals = [
            WorkoutInterval(
                id: UUID(),
                name: "Test Warm Up",
                type: .warmup,
                duration: 10, // 10 seconds for quick testing
                targetHeartRateZone: .easy
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Test Run",
                type: .work,
                duration: 15, // 15 seconds
                targetHeartRateZone: .moderate
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Test Walk",
                type: .rest,
                duration: 10, // 10 seconds
                targetHeartRateZone: .easy
            ),
            WorkoutInterval(
                id: UUID(),
                name: "Test Cool Down",
                type: .cooldown,
                duration: 5, // 5 seconds
                targetHeartRateZone: .easy
            )
        ]
        
        startWorkout(with: testIntervals)
    }
}
