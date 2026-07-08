import Foundation
import HealthKit
import CoreMotion
import CoreLocation
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif
import os.log
import ShuttlXShared

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
    /// True if no HR sample has arrived within `noHRDetectedAfter` seconds of an
    /// active, unpaused workout. HealthKit never tells an app whether READ access
    /// was granted, so this is the only signal we have that HR is silently
    /// missing (denied permission, sensor off-wrist, etc.). Drives a non-blocking
    /// banner in TrainingView. Cleared as soon as the first sample lands.
    @Published private(set) var noHeartRateDetected: Bool = false
    /// True while a workout start is in progress (auth + session setup). Used for immediate UI feedback.
    @Published var isStarting: Bool = false

    /// True average heart rate across all collected samples (excludes paused periods)
    var averageHeartRate: Int {
        guard heartRateSampleCount > 0 else { return 0 }
        return Int((heartRateSampleSum / Double(heartRateSampleCount)).rounded())
    }

    // MARK: - Workout Mode
    enum WorkoutMode { case freeRun, interval, gymRecovery }
    @Published var workoutMode: WorkoutMode = .freeRun
    @Published var workoutName: String = "Free Run"

    // `intervalEngine` is @Published so swapping in a new engine triggers a
    // re-render. For per-tick UI updates, views observe the engine DIRECTLY
    // via @ObservedObject (see IntervalStepWash in TrainingView). We do NOT
    // forward `engine.objectWillChange` through this manager — that doubled
    // the invalidation count per tick (manager + engine both firing) and
    // caused noticeable UI sluggishness during workouts.
    @Published var intervalEngine: IntervalEngine?
    private var activeTemplate: WorkoutTemplate?

    // MARK: - Gym Recovery Mode State
    @Published var recoveryState: SegmentState = .idle
    @Published var restElapsedTime: TimeInterval = 0
    @Published var stationElapsedTime: TimeInterval = 0
    @Published var recoverySetNumber: Int = 0
    @Published var currentCapturePeakHR: Int = 0
    @Published var latestHRR1: Int? = nil
    @Published var latestHRR2: Int? = nil
    @Published var completedCaptures: [HRRCapture] = []
    @Published var currentCadence: Int = 0
    private var recoverySegmenter: RecoverySegmenter?

    var stationCandidateProgress: Double { recoverySegmenter?.candidateProgress ?? 0 }

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
    private var sharedDataManager: WatchSyncCoordinator?

    // HealthKit live queries
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    private var heartRateAnchor: HKQueryAnchor?
    private var caloriesAnchor: HKQueryAnchor?
    // No-HR watchdog: fires once if no sample arrives within the grace period.
    private var noHRTimer: DispatchSourceTimer?
    private var hasReceivedHRSample: Bool = false
    /// Grace period before declaring "no HR". 15s covers the Apple Watch optical
    /// sensor warmup plus the first HKAnchoredObjectQuery delivery.
    private let noHRDetectedAfter: TimeInterval = 15
    // Running accumulators replace the full samples array — O(1) average, not O(n)
    private var heartRateSampleSum: Double = 0
    private var heartRateSampleCount: Int = 0
    private var maxHeartRateValue: Double = 0
    private var totalCaloriesAccumulated: Double = 0
    // Cadence accumulators — paused samples and zero-cadence ticks excluded
    private var cadenceSampleSum: Double = 0
    private var cadenceSampleCount: Int = 0
    private var maxCadenceValue: Int = 0
    // Fallback derivation when CMPedometer.currentCadence is nil (frequent during
    // the first 30-60s of a workout + always nil in the simulator).
    private var lastCadenceStepCount: Int = 0
    private var lastCadenceTimestamp: Date?
    // Rolling pace window — replaces cumulative-average `elapsedTime / distanceKm`
    // which was pinned at ~10:00/km by the pedometer warmup spike (first sample
    // arrived at ~30s elapsed with ~0.05km distance = exactly 600s/km = 10:00).
    private var paceWindowSamples: [(time: TimeInterval, distance: Double)] = []
    private let paceWindowSec: TimeInterval = 30

    // Pace & split tracking
    private var timeAtLastKm: TimeInterval = 0

    // T-METRICS.4: HKLiveWorkoutBuilder's distanceWalkingRunning statistic is
    // Apple's canonical fused distance (pedometer + GPS + on-device motion).
    // We prefer it over CMPedometer.distance when > 0, and fall back to the
    // pedometer reading during the brief warmup before the builder reports.
    var hkDistanceKm: Double = 0

    // Live metrics broadcast
    private var lastLiveUpdateTime: Date?

    let persistence = WorkoutPersistence()

    // Periodic crash-recovery checkpoint (a never-paused workout must still
    // leave a recoverable backup — see docs/plans/2026-07-stability-and-design-plan.md)
    private var lastCheckpointDate: Date?
    private let checkpointInterval: TimeInterval = 15

    // Freeze instrumentation: proves on-device whether ticks stall (main-actor
    // backlog / suspension) or stop entirely (kill) — see freeze root-cause plan.
    private var lastTickDate: Date?
    private var ticksSinceHeartbeat = 0

    // CoreLocation
    private let locationManager = CLLocationManager()
    var routePoints: [RoutePoint] = []
    var routeBuilder: HKWorkoutRouteBuilder?
    let maxRoutePoints = 2000

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

    let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "WatchWorkoutManager")

    // MARK: - Init

    override init() {
        super.init()
        logger.info("WatchWorkoutManager initialized")
    }

    func setSharedDataManager(_ dataManager: WatchSyncCoordinator) {
        self.sharedDataManager = dataManager
        logger.info("WatchSyncCoordinator dependency set")
    }

    // MARK: - HealthKit Permissions

    private lazy var authService = HealthKitAuthService(healthStore: healthStore)

    /// Fire-and-forget pre-warm: called from onAppear to prompt the user early.
    /// Does NOT await result — use requestHealthAuthorizationAsync() when a result is needed.
    func requestHealthKitPermissionsIfNeeded() {
        guard !healthKitAuthorized else { return }
        Task { [weak self] in
            await self?.requestHealthAuthorizationAsync()
        }
    }

    /// Async, awaitable authorization request; reflects the result into the
    /// published flags. Full logic lives in HealthKitAuthService.
    @discardableResult
    private func requestHealthAuthorizationAsync() async -> Bool {
        let result = await authService.requestAuthorization()
        healthKitAuthorized = result.authorized
        authorizationDenied = result.denied
        return result.authorized
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
            defer { self?.isStarting = false }
            guard let self = self else { return }
            await self.startWorkoutAfterAuth()
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
        hkDistanceKm = 0
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
        hasReceivedHRSample = false
        noHeartRateDetected = false
        totalCaloriesAccumulated = 0
        cadenceSampleSum = 0
        cadenceSampleCount = 0
        maxCadenceValue = 0
        lastCadenceStepCount = 0
        lastCadenceTimestamp = nil
        lastCheckpointDate = nil
        lastTickDate = nil
        ticksSinceHeartbeat = 0
        paceWindowSamples.removeAll(keepingCapacity: true)
        heartRateAnchor = nil
        caloriesAnchor = nil
        accumulatedPauseTime = 0
        pauseStartDate = nil
        routePoints = []

        // Start first segment as unknown
        segments.append(ActivitySegment(activityType: .unknown, startDate: now))

        startWorkoutSession()
        startDisplayTimer()
        let sport = activeTemplate?.sportType ?? .running
        if sport.supportsAutoDetection || workoutMode == .gymRecovery {
            startMotionUpdates()
            startPedometerUpdates()
        }
        startHeartRateQuery()
        startCaloriesQuery()
        requestLocationAndStartUpdates()

        logger.info("Workout started (sport: \(sport.displayName))")

        // Notify iPhone that workout started — transferUserInfo wakes iOS in background
        if WCSession.default.activationState == .activated {
            let startPayload: [String: Any] = [
                "action": "workoutStarted",
                "activityType": sport.rawValue,
                "startTime": Date().timeIntervalSince1970
            ]
            WCSession.default.transferUserInfo(startPayload)
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
        let engine = IntervalEngine()
        engine.configure(template: template)
        intervalEngine = engine
        startWorkout()
    }

    func startGymRecoveryWorkout() {
        guard !isWorkoutActive, !isStarting else {
            logger.warning("Workout already active or starting")
            return
        }
        logger.info("Starting gym recovery workout")
        workoutMode = .gymRecovery
        workoutName = "Gym Recovery"
        recoverySegmenter = RecoverySegmenter(config: SegmenterConfig(profile: .cardiacRehab))
        recoveryState = .idle
        restElapsedTime = 0
        stationElapsedTime = 0
        recoverySetNumber = 0
        currentCapturePeakHR = 0
        latestHRR1 = nil
        latestHRR2 = nil
        completedCaptures = []
        currentCadence = 0
        startWorkout()
    }

    // MARK: - Manual station control (cardiacRehab)

    /// Patient tapped **Start Station** on the watch.
    func manualStartStation() {
        guard workoutMode == .gymRecovery, var segmenter = recoverySegmenter else { return }
        let events = segmenter.manualStartStation(hr: heartRate, now: Date())
        recoverySegmenter = segmenter
        processRecoveryEvents(events)
        publishRecoveryState()
    }

    /// Patient tapped **End Station** on the watch.
    func manualEndStation() {
        guard workoutMode == .gymRecovery, var segmenter = recoverySegmenter else { return }
        let events = segmenter.manualEndStation(hr: heartRate, now: Date())
        recoverySegmenter = segmenter
        processRecoveryEvents(events)
        publishRecoveryState()
    }

    /// Mirror segmenter state into the @Published surface views observe.
    /// Same shape as the inline block in `updateElapsedTime`, factored out
    /// so the manual paths can reuse it.
    private func publishRecoveryState() {
        guard let segmenter = recoverySegmenter else { return }
        let now = Date()
        restElapsedTime = segmenter.restStartTime.map { now.timeIntervalSince($0) } ?? 0
        stationElapsedTime = segmenter.workStartTime.map { now.timeIntervalSince($0) } ?? 0
        recoveryState = segmenter.state
        recoverySetNumber = segmenter.setNumber
    }

    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }
        applyPauseState()
        workoutSession?.pause()
        logger.info("Workout paused")
    }

    /// Everything a pause does EXCEPT pausing the HKWorkoutSession itself.
    /// Called both from user-initiated pauseWorkout() and from the session
    /// delegate when watchOS pauses the session on its own — in the latter
    /// case the session is already paused and must not be paused again.
    func applyPauseState() {
        isPaused = true
        pauseStartDate = Date()

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        // Heart rate and calorie queries are intentionally kept running through pause/resume
        // to avoid the HKAnchoredObjectQuery replay bug: stopping and restarting a query
        // causes the initial results handler to re-deliver all samples since the last anchor,
        // double-counting calories/HR samples already processed.
        stopLocationUpdates()

        saveWorkoutDataToLocalStorage()
    }

    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }
        applyResumeState()
        workoutSession?.resume()
        logger.info("Workout resumed")
    }

    /// Everything a resume does EXCEPT resuming the HKWorkoutSession itself.
    /// See applyPauseState() for why this is split out.
    func applyResumeState() {
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

        startDisplayTimer()
        let sport = activeTemplate?.sportType ?? .running
        if sport.supportsAutoDetection || workoutMode == .gymRecovery {
            startMotionUpdates()
            startPedometerUpdates()
        }
        // Heart rate and calorie queries are kept running continuously — do not restart them
        // here. Restarting an HKAnchoredObjectQuery replays all samples since the stored
        // anchor in the initial results handler, causing double-counting on every resume.
        startLocationUpdates()
    }

    func stopWorkout() {
        guard isWorkoutActive else { return }

        stopDisplayTimer()
        stopMotionUpdates()
        stopPedometerUpdates()
        stopHeartRateQuery()
        stopCaloriesQuery()
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
        hkDistanceKm = 0
        currentPace = nil
        completedKmSplits = []
        lastCompletedKm = 0
        timeAtLastKm = 0
        segments = []
        hasReceivedHRSample = false
        noHeartRateDetected = false
        workoutStartTime = nil
        currentSegmentStartTime = nil
        pendingActivity = nil
        pendingActivityStartTime = nil
        heartRateSampleSum = 0
        heartRateSampleCount = 0
        maxHeartRateValue = 0
        cadenceSampleSum = 0
        cadenceSampleCount = 0
        maxCadenceValue = 0
        lastCadenceStepCount = 0
        lastCadenceTimestamp = nil
        paceWindowSamples.removeAll(keepingCapacity: true)
        totalCaloriesAccumulated = 0
        heartRateAnchor = nil
        caloriesAnchor = nil
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

        // Reset gym recovery mode
        recoverySegmenter = nil
        recoveryState = .idle
        restElapsedTime = 0
        stationElapsedTime = 0
        recoverySetNumber = 0
        currentCapturePeakHR = 0
        latestHRR1 = nil
        latestHRR2 = nil
        completedCaptures = []
        currentCadence = 0

        // Clear backup so a Discard path doesn't trigger a false crash-recovery prompt
        // on next launch. (Save path also clears it on confirmed save — idempotent.)
        persistence.clearBackup()
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
        // Gym recovery sessions use functionalStrengthTraining so Health.app classifies them correctly
        if workoutMode == .gymRecovery {
            configuration.activityType = .functionalStrengthTraining
            configuration.locationType = .indoor
        } else {
            configuration.activityType = sport.hkActivityType
            configuration.locationType = sport.hkLocationType
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession = session
            workoutSession?.delegate = self
            let builder = session.associatedWorkoutBuilder()
            workoutBuilder = builder
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            builder.delegate = self
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
        guard let segStart = currentSegmentStartTime else { return }

        // Tick heartbeat: a growing gap means the timer is being throttled or
        // the main actor is backlogged; logs stopping entirely means a kill.
        let tickNow = Date()
        if let lastTick = lastTickDate {
            let gap = tickNow.timeIntervalSince(lastTick)
            if gap > 2.5 {
                logger.warning("Tick gap \(String(format: "%.1f", gap))s at elapsed \(Int(self.elapsedTime))s — timer throttled or suspended")
            }
        }
        lastTickDate = tickNow
        ticksSinceHeartbeat += 1
        if ticksSinceHeartbeat >= 60 {
            ticksSinceHeartbeat = 0
            let sessionState = workoutSession?.state.rawValue ?? -1
            logger.info("Tick heartbeat: elapsed \(Int(self.elapsedTime))s, hr \(self.heartRate), session state \(sessionState)")
        }

        // Pause-corrected wall-clock elapsed. Computed once here and fed to the
        // engine so its countdown is wall-clock-derived (dropped ticks self-heal).
        let wallClockElapsed = Date().timeIntervalSince(startTime) - accumulatedPauseTime

        // Order matters: tick the engine FIRST so its @Published state is up to
        // date BEFORE we write to elapsedTime. The elapsedTime write fires the
        // manager's objectWillChange; SwiftUI re-evaluates the body next runloop
        // pass and reads engine.currentStepTimeRemaining (already decremented).
        if workoutMode == .interval, let engine = intervalEngine {
            engine.tick(heartRate: heartRate, distance: totalDistance, workoutElapsed: wallClockElapsed)
            if engine.isComplete {
                saveWorkoutData()
                stopWorkout()
                return
            }
        }

        elapsedTime = wallClockElapsed
        currentSegmentTime = Date().timeIntervalSince(segStart)

        // Check debounce for pending activity transitions
        checkPendingActivityTransition()

        // Tick recovery segmenter if in gym recovery mode
        if workoutMode == .gymRecovery, var segmenter = recoverySegmenter {
            let maxHR = HeartRateZoneCalculator.fromSharedDefaults().estimatedMaxHR
            let events = segmenter.tick(hr: heartRate, activity: currentActivity, maxHR: maxHR, now: Date())
            recoverySegmenter = segmenter
            processRecoveryEvents(events)
            let now = Date()
            if let restStart = segmenter.restStartTime {
                restElapsedTime = now.timeIntervalSince(restStart)
            } else {
                restElapsedTime = 0
            }
            if let workStart = segmenter.workStartTime {
                stationElapsedTime = now.timeIntervalSince(workStart)
            } else {
                stationElapsedTime = 0
            }
            recoveryState = segmenter.state
            recoverySetNumber = segmenter.setNumber
        }

        // Broadcast live metrics to iOS every 3 seconds
        broadcastLiveMetricsIfNeeded()

        // Periodic checkpoint: keep the crash backup fresh so a kill at any
        // point loses at most `checkpointInterval` seconds of the session.
        let now = Date()
        let checkpointDue = lastCheckpointDate.map { now.timeIntervalSince($0) >= checkpointInterval } ?? true
        if checkpointDue {
            lastCheckpointDate = now
            saveWorkoutDataToLocalStorage()
        }
    }

    // MARK: - Live Metrics Broadcast

    // Dual-channel live metrics broadcast:
    //  • sendMessage — real-time when iPhone is reachable (foregrounded / unlocked)
    //  • updateApplicationContext — OS-queued, delivered when iPhone next wakes
    //    (handles locked phone in pocket, suspended app, brief BT hiccups)
    // Do NOT add an isReachable guard — it silently drops metrics during runs when
    // the iPhone is locked. applicationContext only stores the latest snapshot,
    // which is exactly what we want for live metrics.
    private func broadcastLiveMetricsIfNeeded() {
        let now = Date()
        if let lastUpdate = lastLiveUpdateTime, now.timeIntervalSince(lastUpdate) < 3.0 {
            return
        }
        lastLiveUpdateTime = now

        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = [
            "action": "liveMetrics",
            "workoutName": workoutName,
            "elapsedTime": elapsedTime,
            "heartRate": heartRate,
            "distance": totalDistance,
            "calories": calories,
            "steps": totalSteps,
            "currentActivity": currentActivity.rawValue,
            "isPaused": isPaused,
            "pace": currentPace ?? 0,
            "cadence": currentCadence,
            "timestamp": now.timeIntervalSince1970
        ]

        // Include latest route point for live map on iOS
        if let lastPoint = routePoints.last {
            payload["latitude"] = lastPoint.latitude
            payload["longitude"] = lastPoint.longitude
        }

        // Channel 1: real-time when reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.logger.debug("Live metrics sendMessage failed: \(error.localizedDescription)")
                }
            }
        }

        // Channel 2: applicationContext — always delivered when iPhone next wakes
        do {
            try WCSession.default.updateApplicationContext(payload)
        } catch {
            logger.debug("Live metrics applicationContext failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recovery Mode Event Processing

    private func processRecoveryEvents(_ events: [SegmenterEvent]) {
        for event in events {
            switch event {
            case .enteredWork:
                // Clear previous rest's HRR display on new set start
                latestHRR1 = nil
                latestHRR2 = nil
                currentCapturePeakHR = 0
                #if os(watchOS)
                WKInterfaceDevice.current().play(.click)
                #endif

            case .enteredRest(let peakHR, let setNumber, let restEntryTime):
                currentCapturePeakHR = peakHR
                let capture = HRRCapture(setNumber: setNumber, peakHR: peakHR, restEntryTime: restEntryTime)
                completedCaptures.append(capture)
                #if os(watchOS)
                WKInterfaceDevice.current().play(.stop)
                #endif

            case .hrrCapture(let minuteMark, let hrDrop):
                guard !completedCaptures.isEmpty else { break }
                let idx = completedCaptures.count - 1
                if minuteMark == 1 {
                    let hrAtCapture = max(0, completedCaptures[idx].peakHR - hrDrop)
                    completedCaptures[idx].hrAt60s = hrAtCapture
                    latestHRR1 = hrDrop
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                } else if minuteMark == 2 {
                    let hrAtCapture = max(0, completedCaptures[idx].peakHR - hrDrop)
                    completedCaptures[idx].hrAt120s = hrAtCapture
                    latestHRR2 = hrDrop
                }

            case .restExited(let duration):
                if !completedCaptures.isEmpty {
                    completedCaptures[completedCaptures.count - 1].restDuration = duration
                }
            }
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

    func startLocationUpdates() {
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
                    let pedometerKm = dist.doubleValue / 1000.0
                    // T-METRICS.4: prefer HKLiveWorkoutBuilder's fused distance when
                    // it has begun reporting; otherwise use the pedometer reading.
                    let chosenKm = self.hkDistanceKm > 0 ? self.hkDistanceKm : pedometerKm
                    self.totalDistance = chosenKm
                    self.updatePaceAndSplits(distanceKm: chosenKm)
                }
                let spm: Int? = {
                    if let cadence = data.currentCadence {
                        // Preferred: Apple's instantaneous cadence (steps/sec → steps/min)
                        return Int(cadence.doubleValue * 60)
                    }
                    // Fallback: derive from step delta over a ≥3s window so brief
                    // pauses between samples don't produce wild jitter. nil until
                    // we accumulate the first window's worth of samples.
                    guard let lastTS = self.lastCadenceTimestamp else {
                        self.lastCadenceStepCount = self.totalSteps
                        self.lastCadenceTimestamp = Date()
                        return nil
                    }
                    let dt = Date().timeIntervalSince(lastTS)
                    guard dt >= 3.0 else { return nil }
                    let stepDelta = self.totalSteps - self.lastCadenceStepCount
                    let derived = Int(Double(stepDelta) * 60.0 / dt)
                    self.lastCadenceStepCount = self.totalSteps
                    self.lastCadenceTimestamp = Date()
                    return max(0, derived)
                }()
                if let spm = spm {
                    self.currentCadence = spm
                    // Only average when actually moving (spm > 0) and not paused.
                    // Zero ticks happen during walks against treadmill rails or rest periods —
                    // including them would skew the average toward zero.
                    if !self.isPaused && spm > 0 {
                        self.cadenceSampleSum += Double(spm)
                        self.cadenceSampleCount += 1
                        if spm > self.maxCadenceValue {
                            self.maxCadenceValue = spm
                        }
                    }
                }
            }
        }
    }

    private func updatePaceAndSplits(distanceKm: Double) {
        // Match iPhone's guard threshold exactly (>= 0.05 km / 50 m). Using a
        // smaller outer threshold (0.01) would let the pace window accumulate
        // tiny-distance samples that compute a meaningless ratio.
        guard distanceKm >= 0.05 else {
            currentPace = nil
            return
        }

        // Rolling pace from a sliding 30s window of (elapsedTime, distance)
        // samples. Guards: workout >= 20s old, distance >= 0.05km, window
        // spans >= 5s and >= 5m. When guards fail before publishing, keep
        // currentPace nil; when they fail after publishing, keep last value.
        let now = elapsedTime
        paceWindowSamples.append((time: now, distance: distanceKm))
        let cutoff = now - paceWindowSec
        paceWindowSamples.removeAll { $0.time < cutoff }
        if now < 20 || distanceKm < 0.05 {
            currentPace = nil
        } else if let oldest = paceWindowSamples.first {
            let dt = now - oldest.time
            let dDist = distanceKm - oldest.distance
            if dt >= 5, dDist >= 0.005 {
                currentPace = dt / dDist
            }
            // else: keep previous currentPace value (don't flip mid-workout)
        }

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

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        guard healthKitAuthorized else {
            logger.warning("startHeartRateQuery skipped — HealthKit not authorized")
            return
        }
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let startDate = workoutStartTime else { return }

        stopHeartRateQuery()

        // Time-only predicate. Do NOT filter by HKDevice.local() — the live workout
        // sensor's device identity rarely matches HKDevice.local() exactly, so the
        // device filter silently excludes the watch's own HR samples and BPM reads 0.
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

        scheduleNoHRWatchdog()
    }

    /// Arm a one-shot timer. If no HR sample has arrived after `noHRDetectedAfter`
    /// seconds — and the workout is still active and not paused — flip
    /// `noHeartRateDetected` so the UI can surface a "no heart rate" banner.
    private func scheduleNoHRWatchdog() {
        noHRTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + noHRDetectedAfter)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !self.hasReceivedHRSample, self.isWorkoutActive, !self.isPaused {
                self.noHeartRateDetected = true
                self.logger.warning("No heart rate sample after \(self.noHRDetectedAfter)s — surfacing banner")
            }
        }
        noHRTimer = t
        t.resume()
    }

    nonisolated private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let bpmValues = quantitySamples.map { $0.quantity.doubleValue(for: bpmUnit) }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // First real sample — clear any "no HR" banner and stop the watchdog.
            self.hasReceivedHRSample = true
            if self.noHeartRateDetected { self.noHeartRateDetected = false }
            // Only include samples taken while workout is not paused
            if !self.isPaused {
                self.heartRateSampleSum += bpmValues.reduce(0, +)
                self.heartRateSampleCount += bpmValues.count
            }
            if let latestBPM = bpmValues.last {
                self.heartRate = Int(latestBPM.rounded())
            }
            if let maxBPM = bpmValues.max(), maxBPM > self.maxHeartRateValue {
                self.maxHeartRateValue = maxBPM
            }
        }
    }

    private func stopHeartRateQuery() {
        noHRTimer?.cancel()
        noHRTimer = nil
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    // MARK: - Calories Query

    private func startCaloriesQuery() {
        guard healthKitAuthorized else {
            logger.warning("startCaloriesQuery skipped — HealthKit not authorized")
            return
        }
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let startDate = workoutStartTime else { return }

        stopCaloriesQuery()

        // Time-only predicate — same rationale as the HR query: an HKDevice.local()
        // filter can silently exclude the watch's own samples.
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

    func saveWorkoutDataToLocalStorage() {
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
            kmSplits: backupSplits,
            averageCadence: cadenceSampleCount > 0 ? cadenceSampleSum / Double(cadenceSampleCount) : nil,
            maxCadence: maxCadenceValue > 0 ? maxCadenceValue : nil
        )

        persistence.checkpoint(session)
    }

    /// Check for a crashed workout backup and recover the session
    func recoverCrashedWorkout() -> TrainingSession? {
        persistence.recoverCrashedWorkout()
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
                persistence.clearBackup()
                return
            }
        }
        sharedDataManager?.sendSessionToiOS(session)
        persistence.clearBackup()
        logger.info("Recovered session sent to iOS and backup cleared")
    }

    /// Finalize an HKWorkoutSession orphaned by a crash or watchdog kill so its
    /// collected data still reaches HealthKit. Without this, a workout whose
    /// process died mid-run never writes an HKWorkout at all — the session stays
    /// live inside HealthKit with no owner. Called once at app launch.
    func recoverOrphanedHKSession() {
        #if os(watchOS)
        healthStore.recoverActiveWorkoutSession { [weak self] session, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("recoverActiveWorkoutSession failed: \(error.localizedDescription)")
                    return
                }
                guard let session = session else { return }
                guard !self.isWorkoutActive else {
                    self.logger.warning("Orphaned HK session found while a workout is active — ignoring")
                    return
                }
                self.logger.warning("Recovered orphaned HKWorkoutSession (state \(session.state.rawValue)) — finalizing so the workout reaches Health")
                let builder = session.associatedWorkoutBuilder()
                if session.state == .running || session.state == .paused {
                    session.end()
                }
                builder.endCollection(withEnd: Date()) { _, endError in
                    if let endError = endError {
                        Task { @MainActor [weak self] in
                            self?.logger.error("endCollection on recovered session failed: \(endError.localizedDescription)")
                        }
                    }
                    builder.finishWorkout { workout, finishError in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            if let finishError = finishError {
                                self.logger.error("finishWorkout on recovered session failed: \(finishError.localizedDescription)")
                            } else {
                                self.logger.info("Orphaned workout finalized to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
                            }
                        }
                    }
                }
            }
        }
        #endif
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
            kmSplits: splits,
            averageCadence: cadenceSampleCount > 0 ? cadenceSampleSum / Double(cadenceSampleCount) : nil,
            maxCadence: maxCadenceValue > 0 ? maxCadenceValue : nil
        )

        // Attach interval results if this was an interval workout
        if workoutMode == .interval, let engine = intervalEngine {
            let result = engine.stop(finalDistance: totalDistance)
            session.templateID = result.templateID
            session.programName = result.templateName
            session.completedIntervalResults = result.results
        }

        // Attach recovery results if this was a gym recovery session
        if workoutMode == .gymRecovery {
            session.sessionMode = .gymRecovery
            session.programName = "Gym Recovery"
            let finishedCaptures = completedCaptures
            if !finishedCaptures.isEmpty {
                session.recoveryReport = RecoveryReport(
                    sets: finishedCaptures.count,
                    captures: finishedCaptures
                )
            }
        }

        // Set sport type from template
        session.sportType = activeTemplate?.sportType

        // Capture mutable copies for use in the async Task below
        let sessionToSend = session
        let routeBuilderToFinish = routeBuilder

        #if os(watchOS)
        let builderToFinish = workoutBuilder
        // Capture HKWorkout metadata values before entering the async context
        let capturedWorkoutName = workoutName
        let capturedIsIndoor = workoutMode == .gymRecovery || (activeTemplate?.sportType?.hkLocationType ?? .unknown) == .indoor
        let capturedIntervalCount = activeTemplate?.intervals.count ?? 0
        // Nil out builder/route references before async work so no other call reuses them
        workoutBuilder = nil
        #endif
        routeBuilder = nil

        // Finalize HKLiveWorkoutBuilder → saves HKWorkout to HealthKit, then attach route
        Task {
            #if os(watchOS)
            if let builder = builderToFinish {
                do {
                    // Attach metadata before closing the builder so it appears in Health.app
                    var hkMetadata: [String: Any] = [
                        HKMetadataKeyIndoorWorkout: NSNumber(value: capturedIsIndoor)
                    ]
                    if !capturedWorkoutName.isEmpty {
                        hkMetadata["templateName"] = capturedWorkoutName
                    }
                    if capturedIntervalCount > 0 {
                        hkMetadata["intervalCount"] = NSNumber(value: capturedIntervalCount)
                    }
                    try await builder.addMetadata(hkMetadata)
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
        persistence.clearBackup()
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

    #if DEBUG
    /// Seed representative interval-workout state for snapshot/preview rendering
    /// only. Never called in production paths. Mirrors the iOS
    /// `applyPreviewSnapshot` so the Arcade chrome can be captured at true
    /// device size: stage 3/8, 01:48 countdown, HR 142, live SPM/distance.
    func applyPreviewSnapshot() {
        workoutMode = .interval
        workoutName = "5K Interval"
        isWorkoutActive = true
        isPaused = false
        elapsedTime = 22 * 60 + 14
        totalDistance = 3.42
        totalSteps = 4187
        currentPace = 5 * 60 + 38
        currentCadence = 168
        heartRate = 142
        calories = 268

        let template = WorkoutTemplate(
            name: "5K Interval",
            intervals: [
                IntervalStep(type: .work, duration: 1,   label: "RUN"),
                IntervalStep(type: .work, duration: 120, label: "RUN"),
                IntervalStep(type: .rest, duration: 60,  label: "WALK"),
                IntervalStep(type: .work, duration: 120, label: "RUN"),
                IntervalStep(type: .rest, duration: 60,  label: "WALK"),
                IntervalStep(type: .work, duration: 120, label: "RUN")
            ],
            repeatCount: 1,
            warmup: IntervalStep(type: .warmup, duration: 1, label: "WARM UP"),
            cooldown: IntervalStep(type: .cooldown, duration: 120, label: "COOL DOWN")
        )
        let engine = IntervalEngine()
        engine.configure(template: template)
        // Advance to step 3/8 (index 2, a 120s work step) at 01:48 remaining:
        // elapsed 1 clears the 1s warmup, 2 clears the 1s work, 14 → 12s into
        // the 120s step (108s remaining).
        for i in 1...14 { engine.tick(heartRate: 142, distance: 3.42, workoutElapsed: TimeInterval(i)) }
        intervalEngine = engine
    }
    #endif
}
