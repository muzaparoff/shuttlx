import Foundation
import HealthKit
import Combine

@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isWorkoutActive = false
    @Published var currentProgram: TrainingProgram?
    @Published var currentInterval: TrainingInterval?
    @Published var currentIntervalIndex = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var heartRate: Int = 0
    @Published var calories: Int = 0
    
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var timer: Timer?
    private var intervalStartTime: Date?
    
    // Sample programs for the watch
    let availablePrograms: [TrainingProgram] = [
        TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),    // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),    // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),    // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)     // 5min cooldown
            ],
            maxPulse: 160,
            createdDate: Date(),
            lastModified: Date()
        ),
        TrainingProgram(
            name: "Intermediate Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),    // 5min warmup
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 90, intensity: .low),     // 1.5min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 90, intensity: .low),     // 1.5min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 90, intensity: .low),     // 1.5min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)     // 5min cooldown
            ],
            maxPulse: 170,
            createdDate: Date(),
            lastModified: Date()
        )
    ]
    
    override init() {
        super.init()
        requestHealthPermissions()
    }
    
    private func requestHealthPermissions() {
        let typesToRead: Set<HKQuantityType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout(with program: TrainingProgram) {
        guard !isWorkoutActive else { return }
        
        self.currentProgram = program
        self.currentIntervalIndex = 0
        self.currentInterval = program.intervals.first
        self.isWorkoutActive = true
        
        startWorkoutSession()
        startInterval()
    }
    
    func pauseWorkout() {
        timer?.invalidate()
        workoutSession?.pause()
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
        startInterval()
    }
    
    func stopWorkout() {
        timer?.invalidate()
        workoutSession?.end()
        
        isWorkoutActive = false
        currentProgram = nil
        currentInterval = nil
        currentIntervalIndex = 0
        timeRemaining = 0
    }
    
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            workoutSession?.startActivity(with: Date())
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    private func startInterval() {
        guard let interval = currentInterval else { return }
        
        timeRemaining = interval.duration
        intervalStartTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
    }
    
    private func updateTimer() {
        timeRemaining -= 1
        
        if timeRemaining <= 0 {
            nextInterval()
        }
    }
    
    private func nextInterval() {
        timer?.invalidate()
        
        guard let program = currentProgram else { return }
        
        currentIntervalIndex += 1
        
        if currentIntervalIndex >= program.intervals.count {
            // Workout completed
            stopWorkout()
            return
        }
        
        currentInterval = program.intervals[currentIntervalIndex]
        startInterval()
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle workout session state changes
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}
