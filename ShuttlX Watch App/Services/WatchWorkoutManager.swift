import Foundation
import HealthKit
import CoreMotion
import CoreLocation
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif
import os.log

struct KmSplit: Identifiable {
    let id = UUID()
    let kmNumber: Int
    let splitTime: TimeInterval
    let cumulativeTime: TimeInterval
}

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
    @Published var currentPace: TimeInterval? = nil   // seconds per km (average)
    @Published var completedKmSplits: [KmSplit] = []
    @Published var lastCompletedKm: Int = 0
    @Published var healthKitAuthorized: Bool = false
    @Published var authorizationDenied: Bool = false
    @Published var healthKitSaveError: String? = nil
    /// True while a workout start is in progress (auth + session setup). Used for immediate UI feedback.
    @Published var isStarting: Bool = false

    /// True average heart rate across all collected samples (excludes paused periods)
    var averageHeartRate: Int {
        guard heartRateSampleCount > 0 else { return 0 }
        return Int((heartRateSampleSum / Double(heartRateSampleCount)).rounded())
    }

    // MARK: - Interval Mode
    enum WorkoutMode { case freeRun, interval }
    @Published var workoutMode: WorkoutMode = .freeRun
    @Published var workoutName: String = "Free Run"
    var intervalEngine: IntervalEngine?
    private var activeTemplate: WorkoutTemplate?

    // MARK: - Private State
    private var workoutSession: HKWorkoutSession?
    #if os(watchOS)
    private var workoutBuilder: HKLiveWorkoutBuilder?
    #endif
    private var healthStore = HKHealthStore()
    private var displayTimer: DispatchSourceTimer?
    private var workoutStartTime: Date?
    private var currentSegmentStartTime: Date?
    private var segments: [ActivitySegment] = []
    private var sharedDataManager: SharedDataManager?

    // HealthKit builder-driven metrics (fed by HKLiveWorkoutBuilderDelegate)
    private var heartRateSampleSum: Double = 0
    private var heartRateSampleCount: Int = 0
    private var maxHeartRateValue: Double = 0
    private var totalCaloriesAccumulated: Double = 0

    // Display-only HR fallback: on some watch models the builder delegate may not
    // deliver `.heartRate` in `collectedTypes`. An anchored query runs in parallel
    // and updates only the live `heartRate` display. It intentionally does NOT
    // touch the sum/count/max — those remain authoritative from the builder's
    // pause-aware statistics, so no double-counting on resume.
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?

    // Pace & split tracking
    private var timeAtLastKm: TimeInterval = 0

    // Live metrics broadcast
    private var lastLiveUpdateTime: Date?

    // CoreLocation
    private let locationManager = CLLocationManager()
    private var routePoints: [RoutePoint] = []
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let maxRoutePoints = 2000

    // CoreMotion
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    // Pause time tracking
    private var accumulatedPauseTime: TimeInterval = 0
    private var pauseStartDate: Date?

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

    /// UserDefaults key (App Group) persisting successful HealthKit authorization
    /// across launches. Bump the suffix if `buildHealthKitTypes()` gains a new
    /// required type so the user is re-prompted.
    private static let authCacheKey = "hk_authorized_v1"
    private var authDefaults: UserDefaults {
        UserDefaults(suiteName: "group.com.shuttlx.shared") ?? .standard
    }

    /// Fire-and-forget pre-warm: called from onAppear to prompt the user early.
    /// Does NOT await result — use requestHealthAuthorizationAsync() when a result is needed.
    func requestHealthKitPermissionsIfNeeded() {
        guard !healthKitAuthorized else { return }
        if authDefaults.bool(forKey: Self.authCacheKey) {
            // Previously granted — assume still granted. If a live HealthKit call
            // later fails with an authorization error, we'll clear the flag and
            // re-prompt on the next Start.
            healthKitAuthorized = true
            return
        }
        Task { [weak self] in
            await self?.requestHealthAuthorizationAsync()
        }
    }

    /// Async, awaitable authorization request.
    /// Returns `true` if all critical types are authorized, `false` otherwise.
    /// Short-circuits on the cached flag so the second-and-later workout starts
    /// skip the 500ms–3s HealthKit XPC round-trip entirely.
    @discardableResult
    private func requestHealthAuthorizationAsync() async -> Bool {
        if healthKitAuthorized || authDefaults.bool(forKey: Self.authCacheKey) {
            healthKitAuthorized = true
            authorizationDenied = false
            return true
        }

        let (readTypes, writeTypes) = buildHealthKitTypes()

        // Include date of birth for age-based HR zone calculation (Tanaka formula)
        var allReadTypes: Set<HKObjectType> = Set(readTypes)
        if let dobType = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            allReadTypes.insert(dobType)
        }

        guard !readTypes.isEmpty else {
            logger.error("No valid HealthKit types available for authorization")
            healthKitAuthorized = false
            authorizationDenied = true
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: allReadTypes)
            logger.info("HealthKit authorization granted")
            healthKitAuthorized = true
            authorizationDenied = false
            authDefaults.set(true, forKey: Self.authCacheKey)
            updateMaxHRFromHealthKit()
            return true
        } catch {
            logger.error("HealthKit authorization error: \(error.localizedDescription)")
            healthKitAuthorized = false
            authorizationDenied = true
            authDefaults.set(false, forKey: Self.authCacheKey)
            return false
        }
    }

    private func buildHealthKitTypes() -> (read: Set<HKQuantityType>, write: Set<HKSampleType>) {
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
        return (readTypes, writeTypes)
    }

    /// Reads date of birth from HealthKit and persists the Tanaka-derived max HR
    /// to the App Group UserDefaults. A manual override stored there is not clobbered —
    /// the UI max HR field takes precedence over the formula.
    private func updateMaxHRFromHealthKit() {
        // Only update from HealthKit when no manual override exists
        guard HeartRateZoneCalculator.loadSavedMaxHR() == nil else {
            logger.info("Manual max HR override present — skipping HealthKit age lookup")
            return
        }

        do {
            let components = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let now = calendar.dateComponents([.year], from: Date())
            guard let birthYear = components.year, let currentYear = now.year else { return }
            let age = currentYear - birthYear
            guard age > 0, age < 120 else { return }

            let calculator = HeartRateZoneCalculator(age: age, manualMaxHR: nil)
            HeartRateZoneCalculator.saveMaxHR(calculator.estimatedMaxHR)
            logger.info("Max HR updated from HealthKit age \(age): \(calculator.estimatedMaxHR) BPM")
        } catch {
            logger.info("Date of birth not available in HealthKit: \(error.localizedDescription)")
        }
    }

    // MARK: - Workout Lifecycle

    /// Starts a free-run workout. Authorization is awaited before any HealthKit session
    /// or queries begin. If the user has denied access the workout is aborted and
    /// `authorizationDenied` is set to `true` so the UI can show an error.
    func startWorkout() {
        guard !isWorkoutActive, !isStarting else {
            logger.warning("Workout already active or starting")
            return
        }

        // Set isStarting immediately so the UI shows a spinner on the very next frame —
        // before any async work begins.
        isStarting = true

        // Name must be set before the async task so the UI reflects the correct
        // workout name if it reads the property during the auth wait.
        if workoutMode != .interval {
            workoutName = "Free Run"
        }

        Task { [weak self] in
            guard let self = self else { return }
            await self.startWorkoutAfterAuth()
            self.isStarting = false
        }
    }

    /// Async core of workout startup — awaits HealthKit authorization, then
    /// initialises state and starts all sensors/queries.
    private func startWorkoutAfterAuth() async {
        // Abort if another workout snuck in while we were waiting.
        guard !isWorkoutActive else {
            logger.warning("Workout became active while awaiting authorization")
            return
        }

        let authorized = await requestHealthAuthorizationAsync()
        guard authorized else {
            logger.warning("Workout start aborted — HealthKit not authorized")
            // authorizationDenied is already set by requestHealthAuthorizationAsync
            return
        }

        // --- Phase 1: Flip UI state FIRST so ContentView can transition to
        // TrainingView and render the "Starting…" overlay in the next frame.
        // Everything here is pure @Published property writes — nanoseconds.
        let now = Date()
        workoutStartTime = now
        currentSegmentStartTime = now
        isPaused = false
        elapsedTime = 0
        currentSegmentTime = 0
        heartRate = 0
        calories = 0
        totalSteps = 0
        totalDistance = 0
        currentPace = nil
        completedKmSplits = []
        lastCompletedKm = 0
        timeAtLastKm = 0
        segments = []
        currentActivity = .unknown
        pendingActivity = nil
        pendingActivityStartTime = nil
        heartRateSampleSum = 0
        heartRateSampleCount = 0
        maxHeartRateValue = 0
        totalCaloriesAccumulated = 0
        heartRateAnchor = nil
        accumulatedPauseTime = 0
        pauseStartDate = nil
        routePoints = []
        segments.append(ActivitySegment(activityType: .unknown, startDate: now))

        isWorkoutActive = true

        // Give SwiftUI one guaranteed render frame before we start synchronous
        // HealthKit / CoreMotion / CoreLocation setup. Without this yield the
        // MainActor is held continuously through sensor startup (~300–1500ms)
        // and the user perceives a freeze.
        await Task.yield()

        // --- Phase 2: Sensor setup. Each call can briefly block MainActor;
        // a Task.yield() between them gives SwiftUI a render window so the
        // timer can start ticking and the "Starting…" overlay can animate out.
        startWorkoutSession()
        await Task.yield()
        startDisplayTimer()

        let sport = activeTemplate?.sportType ?? .running
        if sport.supportsAutoDetection {
            startMotionUpdates()
            await Task.yield()
            startPedometerUpdates()
            await Task.yield()
        }
        // Heart rate and calories flow from HKLiveWorkoutBuilderDelegate. A
        // display-only anchored HR query runs alongside as a fallback for
        // watch models/OS versions where the builder delegate is flaky.
        startHeartRateQuery()
        await Task.yield()
        requestLocationAndStartUpdates()

        logger.info("Workout started (sport: \(sport.displayName))")

        // Notify iPhone that workout started — transferUserInfo wakes iOS in background.
        // Dispatched to a utility queue so the brief WC call cannot block MainActor.
        if WCSession.default.activationState == .activated {
            let startPayload: [String: Any] = [
                "action": "workoutStarted",
                "activityType": sport.rawValue,
                "startTime": Date().timeIntervalSince1970
            ]
            DispatchQueue.global(qos: .utility).async {
                WCSession.default.transferUserInfo(startPayload)
            }
        }
    }

    func startIntervalWorkout(template: WorkoutTemplate) {
        guard !isWorkoutActive, !isStarting else {
            logger.warning("Workout already active or starting")
            return
        }
        logger.info("Starting interval workout: \(template.name)")
        workoutMode = .interval
        workoutName = template.name
        activeTemplate = template
        intervalEngine = IntervalEngine()
        intervalEngine?.configure(template: template)
        startWorkout()
    }

    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }
        isPaused = true
        pauseStartDate = Date()

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        stopLocationUpdates()

        workoutSession?.pause()
        saveWorkoutDataToLocalStorage()
        logger.info("Workout paused")
    }

    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }
        isPaused = false

        // Accumulate pause duration
        if let pauseStart = pauseStartDate {
            accumulatedPauseTime += Date().timeIntervalSince(pauseStart)
            pauseStartDate = nil
        }

        // Close the current segment and start a new one
        closeCurrentSegment()
        let now = Date()
        currentSegmentStartTime = now
        segments.append(ActivitySegment(activityType: currentActivity, startDate: now))

        workoutSession?.resume()
        startDisplayTimer()
        let sport = activeTemplate?.sportType ?? .running
        if sport.supportsAutoDetection {
            startMotionUpdates()
            startPedometerUpdates()
        }
        startLocationUpdates()
        logger.info("Workout resumed")
    }

    func stopWorkout() {
        guard isWorkoutActive else { return }

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        stopHeartRateQuery()
        stopLocationUpdates()

        workoutSession?.end()
        workoutSession = nil
        #if os(watchOS)
        workoutBuilder = nil
        #endif

        // Close final segment
        closeCurrentSegment()

        // Note: session is sent to iOS by saveWorkoutData() which is called before stopWorkout()
        // stopWorkout() only cleans up state — no duplicate send

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
        currentPace = nil
        completedKmSplits = []
        lastCompletedKm = 0
        timeAtLastKm = 0
        segments = []
        workoutStartTime = nil
        currentSegmentStartTime = nil
        pendingActivity = nil
        pendingActivityStartTime = nil
        heartRateSampleSum = 0
        heartRateSampleCount = 0
        maxHeartRateValue = 0
        totalCaloriesAccumulated = 0
        heartRateAnchor = nil
        lastLiveUpdateTime = nil
        routePoints = []
        accumulatedPauseTime = 0
        pauseStartDate = nil

        // Notify iOS that workout ended (immediate + guaranteed)
        let stopPayload: [String: Any] = ["action": "workoutStopped", "timestamp": Date().timeIntervalSince1970]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(stopPayload, replyHandler: nil, errorHandler: nil)
        }
        WCSession.default.transferUserInfo(stopPayload)

        // Reset interval mode
        workoutMode = .freeRun
        intervalEngine = nil
        activeTemplate = nil

        // Backup is cleared by saveWorkoutData() after confirmed save — not here
    }

    // MARK: - HKWorkoutSession

    private func startWorkoutSession() {
        guard healthKitAuthorized else {
            logger.warning("startWorkoutSession skipped — HealthKit not authorized")
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available")
            return
        }

        #if os(watchOS)
        let configuration = HKWorkoutConfiguration()
        let sport = activeTemplate?.sportType ?? .running
        configuration.activityType = sport.hkActivityType
        configuration.locationType = sport.hkLocationType

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession = session
            workoutSession?.delegate = self
            let builder = session.associatedWorkoutBuilder()
            workoutBuilder = builder
            builder.delegate = self
            let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            // Explicitly enable HR and active-energy collection. `HKLiveWorkoutDataSource`'s
            // implicit "default types" list is watchOS/model-dependent — without these calls,
            // `workoutBuilder(_:didCollectDataOf:)` may never fire for HR, which is the
            // regression the previous fix ran into.
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                dataSource.enableCollection(for: hrType, predicate: nil)
            }
            if let kcalType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                dataSource.enableCollection(for: kcalType, predicate: nil)
            }
            builder.dataSource = dataSource
            workoutSession?.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak self] success, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let error = error {
                        self.logger.error("Failed to begin workout builder collection: \(error.localizedDescription)")
                    } else {
                        self.logger.info("HKLiveWorkoutBuilder collection started")
                    }
                }
            }
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            logger.info("HKWorkoutSession started (sport: \(sport.displayName))")
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Display Timer (counts UP)

    private func startDisplayTimer() {
        stopDisplayTimer()

        // Use a background queue for the timer source so the 1-second tick does not
        // compete with SwiftUI rendering on the main queue. State updates inside
        // updateElapsedTime() hop back to @MainActor via the class isolation.
        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
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
        elapsedTime = Date().timeIntervalSince(startTime) - accumulatedPauseTime

        guard let segStart = currentSegmentStartTime else { return }
        currentSegmentTime = Date().timeIntervalSince(segStart)

        // Check debounce for pending activity transitions
        checkPendingActivityTransition()

        // Tick interval engine if in interval mode
        if workoutMode == .interval, let engine = intervalEngine {
            engine.tick(heartRate: heartRate, distance: totalDistance)
            if engine.isComplete {
                saveWorkoutData()
                stopWorkout()
                return
            }
        }

        // Broadcast live metrics to iOS every 3 seconds
        broadcastLiveMetricsIfNeeded()
    }

    // MARK: - Live Metrics Broadcast

    private func broadcastLiveMetricsIfNeeded() {
        let now = Date()
        if let lastUpdate = lastLiveUpdateTime, now.timeIntervalSince(lastUpdate) < 3.0 {
            return
        }
        lastLiveUpdateTime = now

        // Snapshot state on MainActor before dispatching — the sendMessage call itself
        // can briefly block the caller, so we run it on a background queue to keep the
        // MainActor free for SwiftUI rendering and timer ticks.
        var payload: [String: Any] = [
            "action": "liveMetrics",
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "distance": totalDistance,
            "calories": calories,
            "steps": totalSteps,
            "currentActivity": currentActivity.rawValue,
            "isPaused": isPaused,
            "pace": currentPace ?? 0,
            "timestamp": now.timeIntervalSince1970
        ]
        if let startTime = workoutStartTime {
            payload["startTime"] = startTime.timeIntervalSince1970
        }
        if let lastPoint = routePoints.last {
            payload["latitude"] = lastPoint.latitude
            payload["longitude"] = lastPoint.longitude
        }

        let frozenPayload = payload
        DispatchQueue.global(qos: .utility).async {
            guard WCSession.default.activationState == .activated,
                  WCSession.default.isReachable else { return }
            WCSession.default.sendMessage(frozenPayload, replyHandler: nil, errorHandler: nil)
        }
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

        // Haptic feedback on activity change
        #if os(watchOS)
        WKInterfaceDevice.current().play(.start)
        #endif

        logger.info("Activity changed to \(newActivity.rawValue)")
    }

    private func closeCurrentSegment() {
        let now = Date()
        guard !segments.isEmpty else { return }
        segments[segments.count - 1].endDate = now
    }

    // MARK: - Location Tracking

    private func requestLocationAndStartUpdates() {
        locationManager.delegate = self
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            startLocationUpdates()
        } else {
            logger.warning("Location permission denied — route will not be recorded")
        }
    }

    private func startLocationUpdates() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        locationManager.activityType = .fitness
        locationManager.startUpdatingLocation()
        logger.info("Location updates started")
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        logger.info("Location updates stopped")
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
                    let distanceKm = dist.doubleValue / 1000.0
                    self.totalDistance = distanceKm
                    self.updatePaceAndSplits(distanceKm: distanceKm)
                }
            }
        }
    }

    private func updatePaceAndSplits(distanceKm: Double) {
        guard distanceKm >= 0.01 else {
            currentPace = nil
            return
        }

        // Average pace: seconds per km
        currentPace = elapsedTime / distanceKm

        // Km split detection
        let completedKm = Int(floor(distanceKm))
        while completedKm > lastCompletedKm {
            lastCompletedKm += 1
            let splitTime = elapsedTime - timeAtLastKm
            let split = KmSplit(
                kmNumber: lastCompletedKm,
                splitTime: splitTime,
                cumulativeTime: elapsedTime
            )
            completedKmSplits.append(split)
            timeAtLastKm = elapsedTime

            // Haptic feedback at each km milestone
            #if os(watchOS)
            WKInterfaceDevice.current().play(.notification)
            #endif
            logger.info("Km split \(self.lastCompletedKm): \(Int(splitTime))s")
        }
    }

    private func stopPedometerUpdates() {
        pedometer.stopUpdates()
    }

    // MARK: - Builder-Driven Metric Collection
    //
    // Heart rate and active calories are read from `HKLiveWorkoutBuilder`'s aggregated
    // statistics via the delegate callback below. The builder is already tied to the
    // workout session, so samples are automatically gated by pause/resume state and
    // we avoid the HKAnchoredObjectQuery replay race that previously dropped the first
    // few seconds of samples and double-counted on resume.

    #if os(watchOS)
    nonisolated fileprivate func updateMetrics(from builder: HKLiveWorkoutBuilder,
                                               changedTypes collected: Set<HKSampleType>) {
        guard let quantityTypes = collected as? Set<HKQuantityType> else { return }

        struct Snapshot {
            var latestHR: Double?
            var avgHR: Double?
            var maxHR: Double?
            var totalCalories: Double?
        }
        var snapshot = Snapshot()

        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           quantityTypes.contains(hrType),
           let stats = builder.statistics(for: hrType) {
            let unit = HKUnit.count().unitDivided(by: .minute())
            snapshot.latestHR = stats.mostRecentQuantity()?.doubleValue(for: unit)
            snapshot.avgHR = stats.averageQuantity()?.doubleValue(for: unit)
            snapshot.maxHR = stats.maximumQuantity()?.doubleValue(for: unit)
        }

        if let kcalType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           quantityTypes.contains(kcalType),
           let stats = builder.statistics(for: kcalType),
           let total = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            snapshot.totalCalories = total
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let bpm = snapshot.latestHR {
                // No-op guard: avoid publishing identical values, which would
                // trigger SwiftUI invalidations and cause perceptible jitter
                // when both this delegate and the anchored fallback query
                // write the same BPM in quick succession.
                let newHR = Int(bpm.rounded())
                if self.heartRate != newHR {
                    self.heartRate = newHR
                }
            }
            if let maxBPM = snapshot.maxHR, maxBPM > self.maxHeartRateValue {
                self.maxHeartRateValue = maxBPM
            }
            // `averageHeartRate` computed property expects sum/count. Store the
            // builder's authoritative pause-aware average by setting sum=avg*1.
            if let avgBPM = snapshot.avgHR, avgBPM > 0 {
                self.heartRateSampleSum = avgBPM
                self.heartRateSampleCount = 1
            }
            if let total = snapshot.totalCalories {
                self.totalCaloriesAccumulated = total
                self.calories = Int(total)
            }
        }
    }
    #endif

    // MARK: - Heart Rate Fallback Query (display-only)

    /// Runs an `HKAnchoredObjectQuery` alongside the builder delegate to guarantee
    /// the live BPM display is populated even when `HKLiveWorkoutDataSource`
    /// doesn't emit `.heartRate` in its collected-types set (observed on some
    /// watch models/OS versions). Samples here ONLY update `self.heartRate`
    /// for the UI — they do not feed the sum/count/max, which remain owned by
    /// the builder's authoritative `statistics(for:)`.
    private func startHeartRateQuery() {
        guard healthKitAuthorized else { return }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let startDate = workoutStartTime else { return }

        stopHeartRateQuery()

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: heartRateAnchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.handleHeartRateSamples(samples, newAnchor: newAnchor)
        }
        query.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.handleHeartRateSamples(samples, newAnchor: newAnchor)
        }
        heartRateQuery = query
        healthStore.execute(query)
        logger.info("HR fallback query started")
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    nonisolated private func handleHeartRateSamples(_ samples: [HKSample]?, newAnchor: HKQueryAnchor?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let latest = quantitySamples.last?.quantity.doubleValue(for: unit)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.heartRateAnchor = newAnchor
            if let bpm = latest {
                // No-op guard: same reasoning as updateMetrics — both writers
                // converge on the same value; publishing duplicates causes
                // unnecessary SwiftUI invalidations and visible flicker.
                let newHR = Int(bpm.rounded())
                if self.heartRate != newHR {
                    self.heartRate = newHR
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveWorkoutDataToLocalStorage() {
        guard let startTime = workoutStartTime else { return }

        var segmentsCopy = segments
        if !segmentsCopy.isEmpty {
            segmentsCopy[segmentsCopy.count - 1].endDate = Date()
        }

        let backupSplits: [KmSplitData]? = completedKmSplits.isEmpty ? nil : completedKmSplits.map {
            KmSplitData(kmNumber: $0.kmNumber, splitTime: $0.splitTime, cumulativeTime: $0.cumulativeTime)
        }

        // Calculate total pause time including current pause if active
        let totalPause = accumulatedPauseTime + (pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)

        let session = TrainingSession(
            startDate: startTime,
            endDate: Date(),
            duration: Date().timeIntervalSince(startTime) - totalPause,
            averageHeartRate: heartRateSampleCount > 0 ? heartRateSampleSum / Double(heartRateSampleCount) : nil,
            maxHeartRate: maxHeartRateValue > 0 ? maxHeartRateValue : nil,
            caloriesBurned: totalCaloriesAccumulated > 0 ? totalCaloriesAccumulated : nil,
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: segmentsCopy,
            route: routePoints.isEmpty ? nil : routePoints,
            kmSplits: backupSplits
        )

        do {
            let data = try JSONEncoder().encode(session)
            guard let backupURL = workoutBackupURL() else {
                logger.error("Could not resolve backup URL for workout backup")
                return
            }
            try data.write(to: backupURL, options: [.atomic, .completeFileProtection])
            logger.info("Workout data backed up")
        } catch {
            logger.error("Failed to backup workout data: \(error.localizedDescription)")
        }
    }

    /// Check for a crashed workout backup and recover the session
    func recoverCrashedWorkout() -> TrainingSession? {
        guard let backupURL = workoutBackupURL() else { return nil }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: backupURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: backupURL)
            let session = try JSONDecoder().decode(TrainingSession.self, from: data)
            logger.info("Recovered crashed workout backup: \(Int(session.duration))s")
            return session
        } catch {
            logger.error("Failed to read workout backup: \(error.localizedDescription)")
            try? fileManager.removeItem(at: backupURL)
            return nil
        }
    }

    /// Save a recovered session if not already saved, and clear the backup
    func saveRecoveredSession(_ session: TrainingSession) {
        // Prevent duplicate: check if this session ID already exists in stored sessions
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            let url = containerURL.appendingPathComponent("sessions.json")
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let existing = try? JSONDecoder().decode([TrainingSession].self, from: data),
               existing.contains(where: { $0.id == session.id }) {
                logger.info("Recovered session \(session.id) already exists — skipping duplicate save")
                clearWorkoutBackup()
                return
            }
        }
        sharedDataManager?.sendSessionToiOS(session)
        clearWorkoutBackup()
        logger.info("Recovered session sent to iOS and backup cleared")
    }

    private func clearWorkoutBackup() {
        guard let backupURL = workoutBackupURL() else { return }
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Returns backup URL in App Group container (preferred) or Documents dir (fallback)
    private func workoutBackupURL() -> URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
            return container.appendingPathComponent("active_workout_backup.json")
        }
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docsURL.appendingPathComponent("active_workout_backup.json")
    }

    func saveWorkoutData() {
        guard let startTime = workoutStartTime else { return }

        var segmentsCopy = segments
        if !segmentsCopy.isEmpty {
            segmentsCopy[segmentsCopy.count - 1].endDate = Date()
        }

        let splits: [KmSplitData]? = completedKmSplits.isEmpty ? nil : completedKmSplits.map {
            KmSplitData(kmNumber: $0.kmNumber, splitTime: $0.splitTime, cumulativeTime: $0.cumulativeTime)
        }

        // Calculate total pause time including current pause if active
        let totalPauseTime = accumulatedPauseTime + (pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)

        var session = TrainingSession(
            startDate: startTime,
            endDate: Date(),
            duration: Date().timeIntervalSince(startTime) - totalPauseTime,
            averageHeartRate: heartRateSampleCount > 0 ? heartRateSampleSum / Double(heartRateSampleCount) : nil,
            maxHeartRate: maxHeartRateValue > 0 ? maxHeartRateValue : nil,
            caloriesBurned: totalCaloriesAccumulated > 0 ? totalCaloriesAccumulated : nil,
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: segmentsCopy,
            route: routePoints.isEmpty ? nil : routePoints,
            kmSplits: splits
        )

        // Attach interval results if this was an interval workout
        if workoutMode == .interval, let engine = intervalEngine {
            let result = engine.stop(finalDistance: totalDistance)
            session.templateID = result.templateID
            session.programName = result.templateName
            session.completedIntervalResults = result.results
        }

        // Set sport type from template
        session.sportType = activeTemplate?.sportType

        // Capture mutable copies for use in the async Task below
        let sessionToSend = session
        let routeBuilderToFinish = routeBuilder

        #if os(watchOS)
        let builderToFinish = workoutBuilder
        // Nil out builder/route references before async work so no other call reuses them
        workoutBuilder = nil
        #endif
        routeBuilder = nil

        // Finalize HKLiveWorkoutBuilder → saves HKWorkout to HealthKit, then attach route
        Task {
            #if os(watchOS)
            if let builder = builderToFinish {
                do {
                    let endDate = Date()
                    try await builder.endCollection(at: endDate)
                    let workout = try await builder.finishWorkout()
                    await MainActor.run {
                        self.logger.info("HKWorkout saved to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
                    }
                    // Attach GPS route to the saved HKWorkout
                    if let rb = routeBuilderToFinish {
                        await self.finalizeRouteBuilder(rb, with: workout)
                    }
                } catch {
                    await MainActor.run {
                        self.logger.error("Failed to save HKWorkout: \(error.localizedDescription)")
                        self.healthKitSaveError = error.localizedDescription
                    }
                }
            } else {
                // No builder — best-effort route finalization (won't find a matching workout)
                if let rb = routeBuilderToFinish {
                    await self.finalizeRouteBuilder(rb, with: nil)
                }
                await MainActor.run {
                    self.logger.warning("No HKLiveWorkoutBuilder — workout not saved to HealthKit")
                    self.healthKitSaveError = "Workout builder unavailable — workout may not appear in Health app"
                }
            }
            #else
            if let rb = routeBuilderToFinish {
                await self.finalizeRouteBuilder(rb, with: nil)
            }
            #endif
        }

        sharedDataManager?.sendSessionToiOS(sessionToSend)
        clearWorkoutBackup()
        logger.info("Session saved: Duration \(Int(sessionToSend.duration))s")
    }

    private func finalizeRouteBuilder(_ builder: HKWorkoutRouteBuilder, with workout: HKWorkout?) async {
        guard let workout = workout else {
            logger.warning("No HKWorkout available — GPS route will not be attached to HealthKit")
            return
        }
        do {
            try await builder.finishRoute(with: workout, metadata: nil)
            logger.info("HKWorkoutRoute saved to HealthKit (attached to workout \(workout.uuid))")
        } catch {
            logger.error("Failed to finalize route: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
#if os(watchOS)
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        updateMetrics(from: workoutBuilder, changedTypes: collectedTypes)
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Events (pause/resume markers) are handled via HKWorkoutSessionDelegate;
        // no additional work needed here.
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            logger.info("Workout session state: \(fromState.rawValue) -> \(toState.rawValue)")

            switch toState {
            case .paused:
                saveWorkoutDataToLocalStorage()
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

// MARK: - CLLocationManagerDelegate
extension WatchWorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let filtered = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 50 }
        guard !filtered.isEmpty else { return }

        let points = filtered.map {
            RoutePoint(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                altitude: $0.altitude,
                timestamp: $0.timestamp,
                speed: $0.speed >= 0 ? $0.speed : nil,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Cap in-memory route points for long workouts to avoid exceeding watchOS memory limit.
            // Full-resolution route is preserved in HealthKit via HKWorkoutRouteBuilder.
            if self.routePoints.count >= self.maxRoutePoints {
                var downsampled: [RoutePoint] = []
                let half = self.routePoints.count / 2
                for (index, point) in self.routePoints.enumerated() {
                    if index < half {
                        if index % 2 == 0 { downsampled.append(point) }
                    } else {
                        downsampled.append(point)
                    }
                }
                self.routePoints = downsampled
                self.logger.info("Route points downsampled from \(self.maxRoutePoints) to \(self.routePoints.count)")
            }
            self.routePoints.append(contentsOf: points)

            // Feed HKWorkoutRouteBuilder for official HealthKit route
            self.routeBuilder?.insertRouteData(filtered) { success, error in
                if let error = error {
                    Task { @MainActor in
                        self.logger.debug("RouteBuilder insert error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let status = manager.authorizationStatus
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && self.isWorkoutActive && !self.isPaused {
                self.startLocationUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.logger.error("Location error: \(error.localizedDescription)")
        }
    }
}
