//
//  WatchWorkoutManager.swift
//  ShuttlX Watch App
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import HealthKit
import WatchKit
import Combine

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
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
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
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = healthStore.authorizationStatus(for: HKQuantityType.workoutType())
    }
    
    // MARK: - Workout Management
    func startWorkout(with intervals: [WorkoutInterval]) {
        guard !isWorkoutActive else { 
            print("❌ Workout already active")
            return 
        }
        
        guard !intervals.isEmpty else {
            print("❌ Cannot start workout with empty intervals")
            return
        }
        
        self.intervals = intervals
        self.currentIntervalIndex = 0
        self.workoutPhase = .warming
        
        // Reset all metrics
        resetMetrics()
        
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
            
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.isWorkoutActive = true
                        self?.isWorkoutPaused = false
                        self?.startDate = Date()
                        self?.startWorkoutTimer()
                        self?.startIntervalTimer()
                        self?.playHapticFeedback(.start)
                        print("✅ Workout started successfully")
                    } else {
                        print("❌ Failed to start workout collection: \(error?.localizedDescription ?? "Unknown error")")
                        self?.finalizeWorkout()
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
    
    // MARK: - Interval Management
    private func startIntervalTimer() {
        guard currentIntervalIndex < intervals.count else { 
            print("❌ Cannot start interval timer: index out of bounds (\(currentIntervalIndex) >= \(intervals.count))")
            return 
        }
        
        // Stop any existing interval timer
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        currentInterval = intervals[currentIntervalIndex]
        guard let interval = currentInterval else {
            print("❌ Current interval is nil")
            return
        }
        
        remainingIntervalTime = interval.duration
        
        guard remainingIntervalTime > 0 else {
            print("❌ Invalid interval duration: \(remainingIntervalTime)")
            completeCurrentInterval()
            return
        }
        
        print("⏱ Starting interval \(currentIntervalIndex + 1)/\(intervals.count) - \(interval.type.displayName) for \(remainingIntervalTime)s")
        
        // Ensure timer runs on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.intervalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.isWorkoutActive && !self.isWorkoutPaused {
                    self.updateInterval()
                } else {
                    print("⚠️ Timer running but workout not active/paused - stopping timer")
                    timer.invalidate()
                    self.intervalTimer = nil
                }
            }
            
            // Add timer to run loop to ensure it fires consistently
            if let timer = self.intervalTimer {
                RunLoop.current.add(timer, forMode: .common)
                print("✅ Interval timer started successfully")
            } else {
                print("❌ Failed to create interval timer")
            }
        }
    }
    
    private func updateInterval() {
        remainingIntervalTime -= 1
        
        // Interval completion
        if remainingIntervalTime <= 0 {
            completeCurrentInterval()
            return
        }
        
        // Warning haptics at 3, 2, 1 seconds remaining
        if remainingIntervalTime <= 3 && remainingIntervalTime > 0 {
            playHapticFeedback(.notification)
        }
    }
    
    private func completeCurrentInterval() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        playHapticFeedback(.directionUp)
        print("✅ Completed interval \(currentIntervalIndex + 1)")
        
        currentIntervalIndex += 1
        
        if currentIntervalIndex < intervals.count {
            // Move to next interval
            workoutPhase = getCurrentPhase()
            
            // Small delay between intervals
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startIntervalTimer()
            }
        } else {
            // Workout complete
            print("🎉 All intervals completed!")
            endWorkout()
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
        default: return .working
        }
    }
    
    // MARK: - Timer Management
    private func startWorkoutTimer() {
        // Stop any existing timer
        workoutTimer?.invalidate()
        workoutTimer = nil
        
        print("⏱ Starting workout timer...")
        
        // Ensure timer runs on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.isWorkoutActive {
                    self.updateElapsedTime()
                } else {
                    print("⚠️ Workout timer running but workout not active - stopping timer")
                    timer.invalidate()
                    self.workoutTimer = nil
                }
            }
            
            // Add timer to run loop to ensure it fires consistently
            if let timer = self.workoutTimer {
                RunLoop.current.add(timer, forMode: .common)
                print("✅ Workout timer started successfully")
            } else {
                print("❌ Failed to create workout timer")
            }
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
    
    // MARK: - Haptic Feedback
    private func playHapticFeedback(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
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
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("Workout session failed: \(error)")
            self.finalizeWorkout()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            DispatchQueue.main.async {
                self.updateMetric(for: type, from: workoutBuilder)
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
    
    private func updateMetric(for type: HKSampleType, from builder: HKLiveWorkoutBuilder) {
        guard let quantityType = type as? HKQuantityType else { return }
        
        let statistics = builder.statistics(for: quantityType)
        
        switch quantityType {
        case HKQuantityType(.heartRate):
            if let mostRecentQuantity = statistics?.mostRecentQuantity() {
                heartRate = mostRecentQuantity.doubleValue(for: .count().unitDivided(by: .minute()))
            }
        case HKQuantityType(.activeEnergyBurned):
            if let sumQuantity = statistics?.sumQuantity() {
                activeCalories = sumQuantity.doubleValue(for: .kilocalorie())
            }
        case HKQuantityType(.distanceWalkingRunning):
            if let sumQuantity = statistics?.sumQuantity() {
                distance = sumQuantity.doubleValue(for: .meter())
            }
        default:
            break
        }
    }
}

// MARK: - Supporting Types
enum WorkoutPhase {
    case ready
    case warming
    case working
    case resting
    case cooling
    case paused
    case completed
    
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
        case .cooling: return .cyan
        case .paused: return .orange
        case .completed: return .purple
        }
    }
}
