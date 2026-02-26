import Foundation
import HealthKit
import CoreMotion
import WatchConnectivity
import os.log

@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var isWorkoutActive = false
    @Published var isPaused = false
    @Published var currentActivity: DetectedActivity = .unknown
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentSegmentTime: TimeInterval = 0
    @Published var heartRate: Int = 0
    @Published var calories: Int = 0
    @Published var totalSteps: Int = 0
    @Published var totalDistance: Double = 0
    @Published var healthKitAuthorized: Bool = false
    @Published var authorizationDenied: Bool = false

    // MARK: - Private State
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var displayTimer: DispatchSourceTimer?
    private var workoutStartTime: Date?
    private var currentSegmentStartTime: Date?
    private var segments: [ActivitySegment] = []
    private var sharedDataManager: SharedDataManager?

    // HealthKit live queries
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private var caloriesAnchor: HKQueryAnchor?
    private var heartRateSamples: [Double] = []
    private var maxHeartRateValue: Double = 0
    private var totalCaloriesAccumulated: Double = 0

    // CoreMotion
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    // Debounce: pending activity must persist for this duration before committing
    private let activityDebounceInterval: TimeInterval = 5.0
    private var pendingActivity: DetectedActivity?
    private var pendingActivityStartTime: Date?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWorkoutManager")

    // MARK: - Init

    override init() {
        super.init()
        logger.info("WatchWorkoutManager initialized")
    }

    func setSharedDataManager(_ dataManager: SharedDataManager) {
        self.sharedDataManager = dataManager
        logger.info("SharedDataManager dependency set")
    }

    // MARK: - HealthKit Permissions

    func requestHealthKitPermissionsIfNeeded() {
        requestHealthPermissions()
    }

    private func requestHealthPermissions() {
        var readTypes = Set<HKQuantityType>()
        var writeTypes = Set<HKSampleType>()

        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        }
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergyType)
            writeTypes.insert(activeEnergyType)
        }
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distanceType)
            writeTypes.insert(distanceType)
        }
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
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
                    self.logger.warning("HealthKit authorization denied")
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

    // MARK: - Workout Lifecycle

    func startWorkout() {
        guard !isWorkoutActive else {
            logger.warning("Workout already active")
            return
        }

        logger.info("Starting free-form workout")
        requestHealthKitPermissionsIfNeeded()

        let now = Date()
        workoutStartTime = now
        currentSegmentStartTime = now
        isWorkoutActive = true
        isPaused = false
        elapsedTime = 0
        currentSegmentTime = 0
        heartRate = 0
        calories = 0
        totalSteps = 0
        totalDistance = 0
        segments = []
        currentActivity = .unknown
        pendingActivity = nil
        pendingActivityStartTime = nil
        heartRateSamples = []
        maxHeartRateValue = 0
        totalCaloriesAccumulated = 0
        heartRateAnchor = nil
        caloriesAnchor = nil

        // Start first segment as unknown
        segments.append(ActivitySegment(activityType: .unknown, startDate: now))

        startWorkoutSession()
        startDisplayTimer()
        startMotionUpdates()
        startPedometerUpdates()
        startHeartRateQuery()
        startCaloriesQuery()

        logger.info("Workout started")
    }

    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }
        isPaused = true

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        stopHeartRateQuery()
        stopCaloriesQuery()

        workoutSession?.pause()
        saveWorkoutDataToLocalStorage()
        logger.info("Workout paused")
    }

    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }
        isPaused = false

        // Close the current segment and start a new one
        closeCurrentSegment()
        let now = Date()
        currentSegmentStartTime = now
        segments.append(ActivitySegment(activityType: currentActivity, startDate: now))

        workoutSession?.resume()
        startDisplayTimer()
        startMotionUpdates()
        startPedometerUpdates()
        startHeartRateQuery()
        startCaloriesQuery()
        logger.info("Workout resumed")
    }

    func stopWorkout() {
        guard isWorkoutActive else { return }

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        stopHeartRateQuery()
        stopCaloriesQuery()

        workoutSession?.end()
        workoutSession = nil

        // Close final segment
        closeCurrentSegment()

        // Build and send session
        if let startTime = workoutStartTime {
            let now = Date()
            let session = TrainingSession(
                startDate: startTime,
                endDate: now,
                duration: now.timeIntervalSince(startTime),
                averageHeartRate: heartRateSamples.isEmpty ? nil : heartRateSamples.reduce(0, +) / Double(heartRateSamples.count),
                maxHeartRate: maxHeartRateValue > 0 ? maxHeartRateValue : nil,
                caloriesBurned: totalCaloriesAccumulated > 0 ? totalCaloriesAccumulated : nil,
                distance: totalDistance > 0 ? totalDistance : nil,
                totalSteps: totalSteps > 0 ? totalSteps : nil,
                segments: segments
            )

            sharedDataManager?.sendSessionToiOS(session)
            logger.info("Session sent to iOS: Duration \(Int(session.duration))s, \(self.segments.count) segments")
        }

        // Reset state
        isWorkoutActive = false
        isPaused = false
        currentActivity = .unknown
        elapsedTime = 0
        currentSegmentTime = 0
        heartRate = 0
        calories = 0
        totalSteps = 0
        totalDistance = 0
        segments = []
        workoutStartTime = nil
        currentSegmentStartTime = nil
        pendingActivity = nil
        pendingActivityStartTime = nil
        heartRateSamples = []
        maxHeartRateValue = 0
        totalCaloriesAccumulated = 0
        heartRateAnchor = nil
        caloriesAnchor = nil

        clearWorkoutBackup()
    }

    // MARK: - HKWorkoutSession

    private func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available")
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
            logger.info("HKWorkoutSession started")
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Display Timer (counts UP)

    private func startDisplayTimer() {
        stopDisplayTimer()

        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        newTimer.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))

        newTimer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateElapsedTime()
            }
        }

        displayTimer = newTimer
        newTimer.resume()
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    private func updateElapsedTime() {
        guard let startTime = workoutStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)

        guard let segStart = currentSegmentStartTime else { return }
        currentSegmentTime = Date().timeIntervalSince(segStart)

        // Check debounce for pending activity transitions
        checkPendingActivityTransition()
    }

    // MARK: - CoreMotion Activity Detection

    private func startMotionUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            logger.warning("Motion activity not available (simulator?)")
            return
        }

        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            Task { @MainActor [weak self] in
                guard let self = self, let activity = activity else { return }
                self.handleMotionActivity(activity)
            }
        }
    }

    private func stopMotionUpdates() {
        motionActivityManager.stopActivityUpdates()
    }

    private func handleMotionActivity(_ activity: CMMotionActivity) {
        let detected: DetectedActivity
        if activity.running {
            detected = .running
        } else if activity.walking {
            detected = .walking
        } else if activity.stationary {
            detected = .stationary
        } else {
            detected = .unknown
        }

        // Only start debounce if activity actually changed
        if detected != currentActivity {
            if detected != pendingActivity {
                // New pending activity
                pendingActivity = detected
                pendingActivityStartTime = Date()
            }
            // Otherwise the same pending activity continues accumulating time
        } else {
            // Activity matches current - clear any pending transition
            pendingActivity = nil
            pendingActivityStartTime = nil
        }
    }

    private func checkPendingActivityTransition() {
        guard let pending = pendingActivity,
              let startTime = pendingActivityStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= activityDebounceInterval {
            commitActivityTransition(to: pending)
            pendingActivity = nil
            pendingActivityStartTime = nil
        }
    }

    private func commitActivityTransition(to newActivity: DetectedActivity) {
        let now = Date()

        // Close current segment
        closeCurrentSegment()

        // Start new segment
        currentActivity = newActivity
        currentSegmentStartTime = now
        currentSegmentTime = 0
        segments.append(ActivitySegment(activityType: newActivity, startDate: now))

        logger.info("Activity changed to \(newActivity.rawValue)")
    }

    private func closeCurrentSegment() {
        let now = Date()
        guard !segments.isEmpty else { return }
        segments[segments.count - 1].endDate = now
    }

    // MARK: - Pedometer

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            logger.warning("Pedometer not available")
            return
        }

        guard let start = workoutStartTime else { return }

        pedometer.startUpdates(from: start) { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self = self, let data = data else { return }
                self.totalSteps = data.numberOfSteps.intValue
                if let dist = data.distance {
                    self.totalDistance = dist.doubleValue / 1000.0 // meters to km
                }
            }
        }
    }

    private func stopPedometerUpdates() {
        pedometer.stopUpdates()
    }

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let startDate = workoutStartTime else { return }

        stopHeartRateQuery()

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: heartRateAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor in
                    self?.logger.error("Heart rate query error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor in
                self?.heartRateAnchor = newAnchor
            }
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor in
                    self?.logger.error("Heart rate update error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor in
                self?.heartRateAnchor = newAnchor
            }
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
        logger.info("Heart rate query started")
    }

    nonisolated private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let bpmValues = quantitySamples.map { $0.quantity.doubleValue(for: bpmUnit) }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.heartRateSamples.append(contentsOf: bpmValues)
            if let latestBPM = bpmValues.last {
                self.heartRate = Int(latestBPM)
            }
            if let maxBPM = bpmValues.max(), maxBPM > self.maxHeartRateValue {
                self.maxHeartRateValue = maxBPM
            }
        }
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    // MARK: - Calories Query

    private func startCaloriesQuery() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let startDate = workoutStartTime else { return }

        stopCaloriesQuery()

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: caloriesType,
            predicate: predicate,
            anchor: caloriesAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor in
                    self?.logger.error("Calories query error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor in
                self?.caloriesAnchor = newAnchor
            }
            self?.processCaloriesSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, newAnchor, error in
            if let error = error {
                Task { @MainActor in
                    self?.logger.error("Calories update error: \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor in
                self?.caloriesAnchor = newAnchor
            }
            self?.processCaloriesSamples(samples)
        }

        caloriesQuery = query
        healthStore.execute(query)
        logger.info("Calories query started")
    }

    nonisolated private func processCaloriesSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        let kcalUnit = HKUnit.kilocalorie()
        let kcalValues = quantitySamples.map { $0.quantity.doubleValue(for: kcalUnit) }
        let batchTotal = kcalValues.reduce(0, +)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.totalCaloriesAccumulated += batchTotal
            self.calories = Int(self.totalCaloriesAccumulated)
        }
    }

    private func stopCaloriesQuery() {
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
    }

    // MARK: - Persistence

    private func saveWorkoutDataToLocalStorage() {
        guard let startTime = workoutStartTime else { return }

        var segmentsCopy = segments
        if !segmentsCopy.isEmpty {
            segmentsCopy[segmentsCopy.count - 1].endDate = Date()
        }

        let session = TrainingSession(
            startDate: startTime,
            endDate: Date(),
            duration: Date().timeIntervalSince(startTime),
            averageHeartRate: heartRateSamples.isEmpty ? nil : heartRateSamples.reduce(0, +) / Double(heartRateSamples.count),
            maxHeartRate: maxHeartRateValue > 0 ? maxHeartRateValue : nil,
            caloriesBurned: totalCaloriesAccumulated > 0 ? totalCaloriesAccumulated : nil,
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: segmentsCopy
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
            logger.info("Workout data backed up")
        } catch {
            logger.error("Failed to backup workout data: \(error.localizedDescription)")
        }
    }

    private func clearWorkoutBackup() {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let backupURL = docsURL.appendingPathComponent("active_workout_backup.json")
        try? fileManager.removeItem(at: backupURL)
    }

    func saveWorkoutData() {
        guard let startTime = workoutStartTime else { return }

        var segmentsCopy = segments
        if !segmentsCopy.isEmpty {
            segmentsCopy[segmentsCopy.count - 1].endDate = Date()
        }

        let session = TrainingSession(
            startDate: startTime,
            endDate: Date(),
            duration: Date().timeIntervalSince(startTime),
            averageHeartRate: heartRateSamples.isEmpty ? nil : heartRateSamples.reduce(0, +) / Double(heartRateSamples.count),
            maxHeartRate: maxHeartRateValue > 0 ? maxHeartRateValue : nil,
            caloriesBurned: totalCaloriesAccumulated > 0 ? totalCaloriesAccumulated : nil,
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: segmentsCopy
        )

        sharedDataManager?.sendSessionToiOS(session)
        saveWorkoutDataToLocalStorage()
        logger.info("Session saved: Duration \(Int(session.duration))s")
    }
}

// MARK: - HKWorkoutSessionDelegate
#if os(watchOS)
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            logger.info("Workout session state: \(fromState.rawValue) -> \(toState.rawValue)")

            switch toState {
            case .paused:
                saveWorkoutDataToLocalStorage()
            case .ended, .stopped:
                clearWorkoutBackup()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Workout session failed: \(error.localizedDescription)")
            saveWorkoutDataToLocalStorage()
        }
    }
}
#endif
