import Foundation
import HealthKit
import CoreMotion
import CoreLocation
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif
import os
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
    /// Wall-clock basis for SwiftUI's system-rendered timer text
    /// (`Text(timerInterval:)`), which ticks in the render server and therefore
    /// keeps counting even when the main actor is backlogged or the app is in
    /// Always-On (reduced luminance) state.
    ///
    /// Invariant while RUNNING: `timerReferenceDate == Date() - elapsedTime`,
    /// i.e. `workoutStartTime + accumulatedPauseTime`. `nil` while paused and
    /// after stop, so views fall back to static `elapsedTime` text.
    /// `elapsedTime` itself is unchanged — metrics, the interval engine and the
    /// crash checkpoints all still derive from it.
    @Published private(set) var timerReferenceDate: Date?
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

    /// Non-nil while the post-workout summary is pending user dismissal (S-1 fix).
    /// Set BEFORE stopWorkout() so ContentView can show WorkoutSummaryView while
    /// TrainingView is still mounted; cleared by the user dismissing the summary.
    @Published var pendingSummary: WorkoutSummary? = nil

    /// Start-phase error visible to ProgramSelectionView (before any workout is active).
    /// Distinct from healthKitSaveError (which is a mid/post-workout save failure shown
    /// by TrainingView's alert). Cleared on the next successful workout start.
    @Published var startupError: String? = nil

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
    /// One id per workout, created at start and shared by the 15s checkpoint
    /// and the final save — recovery dedup compares ids, so both saves MUST
    /// agree or a surviving backup re-imports as a duplicate session.
    private var currentSessionID = UUID()
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
    // Samples are keyed on WALL CLOCK, not `elapsedTime`. Keying on elapsedTime
    // created a feedback loop: if the display tick stalls, elapsedTime stops
    // advancing, the 30s cutoff stops moving, and every pedometer callback appends
    // a sample that is never pruned — an unbounded array with an O(n) removeAll per
    // callback, which deepens the very main-actor backlog that stalled the tick.
    private var paceWindowSamples: [(time: Date, distance: Double)] = []
    private let paceWindowSec: TimeInterval = 30

    // Pace & split tracking
    private var timeAtLastKm: TimeInterval = 0

    // T-METRICS.4: HKLiveWorkoutBuilder's distanceWalkingRunning statistic is
    // Apple's canonical fused distance (pedometer + GPS + on-device motion).
    // We prefer it over CMPedometer.distance when > 0, and fall back to the
    // pedometer reading during the brief warmup before the builder reports.
    var hkDistanceKm: Double = 0

    // Live metrics broadcast
    private let broadcaster = LiveMetricsBroadcaster()

    let persistence = WorkoutPersistence()

    // Periodic crash-recovery checkpoint (a never-paused workout must still
    // leave a recoverable backup — see docs/plans/2026-07-stability-and-design-plan.md)
    private var lastCheckpointDate: Date?
    private let checkpointInterval: TimeInterval = 15

    // Freeze instrumentation: proves on-device whether ticks stall (main-actor
    // backlog / suspension) or stop entirely (kill) — see freeze root-cause plan.
    private var lastTickDate: Date?
    private var ticksSinceHeartbeat = 0

    // Tick reentrancy guard — touched from the timer's background queue AND the
    // main actor, hence a lock rather than actor-isolated state.
    private nonisolated let tickPending = OSAllocatedUnfairLock(initialState: false)

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

    // Debounce: pending activity must persist for this duration before committing.
    // The debounce itself is unchanged; ActivityClassifier layers the confidence
    // and cadence-corroboration gates on top of it (Phase 1 / CE1).
    private static let activityDebounceInterval: TimeInterval = 5.0
    private var classifier = ActivityClassifier(debounceInterval: WatchWorkoutManager.activityDebounceInterval)
    /// True while `currentSegmentStartTime` is set but no `ActivitySegment` row
    /// has been opened for it yet — the workout has started (or resumed) and we
    /// are waiting for the first *confident* classification. The segment is then
    /// backdated to `currentSegmentStartTime`, so no `.unknown` placeholder ever
    /// reaches storage (CE2).
    private var awaitingSegmentOpen = false
    /// Step/distance totals at the current segment's start — the deltas become
    /// `ActivitySegment.steps` / `.distance` when the segment closes (CE2).
    private var segmentStartSteps: Int = 0
    private var segmentStartDistance: Double = 0
    /// `currentCadence` starts at 0 and is only written once a pedometer sample
    /// lands; without this flag the classifier cannot tell "0 spm" from
    /// "no cadence yet" — and they mean opposite things for `.stationary`.
    private var hasCadenceSample = false
    /// Most recent motion reading, kept in interval mode purely so the
    /// instrumentation can report where detection disagreed with the plan.
    private var lastMotionReading: (activity: DetectedActivity, confidence: ActivityClassifier.Confidence)?
    /// Interval-mode segment reconciliation: the `IntervalEngine` step index the
    /// current segment was opened for (CE7).
    private var lastIntervalStepIndex: Int?

    // MARK: - Per-phase energy (Phase 2 / CE3-CE5)

    /// Timestamped HR / Apple-energy / pause timeline. The running accumulators
    /// above answer "what was the session average"; this answers "what happened
    /// during *this* segment", which is what per-phase calories need.
    private var metricsLedger = SegmentMetricsLedger()
    /// Body mass / age / max HR resolved once per workout start.
    private var anthropometrics = Anthropometrics()
    /// True when body mass is unknown, so no ShuttlX MET estimate can be produced.
    /// Drives the "add your weight in Health" hint on the summary screen — we do
    /// not substitute a 70 kg placeholder (plan item 5).
    @Published private(set) var bodyMassUnavailable: Bool = false

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

    /// Fire-and-forget read of body mass / age / sex for the per-phase calorie
    /// model (Phase 2 / CE4).
    private func loadAnthropometrics() {
        Task { [weak self] in
            guard let self = self else { return }
            let values = await self.authService.loadAnthropometrics()
            self.anthropometrics = values
            self.bodyMassUnavailable = !values.hasBodyMass
            if !values.hasBodyMass {
                self.logger.warning("SEG KCAL: body mass unavailable — ShuttlX per-phase estimate suppressed (no 70kg placeholder)")
            }
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

        // RC-3: Always reset interval/recovery state at free-run entry. If the
        // previous session crashed before stopWorkout() ran, workoutMode/.intervalEngine
        // can still be .interval with a completed engine. Without this reset, the timer
        // would tick the stale engine and auto-stop the free run when engine.isComplete
        // fires (typically at the old template's total duration — coincides with ~500m
        // at a moderate walking pace).
        workoutMode = .freeRun
        intervalEngine = nil
        activeTemplate = nil
        workoutName = "Free Run"

        // Set isStarting so the UI shows a spinner on the very next frame.
        isStarting = true

        Task { [weak self] in
            defer { self?.isStarting = false }
            guard let self = self else { return }
            await self.startWorkoutAfterAuth()
        }
    }

    /// Async core of workout startup — awaits HealthKit authorization, then
    /// initialises state and starts all sensors/queries.
    private func startWorkoutAfterAuth() async {
        // Serialize behind launch recovery. On a cold launch a fast start (e.g. a
        // complication deep link) used to race recoverOrphanedHKSession(): the RC-2
        // guard made recovery bail out, leaving an orphaned HKWorkoutSession live
        // alongside the brand-new one, and the system then ended one of them —
        // the "workout auto-stops within a minute of first launch" bug. Near-instant
        // when there is nothing to recover.
        if let recovery = launchRecoveryTask {
            await recovery.value
        }

        // Abort if another workout snuck in while we were waiting.
        guard !isWorkoutActive else {
            logger.warning("Workout became active while awaiting authorization")
            return
        }

        let authorized = await requestHealthAuthorizationAsync()
        guard authorized else {
            logger.warning("Workout start aborted — HealthKit not authorized")
            // authorizationDenied is set by requestHealthAuthorizationAsync when the
            // user (or the system) actually refused. When it is false we got here via
            // the authorization TIMEOUT, which is a different user story: nothing was
            // denied, the grant sheet just never resolved. Surface a retry prompt via
            // startupError — ProgramSelectionView shows it in an ErrorBanner — instead
            // of silently doing nothing.
            if !authorizationDenied {
                startupError = "Health access didn't finish setting up. Please try again."
            }
            return
        }

        // Clear any previous start-phase error — the user is making a new attempt.
        startupError = nil

        let now = Date()
        workoutStartTime = now
        currentSessionID = UUID()
        currentSegmentStartTime = now
        // NOTE: isWorkoutActive is set AFTER startWorkoutSession() succeeds (RC-1 fix).
        // Setting it here (before the HK session) would leave the app showing a live
        // workout with no background runtime if the session fails — killed at wrist-down.
        isPaused = false
        elapsedTime = 0
        // Running invariant: start time + accumulated pause (zero at start).
        timerReferenceDate = now
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
        classifier.reset()
        awaitingSegmentOpen = true
        segmentStartSteps = 0
        segmentStartDistance = 0
        hasCadenceSample = false
        lastMotionReading = nil
        lastIntervalStepIndex = nil
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
        metricsLedger.reset()

        // Anthropometrics are NOT awaited: the calorie model only runs when a
        // segment closes, and the first close is minutes away. Blocking the start
        // button on an HKSampleQuery would trade a real UX cost for nothing.
        loadAnthropometrics()

        // No `.unknown` placeholder segment (CE2). Free-run/gym sessions open
        // their first segment from the first confident classification, backdated
        // to `now`; interval sessions open theirs immediately from the plan.
        if workoutMode == .interval, let engine = intervalEngine, let step = engine.currentStep {
            let planned = Self.plannedActivity(for: step.type)
            openSegment(activity: planned, at: now)
            currentActivity = planned
            lastIntervalStepIndex = engine.currentStepIndex
            logger.info("SEG OPEN [plan] step 1/\(engine.totalStepsCount) \(step.type.rawValue) -> \(planned.rawValue)")
        }

        // RC-1: Only mark the workout active after the HK session is confirmed started.
        // If the session fails, roll back timestamps so saveWorkoutData() can't persist
        // a zero-duration session, and return without starting sensors.
        guard startWorkoutSession() else {
            workoutStartTime = nil
            timerReferenceDate = nil
            segments = []
            awaitingSegmentOpen = false
            lastIntervalStepIndex = nil
            return
        }
        isWorkoutActive = true
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

        broadcaster.notifyWorkoutStarted(sport: sport)
    }

    func startIntervalWorkout(template: WorkoutTemplate) {
        guard !isWorkoutActive, !isStarting else {
            logger.warning("Workout already active or starting")
            return
        }
        logger.info("Starting interval workout: \(template.name)")
        // Set mode/engine BEFORE launching the task. startWorkout() resets these to
        // .freeRun, so interval callers must NOT call startWorkout() — they launch the
        // shared async core directly. (RC-3 fix separates the two entry paths.)
        workoutMode = .interval
        workoutName = template.name
        activeTemplate = template
        let engine = IntervalEngine()
        engine.configure(template: template)
        intervalEngine = engine
        isStarting = true
        Task { [weak self] in
            defer { self?.isStarting = false }
            guard let self = self else { return }
            await self.startWorkoutAfterAuth()
        }
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
        // Launch async core directly — same as startIntervalWorkout; must NOT call
        // startWorkout() which resets workoutMode to .freeRun. (RC-3)
        isStarting = true
        Task { [weak self] in
            defer { self?.isStarting = false }
            guard let self = self else { return }
            await self.startWorkoutAfterAuth()
        }
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
        // Freeze the system-rendered timer: views fall back to static elapsedTime text.
        timerReferenceDate = nil

        // Push isPaused:true to iPhone before stopping the timer so the
        // 10-second timeout on the phone side doesn't clear live state.
        broadcaster.reset()
        broadcastLiveMetricsIfNeeded()

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
            let pauseEnd = Date()
            accumulatedPauseTime += pauseEnd.timeIntervalSince(pauseStart)
            // Segments close on RESUME, not on pause, so the paused span sits
            // inside the segment that was open. Record it or the MET estimate
            // charges the wearer for standing still (Phase 2).
            metricsLedger.recordPause(from: pauseStart, to: pauseEnd)
            pauseStartDate = nil
        }

        // Re-anchor the system-rendered timer past the pause we just closed:
        // start + total pause == Date() - elapsedTime.
        timerReferenceDate = workoutStartTime?.addingTimeInterval(accumulatedPauseTime)

        // Close the current segment and start a new one. CE2: the old code
        // reopened the segment carrying the PRE-PAUSE `currentActivity`, which is
        // stale by definition — a pause is exactly when the wearer changes what
        // they are doing. Interval mode re-seeds from the plan (authoritative);
        // free-run/gym mode waits for the classifier to re-earn the activity and
        // backdates the segment to this moment once it does.
        let now = Date()
        closeCurrentSegment(at: now)
        currentSegmentStartTime = now
        currentSegmentTime = 0
        segmentStartSteps = totalSteps
        segmentStartDistance = totalDistance
        awaitingSegmentOpen = true

        if workoutMode == .interval, let engine = intervalEngine, let step = engine.currentStep {
            let planned = Self.plannedActivity(for: step.type)
            openSegment(activity: planned, at: now)
            currentActivity = planned
            lastIntervalStepIndex = engine.currentStepIndex
            logger.info("SEG OPEN [plan/resume] step \(engine.currentStepIndex + 1)/\(engine.totalStepsCount) \(step.type.rawValue) -> \(planned.rawValue)")
        } else {
            classifier.requireReconfirmation()
            logger.info("SEG PENDING [free-run/resume] awaiting re-classification (was \(self.currentActivity.rawValue))")
        }

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
        closeCurrentSegment(at: Date())

        // Note: session is sent to iOS by saveWorkoutData() which is called before stopWorkout()
        // stopWorkout() only cleans up state — no duplicate send

        // Reset state
        isWorkoutActive = false
        isPaused = false
        currentActivity = .unknown
        elapsedTime = 0
        timerReferenceDate = nil
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
        classifier.reset()
        awaitingSegmentOpen = false
        segmentStartSteps = 0
        segmentStartDistance = 0
        hasCadenceSample = false
        lastMotionReading = nil
        lastIntervalStepIndex = nil
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
        // Free the per-phase timeline as soon as the session is saved — it is the
        // largest per-workout allocation this class holds.
        metricsLedger.reset()
        heartRateAnchor = nil
        caloriesAnchor = nil
        broadcaster.reset()
        routePoints = []
        accumulatedPauseTime = 0
        pauseStartDate = nil

        broadcaster.notifyWorkoutStopped()

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

    @discardableResult
    private func startWorkoutSession() -> Bool {
        guard healthKitAuthorized else {
            logger.warning("startWorkoutSession skipped — HealthKit not authorized")
            return false
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available")
            return false
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
            return true
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
            // Use startupError (not healthKitSaveError) — at this point isWorkoutActive
            // is still false so TrainingView is never shown; the error must surface through
            // ProgramSelectionView's ErrorBanner which observes startupError.
            startupError = "Could not start workout. Please try again."
            return false
        }
        #else
        return true
        #endif
    }

    // MARK: - Display Timer (counts UP)

    private func startDisplayTimer() {
        stopDisplayTimer()

        // Use a background queue for the timer source so the 1-second tick does not
        // compete with SwiftUI rendering on the main queue. State updates inside
        // updateElapsedTime() hop back to @MainActor via the class isolation.
        //
        // QoS: .userInitiated. S-6 downgraded this to .utility as a battery
        // optimisation, but .utility is subject to aggressive CPU-bandwidth
        // throttling — under a WatchConnectivity sync storm the tick source was
        // scheduled late, the tickPending guard then DROPPED the late tick, and the
        // on-screen clock stalled for minutes. A 1 Hz timer costs effectively
        // nothing; the correct backpressure mechanism is the drop-guard below, not
        // a starved QoS bucket.
        let newTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        newTimer.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))

        newTimer.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Reentrancy guard: if the previous tick's main-actor task hasn't
            // run yet, DROP this tick instead of enqueueing another. Under a
            // main-actor backlog, stacking ticks only deepens the backlog
            // (freeze root-cause H1); the wall-clock-derived countdown and
            // elapsed time self-heal on the next executed tick.
            let alreadyPending = self.tickPending.withLock { pending -> Bool in
                if pending { return true }
                pending = true
                return false
            }
            if alreadyPending { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.tickPending.withLock { $0 = false }
                self.updateElapsedTime()
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
                // Build summary BEFORE save+stop — stopWorkout() zeros all published state.
                let summary = buildCurrentSummary()
                saveWorkoutData()
                pendingSummary = summary
                stopWorkout()
                return
            }
            // Keep the segment timeline locked to the plan's step boundaries.
            reconcileIntervalSegment(engine: engine)
        }

        elapsedTime = wallClockElapsed
        currentSegmentTime = Date().timeIntervalSince(segStart)

        // Check debounce + corroboration for pending activity transitions
        // (no-op in interval mode — the classifier is never fed there).
        if workoutMode != .interval {
            checkPendingActivityTransition()
        }

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

    private func broadcastLiveMetricsIfNeeded() {
        broadcaster.broadcastIfNeeded(LiveMetricsBroadcaster.Snapshot(
            workoutName: workoutName,
            elapsedTime: elapsedTime,
            heartRate: heartRate,
            distance: totalDistance,
            calories: calories,
            steps: totalSteps,
            activityRawValue: currentActivity.rawValue,
            isPaused: isPaused,
            pace: currentPace,
            cadence: currentCadence,
            lastLatitude: routePoints.last?.latitude,
            lastLongitude: routePoints.last?.longitude
        ))
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

        let confidence: ActivityClassifier.Confidence
        switch activity.confidence {
        case .low: confidence = .low
        case .medium: confidence = .medium
        case .high: confidence = .high
        @unknown default: confidence = .low
        }

        if detected != .unknown {
            lastMotionReading = (detected, confidence)
        }

        // Interval mode: the template's step schedule is ground truth for the
        // segment timeline (CE7). Motion is still read — it feeds the
        // plan-vs-detection disagreement log — but never opens a segment.
        guard workoutMode != .interval else { return }

        let outcome = classifier.ingest(activity: detected, confidence: confidence, now: Date())
        switch outcome {
        case .droppedLowConfidence(let proposed):
            logger.debug("SEG READ [free-run] \(proposed.rawValue) dropped — low confidence")
        case .startedPending(let proposed):
            logger.info("SEG PENDING [free-run] \(proposed.rawValue) conf=\(confidence.label) cadence=\(self.cadenceForClassification.map(String.init) ?? "n/a")")
        case .droppedUnclassified, .continuedPending, .confirmedCurrent:
            break
        }
    }

    /// Cadence as the classifier should see it: `nil` until the pedometer has
    /// actually reported, because a literal 0 spm is meaningful evidence.
    private var cadenceForClassification: Int? {
        hasCadenceSample ? currentCadence : nil
    }

    private func checkPendingActivityTransition() {
        switch classifier.evaluate(cadence: cadenceForClassification, now: Date()) {
        case .idle:
            break
        case .holding(let hold):
            logger.warning("""
                SEG HOLD [free-run] \(hold.activity.rawValue) held \(String(format: "%.0f", hold.heldFor))s — \
                cadence \(hold.cadence.map(String.init) ?? "n/a") spm contradicts at conf=\(hold.minConfidence.label) \
                (needs high); staying on \(self.currentActivity.rawValue)
                """)
        case .commit(let decision):
            commitActivityTransition(decision)
        }
    }

    private func commitActivityTransition(_ decision: ActivityClassifier.Decision) {
        let now = Date()
        let backdated = awaitingSegmentOpen
        let startDate: Date

        if awaitingSegmentOpen {
            // First classification of this run/resume — the segment owns the time
            // back to the workout (or resume) start instead of leaving a hole.
            startDate = currentSegmentStartTime ?? now
        } else {
            closeCurrentSegment(at: now)
            startDate = now
            currentSegmentStartTime = now
            segmentStartSteps = totalSteps
            segmentStartDistance = totalDistance
        }

        currentActivity = decision.activity
        openSegment(activity: decision.activity, at: startDate)
        currentSegmentTime = now.timeIntervalSince(startDate)

        // Haptic feedback on activity change (not on a re-open of the same activity)
        #if os(watchOS)
        if !decision.isReconfirmation {
            WKInterfaceDevice.current().play(.start)
        }
        #endif

        let kind = backdated ? "open" : "switch"
        logger.info("""
            SEG COMMIT [free-run/\(kind)] \(decision.previous.rawValue) -> \(decision.activity.rawValue) \
            conf=\(decision.minConfidence.label)..\(decision.maxConfidence.label) \
            cadence=\(decision.cadence.map(String.init) ?? "n/a") spm (\(decision.cadenceCheck.rawValue)) \
            held=\(String(format: "%.0f", decision.heldFor))s hr=\(self.heartRate) \
            at +\(Int(startDate.timeIntervalSince(self.workoutStartTime ?? startDate)))s
            """)
    }

    // MARK: - Interval Plan Reconciliation (CE7)

    /// The plan's declared activity for a template step. Run/walk programs use
    /// warm-up and cool-down as walking phases, which is also what a wearer
    /// actually does during them.
    static func plannedActivity(for stepType: IntervalType) -> DetectedActivity {
        switch stepType {
        case .work: return .running
        case .rest, .warmup, .cooldown: return .walking
        }
    }

    /// Called after every engine tick. When the engine has advanced to a new
    /// step, close the segment and open one typed by the plan. The plan is
    /// trusted **exclusively** here: an independent classifier misfire mid-run
    /// interval would otherwise contradict a schedule we already know exactly.
    /// Motion detection is still logged alongside so Phase 1 verification can
    /// measure how often the two disagree.
    private func reconcileIntervalSegment(engine: IntervalEngine) {
        let index = engine.currentStepIndex
        guard let step = engine.currentStep else { return }
        guard lastIntervalStepIndex != index else { return }
        lastIntervalStepIndex = index

        let planned = Self.plannedActivity(for: step.type)
        let now = Date()

        if awaitingSegmentOpen {
            openSegment(activity: planned, at: currentSegmentStartTime ?? now)
        } else if planned != currentActivity {
            closeCurrentSegment(at: now)
            currentSegmentStartTime = now
            currentSegmentTime = 0
            segmentStartSteps = totalSteps
            segmentStartDistance = totalDistance
            openSegment(activity: planned, at: now)
        }
        currentActivity = planned

        let detected = lastMotionReading.map { "\($0.activity.rawValue)@\($0.confidence.label)" } ?? "n/a"
        let agreement = lastMotionReading.map { $0.activity == planned ? "agrees" : "disagrees" } ?? "unavailable"
        logger.info("""
            SEG COMMIT [plan] step \(index + 1)/\(engine.totalStepsCount) \(step.type.rawValue) -> \(planned.rawValue) \
            motion=\(detected) (\(agreement)) cadence=\(self.cadenceForClassification.map(String.init) ?? "n/a") spm \
            hr=\(self.heartRate) at +\(Int(self.elapsedTime))s
            """)
    }

    // MARK: - Segment Bookkeeping

    private func openSegment(activity: DetectedActivity, at date: Date) {
        segments.append(ActivitySegment(activityType: activity, startDate: date))
        awaitingSegmentOpen = false
    }

    /// Closes the open segment and stamps the steps/distance accrued across its
    /// span (CE2 — these fields existed on the model but were never written).
    private func closeCurrentSegment(at date: Date = Date()) {
        guard !segments.isEmpty else { return }
        let index = segments.count - 1
        segments[index].endDate = date
        segments[index].steps = max(0, totalSteps - segmentStartSteps)
        segments[index].distance = max(0, totalDistance - segmentStartDistance)
    }

    /// Snapshot of the segment timeline for persistence: closes the live segment,
    /// then runs the hygiene pass (min-length merge + same-type coalesce).
    /// Interval sessions pass `minimumDuration: 0` — plan-derived segments are
    /// ground truth and are never treated as noise.
    /// - Parameter logEnergy: emit the `SEG KCAL` bias instrumentation. Only the
    ///   final save passes `true` — the 15s crash checkpoint runs this same path
    ///   and would otherwise repeat every line dozens of times per workout,
    ///   making the log unusable for the walk-vs-run bias measurement it exists
    ///   for (plan item 8). The numbers are written to the checkpoint either way.
    private func finalizedSegments(logEnergy: Bool = false) -> [ActivitySegment] {
        let now = Date()
        var snapshot = segments

        if awaitingSegmentOpen {
            // No segment is open: we are between the workout/resume start and the
            // first confident classification. Everything already in `segments` is
            // correctly closed — appending a provisional span typed with the last
            // known activity keeps the timeline whole instead of leaving a hole.
            // If it is shorter than the minimum the hygiene pass folds it away.
            if let start = currentSegmentStartTime, now.timeIntervalSince(start) > 0 {
                snapshot.append(ActivitySegment(activityType: currentActivity,
                                                startDate: start,
                                                endDate: now,
                                                steps: max(0, totalSteps - segmentStartSteps),
                                                distance: max(0, totalDistance - segmentStartDistance)))
            }
        } else if let index = snapshot.indices.last {
            snapshot[index].endDate = now
            snapshot[index].steps = max(0, totalSteps - segmentStartSteps)
            snapshot[index].distance = max(0, totalDistance - segmentStartDistance)
        }

        let result = SegmentHygiene.finalize(
            snapshot,
            minimumDuration: workoutMode == .interval ? 0 : SegmentHygiene.minimumSegmentDuration,
            now: now
        )
        if result.absorbed > 0 || result.coalesced > 0 {
            logger.info("SEG FINALIZE: \(snapshot.count) raw -> \(result.segments.count) kept (absorbed \(result.absorbed) under \(Int(SegmentHygiene.minimumSegmentDuration))s, coalesced \(result.coalesced))")
        }
        return annotateWithEnergy(result.segments, now: now, log: logEnergy)
    }

    // MARK: - Per-phase Energy Attribution (Phase 2 / CE3, CE5)

    /// Stamps average HR, ShuttlX's MET estimate and Apple's summed
    /// `activeEnergyBurned` onto each finalized segment.
    ///
    /// Runs **after** the hygiene pass, not during recording: absorbing a blip or
    /// coalescing two segments changes the time range the numbers belong to, and
    /// re-deriving from the ledger is both simpler and more correct than trying to
    /// merge partial calorie sums. It is also idempotent, which matters because
    /// this path runs on every 15s checkpoint as well as the final save.
    private func annotateWithEnergy(_ segments: [ActivitySegment], now: Date, log: Bool) -> [ActivitySegment] {
        guard !segments.isEmpty else { return segments }

        // Fold in the still-open pause (checkpoints are written from
        // applyPauseState, i.e. while paused) without mutating the live ledger.
        var ledger = metricsLedger
        if let pauseStart = pauseStartDate, now > pauseStart {
            ledger.recordPause(from: pauseStart, to: now)
        }

        // Gym-recovery sessions run as functionalStrengthTraining; a wrist flail
        // classified as "running" there must not be charged a 9.8 running MET, so
        // the whole session is costed at the cross-training MET instead.
        let sport: WorkoutSport = workoutMode == .gymRecovery ? .crossTraining : (activeTemplate?.sportType ?? .running)
        let configName = workoutMode == .gymRecovery ? "functionalStrengthTraining" : sport.rawValue
        var annotated: [ActivitySegment] = []
        annotated.reserveCapacity(segments.count)

        for segment in segments {
            var s = segment
            let end = s.endDate ?? now
            let activeDuration = ledger.activeDuration(from: s.startDate, to: end)
            let avgHR = ledger.averageHeartRate(from: s.startDate, to: end)
            let appleKcal = ledger.activeEnergy(from: s.startDate, to: end)
            let shuttlxKcal = CalorieEstimationEngine.estimateSegment(
                activity: s.activityType,
                sport: sport,
                activeDurationSeconds: activeDuration,
                averageHeartRate: avgHR,
                anthropometrics: anthropometrics
            )

            s.averageHeartRate = avgHR
            s.estimatedCalories = shuttlxKcal
            s.activeEnergyCalories = appleKcal
            annotated.append(s)

            guard log else { continue }

            // Plan item 8 — bias instrumentation. Grep `SEG KCAL` after logging the
            // same walk under a `.walking` vs `.running` configuration to measure
            // how far Apple's single-activity-type model drifts on walk phases.
            // `config=` is the HKWorkoutConfiguration activity type the whole
            // session ran under; `met=` is what ShuttlX charged this phase.
            let delta: String = {
                guard let a = appleKcal, let s = shuttlxKcal else { return "n/a" }
                let d = s - a
                let pct = a > 0 ? (d / a) * 100 : 0
                return String(format: "%+.1f (%+.0f%%)", d, pct)
            }()
            logger.info("""
                SEG KCAL [\(s.activityType.rawValue)] config=\(configName) mode=\(String(describing: self.workoutMode)) \
                dur=\(String(format: "%.0f", activeDuration))s hr=\(avgHR.map { String(format: "%.0f", $0) } ?? "n/a") \
                met=\(String(format: "%.1f", CalorieEstimationEngine.met(for: s.activityType, sport: sport))) \
                weight=\(self.anthropometrics.weightKg.map { String(format: "%.1f", $0) } ?? "n/a")kg \
                age=\(self.anthropometrics.age.map(String.init) ?? "n/a") \
                shuttlx=\(shuttlxKcal.map { String(format: "%.1f", $0) } ?? "n/a") \
                apple=\(appleKcal.map { String(format: "%.1f", $0) } ?? "n/a") delta=\(delta)
                """)
        }

        if log {
            // One roll-up line per workout: the run-vs-walk split is the number the
            // bias experiment compares across a `.walking`- and a `.running`-
            // configured recording of the same route.
            func total(_ activity: DetectedActivity, _ pick: (ActivitySegment) -> Double?) -> Double {
                annotated.filter { $0.activityType == activity }.compactMap(pick).reduce(0, +)
            }
            func seconds(_ activity: DetectedActivity) -> Int {
                Int(annotated.filter { $0.activityType == activity }.reduce(0) { $0 + $1.duration })
            }
            logger.info("""
                SEG KCAL SUMMARY config=\(configName) segments=\(annotated.count) \
                run=\(seconds(.running))s/shuttlx \(String(format: "%.1f", total(.running) { $0.estimatedCalories }))/apple \(String(format: "%.1f", total(.running) { $0.activeEnergyCalories })) \
                walk=\(seconds(.walking))s/shuttlx \(String(format: "%.1f", total(.walking) { $0.estimatedCalories }))/apple \(String(format: "%.1f", total(.walking) { $0.activeEnergyCalories })) \
                sessionApple=\(String(format: "%.1f", self.totalCaloriesAccumulated))
                """)
        }

        return annotated
    }

    /// Sum of the per-segment ShuttlX MET estimates. Nil when body mass is
    /// unknown (no segment carries an estimate) — `TrainingSession.caloriesBurned`
    /// still holds Apple's whole-session number in that case.
    private func shuttlxEstimatedCalories(for segments: [ActivitySegment]) -> Double? {
        let values = segments.compactMap { $0.estimatedCalories }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
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
                    // From here on a 0 spm reading means "not stepping", not
                    // "pedometer hasn't reported yet" — the classifier needs the
                    // distinction (see cadenceForClassification).
                    self.hasCadenceSample = true
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

        // Rolling pace from a sliding 30s window of (wall clock, distance)
        // samples. Guards: workout >= 20s old, distance >= 0.05km, window
        // spans >= 5s and >= 5m. When guards fail before publishing, keep
        // currentPace nil; when they fail after publishing, keep last value.
        let now = Date()
        // Pause-corrected wall-clock workout age — same formula updateElapsedTime()
        // uses, but computed here so a stalled tick can't affect the guard.
        let workoutAge = workoutStartTime.map { now.timeIntervalSince($0) - accumulatedPauseTime } ?? elapsedTime
        paceWindowSamples.append((time: now, distance: distanceKm))
        let cutoff = now.addingTimeInterval(-paceWindowSec)
        paceWindowSamples.removeAll { $0.time < cutoff }
        if workoutAge < 20 || distanceKm < 0.05 {
            currentPace = nil
        } else if let oldest = paceWindowSamples.first {
            let dt = now.timeIntervalSince(oldest.time)
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
        // S-4: use Task { @MainActor } to hop to the main actor before touching
        // @MainActor-isolated state. The closure is @Sendable (DispatchSource handler)
        // so direct access would be a data race — latent today but a hard error under
        // Swift 6 strict concurrency. Every other timer handler in this file already
        // uses this pattern (see startDisplayTimer).
        t.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.hasReceivedHRSample, self.isWorkoutActive, !self.isPaused {
                    self.noHeartRateDetected = true
                    self.logger.warning("No heart rate sample after \(self.noHRDetectedAfter)s — surfacing banner")
                }
            }
        }
        noHRTimer = t
        t.resume()
    }

    nonisolated private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let bpmValues = quantitySamples.map { $0.quantity.doubleValue(for: bpmUnit) }
        // Keep the timestamps too — the session accumulators below discard them,
        // and per-segment averages cannot be reconstructed afterwards.
        let timedValues: [(date: Date, bpm: Double)] = quantitySamples.map {
            ($0.startDate, $0.quantity.doubleValue(for: bpmUnit))
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // First real sample — clear any "no HR" banner and stop the watchdog.
            self.hasReceivedHRSample = true
            if self.noHeartRateDetected { self.noHeartRateDetected = false }
            // Only include samples taken while workout is not paused
            if !self.isPaused {
                self.heartRateSampleSum += bpmValues.reduce(0, +)
                self.heartRateSampleCount += bpmValues.count
                for sample in timedValues {
                    self.metricsLedger.recordHeartRate(bpm: sample.bpm, at: sample.date)
                }
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
        // Apple's energy samples are already personally calibrated (HR + motion +
        // Health profile) and each carries its own start/end. Bucketing them by
        // segment range is therefore free per-phase energy — CE5 / plan item 7.
        let spans: [(start: Date, end: Date, kcal: Double)] = quantitySamples.map {
            ($0.startDate, $0.endDate, $0.quantity.doubleValue(for: kcalUnit))
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.totalCaloriesAccumulated += batchTotal
            self.calories = Int(self.totalCaloriesAccumulated)
            for span in spans {
                self.metricsLedger.recordEnergy(kcal: span.kcal, from: span.start, to: span.end)
            }
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

        let segmentsCopy = finalizedSegments()

        let backupSplits: [KmSplitData]? = completedKmSplits.isEmpty ? nil : completedKmSplits.map {
            KmSplitData(kmNumber: $0.kmNumber, splitTime: $0.splitTime, cumulativeTime: $0.cumulativeTime)
        }

        // Calculate total pause time including current pause if active
        let totalPause = accumulatedPauseTime + (pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)

        var session = TrainingSession(
            id: currentSessionID,
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
        // ShuttlX's own phase-aware total, alongside Apple's `caloriesBurned`.
        session.estimatedCalories = shuttlxEstimatedCalories(for: segmentsCopy)

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

    // MARK: - Launch Recovery

    /// Launch-time recovery work (orphaned HKWorkoutSession + crashed-workout
    /// backup), kept as a Task so `startWorkoutAfterAuth()` can await it. Without
    /// this serialization a cold-launch start races the recovery and both sessions
    /// end up live in HealthKit.
    private(set) var launchRecoveryTask: Task<Void, Never>?

    /// Starts launch recovery exactly once. Called from the app root's onAppear.
    func beginLaunchRecovery() {
        guard launchRecoveryTask == nil else { return }
        logger.info("Launch recovery starting")
        launchRecoveryTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.recoverOrphanedHKSession()
            if !self.isWorkoutActive, let recovered = self.recoverCrashedWorkout() {
                self.logger.info("Recovering crashed workout session")
                self.saveRecoveredSession(recovered)
            }
            self.logger.info("Launch recovery complete")
        }
    }

    /// Finalize an HKWorkoutSession orphaned by a crash or watchdog kill so its
    /// collected data still reaches HealthKit. Without this, a workout whose
    /// process died mid-run never writes an HKWorkout at all — the session stays
    /// live inside HealthKit with no owner. Called once at app launch, and awaited
    /// by any workout start that happens before it finishes.
    func recoverOrphanedHKSession() async {
        #if os(watchOS)
        guard let session = await recoverActiveWorkoutSession(timeout: 5) else { return }
        // RC-2 safety net, tightened: the precise question is "have WE created a
        // session yet?", which `workoutSession == nil` answers exactly. The old
        // `!isStarting` clause made recovery bail out precisely when it mattered —
        // the deep-link start path sets isStarting BEFORE awaiting us, so a genuine
        // orphan was left un-finalized next to the new session.
        guard !isWorkoutActive, workoutSession == nil else {
            logger.warning("Orphaned HK session found while a workout is active — ignoring")
            return
        }
        logger.warning("Recovered orphaned HKWorkoutSession (state \(session.state.rawValue)) — finalizing so the workout reaches Health")
        let builder = session.associatedWorkoutBuilder()
        if session.state == .running || session.state == .paused {
            session.end()
        }
        do {
            try await builder.endCollection(at: Date())
            let workout = try await builder.finishWorkout()
            logger.info("Orphaned workout finalized to HealthKit: \(workout?.uuid.uuidString ?? "unknown")")
        } catch {
            logger.error("Failed to finalize recovered HK session: \(error.localizedDescription)")
        }
        #endif
    }

    #if os(watchOS)
    /// `recoverActiveWorkoutSession` with a hard deadline. A workout start now
    /// awaits launch recovery, so a HealthKit daemon that never calls back must not
    /// be able to block the start button forever.
    private func recoverActiveWorkoutSession(timeout: TimeInterval) async -> HKWorkoutSession? {
        let store = healthStore
        let logger = self.logger
        return await withCheckedContinuation { (continuation: CheckedContinuation<HKWorkoutSession?, Never>) in
            // The HK callback and the timeout can race; the lock guarantees exactly
            // one resume (a double resume traps).
            let hasResumed = OSAllocatedUnfairLock(initialState: false)
            let resumeOnce: (HKWorkoutSession?) -> Bool = { session in
                let already = hasResumed.withLock { done -> Bool in
                    if done { return true }
                    done = true
                    return false
                }
                guard !already else { return false }
                continuation.resume(returning: session)
                return true
            }
            store.recoverActiveWorkoutSession { session, error in
                if let error = error {
                    logger.error("recoverActiveWorkoutSession failed: \(error.localizedDescription)")
                    _ = resumeOnce(nil)
                    return
                }
                _ = resumeOnce(session)
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                if resumeOnce(nil) {
                    logger.warning("recoverActiveWorkoutSession did not call back within \(Int(timeout))s — continuing without orphan recovery")
                }
            }
        }
    }
    #endif


    /// Snapshot current metrics into a WorkoutSummary BEFORE calling stopWorkout().
    /// stopWorkout() zeros all published state, so the summary must be captured first.
    /// Used by both the user-initiated "Save & Finish" path and the interval engine
    /// auto-complete path (when engine.isComplete fires during updateElapsedTime).
    func buildCurrentSummary() -> WorkoutSummary {
        let captures = completedCaptures
        let avgHRR1: Double? = {
            let vals = captures.compactMap { $0.hrr1 }
            guard !vals.isEmpty else { return nil }
            return Double(vals.reduce(0, +)) / Double(vals.count)
        }()
        return WorkoutSummary(
            duration: elapsedTime,
            distance: totalDistance,
            avgHeartRate: averageHeartRate,
            calories: calories,
            steps: totalSteps,
            avgPace: currentPace,
            splitsCount: lastCompletedKm,
            completedSets: workoutMode == .gymRecovery ? captures.count : nil,
            averageHRR1: avgHRR1,
            bodyMassUnavailable: bodyMassUnavailable
        )
    }

    func saveWorkoutData() {
        guard let startTime = workoutStartTime else { return }

        let segmentsCopy = finalizedSegments(logEnergy: true)

        let splits: [KmSplitData]? = completedKmSplits.isEmpty ? nil : completedKmSplits.map {
            KmSplitData(kmNumber: $0.kmNumber, splitTime: $0.splitTime, cumulativeTime: $0.cumulativeTime)
        }

        // Calculate total pause time including current pause if active
        let totalPauseTime = accumulatedPauseTime + (pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)

        var session = TrainingSession(
            id: currentSessionID,
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
        // Phase-aware total from the per-segment MET estimates (Phase 2). Apple's
        // whole-session number stays in `caloriesBurned`; nothing is overwritten.
        session.estimatedCalories = shuttlxEstimatedCalories(for: segmentsCopy)

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
        // Phase 3 (interop): publish the SAME finalized phase timeline that is
        // persisted app-side, so HealthKit and TrainingSession.segments can never
        // disagree about where the walk/run boundaries were.
        let capturedPhaseSegments = segmentsCopy
        let capturedWorkoutStart = startTime
        let capturedLogger = logger
        // Nil out builder/route references before async work so no other call reuses them
        workoutBuilder = nil
        #endif
        routeBuilder = nil

        // Finalize HKLiveWorkoutBuilder → saves HKWorkout to HealthKit, then attach route
        Task {
            #if os(watchOS)
            if let builder = builderToFinish {
                do {
                    // End date is fixed up front: it bounds the phase activities and
                    // .segment events written below, and HealthKit requires both to
                    // sit inside the workout's own interval.
                    let endDate = Date()

                    // Phase 3 / plan items 9-10 (optional interop). Deliberately
                    // ahead of the mandatory metadata + endCollection + finishWorkout
                    // sequence and fully self-contained: it never throws, so a
                    // rejected phase write can never cost the user their workout.
                    await WorkoutPhaseHealthKitWriter.write(
                        segments: capturedPhaseSegments,
                        configuration: builder.workoutConfiguration,
                        builder: builder,
                        bounds: WorkoutPhaseHealthKitWriter.Bounds(
                            start: builder.startDate ?? capturedWorkoutStart,
                            end: endDate
                        ),
                        logger: capturedLogger
                    )

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
    /// Seeds a RUNNING free-run state at an arbitrary elapsed time so the
    /// wall-clock timer branch (`timerReferenceDate != nil`) can be captured in the
    /// simulator without waiting an hour. Snapshot/QA only.
    func applyFreeRunPreviewSnapshot(elapsed: TimeInterval) {
        workoutMode = .freeRun
        workoutName = "Free Run"
        intervalEngine = nil
        isWorkoutActive = true
        isPaused = false
        elapsedTime = elapsed
        // The running invariant: reference = now - elapsed.
        timerReferenceDate = Date().addingTimeInterval(-elapsed)
        totalDistance = 12.84
        totalSteps = 15_402
        currentPace = 6 * 60 + 47
        currentCadence = 162
        heartRate = 138
        calories = 812
    }

    /// Freezes an already-seeded snapshot the way `pauseWorkout()` does, without
    /// touching HealthKit or the tick timer: `isPaused` + a nil
    /// `timerReferenceDate` (which is what makes the views fall back to static
    /// elapsed text). Snapshot/QA only — `timerReferenceDate` is `private(set)`
    /// in production, and it stays that way.
    func applyPausedPreviewState() {
        isPaused = true
        timerReferenceDate = nil
    }

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
