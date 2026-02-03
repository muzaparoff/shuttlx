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
    @Published var healthKitAuthorized: Bool = false
    @Published var authorizationDenied: Bool = false

    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var timer: DispatchSourceTimer?
    private var intervalStartTime: Date?
    private var workoutStartTime: Date?
    private var completedIntervals: [CompletedInterval] = []
    private var cancellables = Set<AnyCancellable>()

    private var sharedDataManager: SharedDataManager?

    /// Tracks the absolute end time for the current interval to prevent drift
    private var intervalEndDate: Date?
    /// Flag to prevent multiple concurrent timer instances
    private var isTimerRunning = false

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
        logger.info("WatchWorkoutManager init() called...")
        super.init()
        logger.info("WatchWorkoutManager initialization completed (HealthKit permissions deferred)")
    }

    func setSharedDataManager(_ dataManager: SharedDataManager) {
        logger.info("Setting SharedDataManager dependency...")
        self.sharedDataManager = dataManager
        logger.info("Setting up program sync...")
        setupProgramSync()
        logger.info("SharedDataManager dependency set successfully")
    }

    // MARK: - Public Methods

    /// Request HealthKit permissions if not already granted
    func requestHealthKitPermissionsIfNeeded() {
        logger.info("Checking HealthKit permissions...")
        requestHealthPermissions()
    }

    private func setupProgramSync() {
        logger.info("Setting up program sync...")
        guard let sharedDataManager = sharedDataManager else {
            logger.warning("No SharedDataManager available, using fallback programs")
            // Use fallback programs if no data manager available
            availablePrograms = fallbackPrograms
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
    }

    private func updateAvailablePrograms(_ receivedPrograms: [TrainingProgram]) {
        if receivedPrograms.isEmpty {
            // Use fallback programs when no programs received from iPhone
            availablePrograms = fallbackPrograms
            logger.info("Using fallback programs (\(self.fallbackPrograms.count) programs)")
        } else {
            availablePrograms = receivedPrograms
            logger.info("Updated available programs (\(receivedPrograms.count) programs)")
        }
    }

    private func requestHealthPermissions() {
        // Safely create HealthKit quantity types without force unwraps
        var readTypes = Set<HKQuantityType>()
        var writeTypes = Set<HKSampleType>()

        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        } else {
            logger.warning("Failed to create heartRate HKQuantityType")
        }

        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergyType)
            writeTypes.insert(activeEnergyType)
        } else {
            logger.warning("Failed to create activeEnergyBurned HKQuantityType")
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distanceType)
            writeTypes.insert(distanceType)
        } else {
            logger.warning("Failed to create distanceWalkingRunning HKQuantityType")
        }

        writeTypes.insert(HKWorkoutType.workoutType())

        guard !readTypes.isEmpty else {
            logger.error("No valid HealthKit types available for authorization")
            return
        }

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("HealthKit authorization error: \(error.localizedDescription)")
                    self.authorizationDenied = true
                    self.healthKitAuthorized = false
                } else if !success {
                    self.logger.warning("HealthKit authorization was denied by user")
                    self.authorizationDenied = true
                    self.healthKitAuthorized = false
                } else {
                    self.logger.info("HealthKit authorization granted")
                    self.healthKitAuthorized = true
                    self.authorizationDenied = false
                }
            }
        }
    }

    func startWorkout(with program: TrainingProgram) {
        guard !isWorkoutActive else {
            logger.warning("Attempted to start workout when already active")
            return
        }

        logger.info("Starting workout with program: \(program.name)")
        logger.info("Program has \(program.intervals.count) intervals")

        // Ensure HealthKit permissions are requested before starting workout
        requestHealthKitPermissionsIfNeeded()

        self.currentProgram = program
        self.currentIntervalIndex = 0
        self.currentInterval = program.intervals.first
        self.isWorkoutActive = true
        self.workoutStartTime = Date()
        self.completedIntervals = []

        logger.info("Workout state updated - isWorkoutActive: \(self.isWorkoutActive)")

        startWorkoutSession()
        startInterval()

        logger.info("Workout session started successfully")
    }

    func pauseWorkout() {
        cancelTimer()
        workoutSession?.pause()
        // Save data on pause in case the app is killed
        saveWorkoutDataToLocalStorage()
        logger.info("Workout paused")
    }

    func resumeWorkout() {
        workoutSession?.resume()
        startInterval()
        logger.info("Workout resumed")
    }

    func stopWorkout() {
        cancelTimer()
        workoutSession?.end()
        workoutSession = nil

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
            logger.info("Session sent to iOS: \(session.programName), Duration: \(Int(session.duration))s")
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
        intervalEndDate = nil
    }

    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit data not available on this device")
            return
        }

        #if os(watchOS)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            workoutSession?.startActivity(with: Date())
            logger.info("HKWorkoutSession started successfully")
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
            // Workout can still proceed without HealthKit session for timer/interval tracking
        }
        #else
        // On iOS, HKWorkoutSession is not available
        logger.info("Workout session started on iOS (simplified)")
        #endif
    }

    // MARK: - Timer Management

    /// Starts the interval timer using DispatchSourceTimer to avoid drift.
    /// Uses an absolute end date so the countdown is always accurate
    /// even if the Watch screen turns off and the timer fires are delayed.
    private func startInterval() {
        guard let interval = currentInterval else { return }

        // Cancel any existing timer first to prevent stacking
        cancelTimer()

        let now = Date()
        intervalStartTime = now
        intervalEndDate = now.addingTimeInterval(interval.duration)
        timeRemaining = interval.duration

        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        newTimer.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))

        newTimer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateTimer()
            }
        }

        isTimerRunning = true
        self.timer = newTimer
        newTimer.resume()
    }

    /// Calculates remaining time from the absolute end date to prevent drift
    private func updateTimer() {
        guard let endDate = intervalEndDate else {
            cancelTimer()
            return
        }

        let remaining = endDate.timeIntervalSinceNow

        if remaining <= 0 {
            timeRemaining = 0
            nextInterval()
        } else {
            timeRemaining = remaining
        }
    }

    /// Safely cancels and cleans up the current timer
    private func cancelTimer() {
        if let existingTimer = timer {
            existingTimer.cancel()
            timer = nil
        }
        isTimerRunning = false
    }

    private func nextInterval() {
        cancelTimer()

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

    /// Saves workout data without relying on HealthKit session state.
    /// Called when user explicitly ends workout or app is backgrounded.
    func saveWorkoutData() {
        // Create and save session regardless of workout session state
        if let program = currentProgram,
           let startTime = workoutStartTime {

            logger.info("Sending training session to iOS...")

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

            // Also persist locally in case connectivity fails
            saveWorkoutDataToLocalStorage()

            logger.info("Session sent to iOS: \(session.programName), Duration: \(Int(session.duration))s")
        }
    }

    /// Persists current workout data to local storage so it survives app backgrounding or termination
    private func saveWorkoutDataToLocalStorage() {
        guard let program = currentProgram,
              let startTime = workoutStartTime else { return }

        let session = TrainingSession(
            programID: program.id,
            programName: program.name,
            startDate: startTime,
            endDate: Date(),
            duration: Date().timeIntervalSince(startTime),
            averageHeartRate: Double(heartRate),
            maxHeartRate: Double(heartRate),
            caloriesBurned: Double(calories),
            distance: 0.0,
            completedIntervals: completedIntervals
        )

        do {
            let data = try JSONEncoder().encode(session)
            let fileManager = FileManager.default
            guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                logger.error("Could not access documents directory for workout backup")
                return
            }
            let backupURL = docsURL.appendingPathComponent("active_workout_backup.json")
            try data.write(to: backupURL)
            logger.info("Workout data backed up to local storage")
        } catch {
            logger.error("Failed to backup workout data: \(error.localizedDescription)")
        }
    }

    /// Clears the local workout backup after successful completion/sync
    private func clearWorkoutBackup() {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let backupURL = docsURL.appendingPathComponent("active_workout_backup.json")
        try? fileManager.removeItem(at: backupURL)
    }
}

// MARK: - HKWorkoutSessionDelegate
#if os(watchOS)
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            logger.info("Workout session state changed: \(fromState.rawValue) -> \(toState.rawValue)")

            switch toState {
            case .running:
                logger.info("Workout session is now running")
            case .paused:
                logger.info("Workout session is paused")
                // Persist data on pause
                saveWorkoutDataToLocalStorage()
            case .ended:
                logger.info("Workout session has ended")
                clearWorkoutBackup()
            case .stopped:
                logger.info("Workout session has stopped")
                clearWorkoutBackup()
            case .notStarted:
                logger.info("Workout session is not started")
            case .prepared:
                logger.info("Workout session is prepared")
            @unknown default:
                logger.warning("Workout session entered unknown state: \(toState.rawValue)")
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Workout session failed: \(error.localizedDescription)")
            // Save whatever data we have before the session is lost
            saveWorkoutDataToLocalStorage()
        }
    }
}
#endif
