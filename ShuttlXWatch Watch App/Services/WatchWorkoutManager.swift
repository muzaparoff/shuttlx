import Foundation
import HealthKit
import Combine
import WatchConnectivity

@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isWorkoutActive = false
    @Published var currentProgram: TrainingProgram?
    @Published var currentInterval: TrainingInterval?
    @Published var currentIntervalIndex = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var heartRate: Int = 0
    @Published var calories: Int = 0
    @Published var availablePrograms: [TrainingProgram] = []
    
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var timer: Timer?
    private var intervalStartTime: Date?
    private var workoutStartTime: Date?
    private var completedIntervals: [CompletedInterval] = []
    private var cancellables = Set<AnyCancellable>()
    
    private var connectivityManager: WatchConnectivityProtocol?
    
    // Fallback sample programs for the watch (used when no connectivity)
    private let samplePrograms: [TrainingProgram] = [
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
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        ),
        TrainingProgram(
            name: "Intermediate Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 185,
            createdDate: Date().addingTimeInterval(-86400), // Yesterday
            lastModified: Date().addingTimeInterval(-86400)
        )
    ]
    
    override init() {
        super.init()
        setupConnectivity()
        requestHealthPermissions()
    }
    
    // Convenience initializer for dependency injection (useful for testing)
    init(connectivityManager: WatchConnectivityProtocol? = nil) {
        super.init()
        self.connectivityManager = connectivityManager
        setupConnectivity()
        requestHealthPermissions()
    }
    
    private func setupConnectivity() {
        // Use injected connectivity manager or create the shared instance
        if connectivityManager == nil {
            connectivityManager = WatchConnectivityManager.shared
        }
        
        // Listen for programs from iPhone
        connectivityManager?.receivedProgramsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] programs in
                self?.updateAvailablePrograms(programs)
            }
            .store(in: &cancellables)
        
        // Set initial programs (fallback to sample data)
        updateAvailablePrograms(connectivityManager?.receivedPrograms ?? [])
    }
    
    private func updateAvailablePrograms(_ receivedPrograms: [TrainingProgram]) {
        if receivedPrograms.isEmpty {
            // Use fallback sample programs when no programs received from iPhone
            availablePrograms = samplePrograms
        } else {
            availablePrograms = receivedPrograms
        }
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
        self.workoutStartTime = Date()
        self.completedIntervals = []
        
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
        
        // Create completed session and send to iPhone
        if let program = currentProgram,
           let startTime = workoutStartTime {
            let session = TrainingSession(
                programID: program.id,
                programName: program.name,
                startDate: startTime,
                endDate: Date(),
                duration: Date().timeIntervalSince(startTime),
                averageHeartRate: Double(heartRate),
                maxHeartRate: Double(heartRate), // TODO: Track actual max heart rate
                caloriesBurned: Double(calories),
                distance: 0.0, // TODO: Track actual distance
                completedIntervals: completedIntervals
            )
            
            // Send session to iPhone via connectivity manager
            connectivityManager?.sendSessionToPhone(session)
        }
        
        isWorkoutActive = false
        currentProgram = nil
        currentInterval = nil
        currentIntervalIndex = 0
        timeRemaining = 0
        workoutStartTime = nil
        completedIntervals = []
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
        
        // Mark current interval as completed
        if let interval = currentInterval {
            let completedInterval = CompletedInterval(
                intervalID: interval.id,
                actualDuration: interval.duration,
                averageHeartRate: Double(heartRate),
                maxHeartRate: Double(heartRate)
            )
            completedIntervals.append(completedInterval)
        }
        
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
