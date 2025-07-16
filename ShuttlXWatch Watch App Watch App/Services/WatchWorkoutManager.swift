import Foundation
import HealthKit
import Combine
import WatchConnectivity
import os.log

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
    
    private var sharedDataManager: SharedDataManager?
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWorkoutManager")
    
    // Fallback sample programs for the watch (identical to iOS defaults)
    private let fallbackPrograms: [TrainingProgram] = [
        TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
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
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 185,
            createdDate: Date().addingTimeInterval(-86400), // Yesterday
            lastModified: Date().addingTimeInterval(-86400)
        )
    ]
    
    override init() {
        logger.info("🔄 WatchWorkoutManager init() called...")
        super.init()
        logger.info("✅ super.init() completed successfully")
        
        // Note: HealthKit permissions will be requested when needed, not during init
        // This prevents crashes during app startup
        logger.info("✅ WatchWorkoutManager initialization completed (HealthKit permissions deferred)")
    }
    
    func setSharedDataManager(_ dataManager: SharedDataManager) {
        logger.info("🔗 Setting SharedDataManager dependency...")
        self.sharedDataManager = dataManager
        logger.info("📊 Setting up program sync...")
        setupProgramSync()
        logger.info("✅ SharedDataManager dependency set successfully")
    }
    
    // MARK: - Public Methods
    
    /// Request HealthKit permissions if not already granted
    func requestHealthKitPermissionsIfNeeded() {
        logger.info("🏥 Checking HealthKit permissions...")
        requestHealthPermissions()
    }
    
    private func setupProgramSync() {
        logger.info("🔄 Setting up program sync...")
        guard let sharedDataManager = sharedDataManager else {
            logger.warning("⚠️ No SharedDataManager available, using fallback programs")
            // Use fallback programs if no data manager available
            availablePrograms = fallbackPrograms
            print("⚠️ No SharedDataManager available, using fallback programs")
            return
        }
        
        // Listen for programs from SharedDataManager
        sharedDataManager.$syncedPrograms
            .receive(on: DispatchQueue.main)
            .sink { [weak self] programs in
                self?.updateAvailablePrograms(programs)
            }
            .store(in: &cancellables)
        
        // Load programs immediately
        sharedDataManager.loadPrograms()
        updateAvailablePrograms(sharedDataManager.syncedPrograms)
        
        print("🔄 Program sync setup completed for watchOS")
    }
    
    private func updateAvailablePrograms(_ receivedPrograms: [TrainingProgram]) {
        if receivedPrograms.isEmpty {
            // Use fallback programs when no programs received from iPhone
            availablePrograms = fallbackPrograms
            print("⚠️ Using fallback programs (\(fallbackPrograms.count) programs)")
        } else {
            availablePrograms = receivedPrograms
            print("✅ Updated available programs (\(receivedPrograms.count) programs)")
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
        guard !isWorkoutActive else { 
            print("⚠️ Workout already active, ignoring start request")
            logger.warning("⚠️ Attempted to start workout when already active")
            return 
        }
        
        print("🏃‍♂️ Starting workout with program: \(program.name)")
        print("📊 Program has \(program.intervals.count) intervals")
        logger.info("🏃‍♂️ Starting workout with program: \(program.name)")
        logger.info("📊 Program has \(program.intervals.count) intervals")
        
        // Ensure HealthKit permissions are requested before starting workout
        requestHealthKitPermissionsIfNeeded()
        
        self.currentProgram = program
        self.currentIntervalIndex = 0
        self.currentInterval = program.intervals.first
        self.isWorkoutActive = true
        self.workoutStartTime = Date()
        self.completedIntervals = []
        
        print("✅ Workout state updated - isWorkoutActive: \(isWorkoutActive)")
        print("📱 Current program: \(currentProgram?.name ?? "nil")")
        print("⏱️ Current interval: \(currentInterval?.phase.rawValue ?? "nil")")
        logger.info("✅ Workout state updated - isWorkoutActive: \(self.isWorkoutActive)")
        logger.info("📱 Current program: \(self.currentProgram?.name ?? "nil")")
        logger.info("⏱️ Current interval: \(self.currentInterval?.phase.rawValue ?? "nil")")

        startWorkoutSession()
        startInterval()
        
        print("🚀 Workout session started successfully")
        logger.info("🚀 Workout session started successfully")
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
            
            // Send session to iPhone via SharedDataManager
            sharedDataManager?.sendSessionToiOS(session)
            print("⌚➡️📱 Session sent to iOS: \(session.programName), Duration: \(Int(session.duration))s")
        }
        
        isWorkoutActive = false
        currentProgram = nil
        currentInterval = nil
        currentIntervalIndex = 0
        timeRemaining = 0
        heartRate = 0
        calories = 0
        completedIntervals = []
        workoutStartTime = nil
        intervalStartTime = nil
    }
    
    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        #if os(watchOS)
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
        #else
        // On iOS, HKWorkoutSession is not available, so we'll use a simplified approach
        print("Workout session started on iOS (simplified)")
        #endif
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
    
    /// Public accessor for workout start time (if available)
    var elapsedWorkoutTime: TimeInterval {
        if let startTime = workoutStartTime {
            return Date().timeIntervalSince(startTime)
        }
        return 0
    }
    
    /// Saves workout data without relying on HealthKit session state
    func saveWorkoutData() {
        // Create and save session regardless of workout session state
        if let program = currentProgram,
           let startTime = workoutStartTime {
            
            print("📊 Sending training session to iOS...")
            
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
            
            // Send session to iPhone via SharedDataManager
            sharedDataManager?.sendSessionToiOS(session)
            print("⌚➡️📱 Session sent to iOS: \(session.programName), Duration: \(Int(session.duration))s")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
#if os(watchOS)
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle workout session state changes
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}
#endif
