import Foundation
import Combine
import HealthKit
import CoreMotion
import CoreLocation
import os.log
import ShuttlXShared

/// iOS counterpart of `WatchWorkoutManager`. Drives a standalone iPhone-side
/// workout — no Apple Watch required. Supports three modes:
///   - `.freeRun`     — open-ended, just timer + HR + distance/route
///   - `.interval`    — driven by `ShuttlXShared.IntervalEngine` (countdown
///                      per step with transition haptics)
///   - `.gymRecovery` — driven by `ShuttlXShared.RecoverySegmenter` with the
///                      dual-condition (stationary ≥15s AND HR rise ≥6 BPM)
///                      station detection; same algorithm as the watch
///
/// HR comes from HealthKit (via `iOSHeartRateMonitor`) and works with any
/// paired device — Apple Watch when worn, Powerbeats Pro 2, future AirPods
/// Pro 3, third-party straps.
///
/// On finish, builds a `TrainingSession` and hands it to
/// `DataManager.handleReceivedSessions(_:)` — same store the watch writes to,
/// so the workout shows up in iOS history alongside watch-driven sessions.
/// Apple Health (HKWorkout) write is **deferred to a follow-up commit** —
/// this controller produces the in-app record only.
@MainActor
final class iPhoneWorkoutController: ObservableObject {

    // MARK: - Mode

    enum Mode { case freeRun, interval, gymRecovery }

    @Published private(set) var mode: Mode = .freeRun
    @Published private(set) var workoutName: String = ""
    @Published private(set) var isActive: Bool = false
    @Published private(set) var isPaused: Bool = false

    /// Writable presentation flag — entry points (Dashboard, TemplateList,
    /// PlanDetail) call a `present*` convenience method which both starts the
    /// workout AND flips this to true. The root view binds a
    /// `.fullScreenCover(isPresented:)` to it. Finish/Cancel flip it back to
    /// false (in `tearDown`) so the cover auto-dismisses without callers
    /// needing to track presentation state themselves.
    @Published var isPresentingTimer: Bool = false
    /// Short explanation shown on the timer when the watch could not join this workout.
    @Published private(set) var watchNotice: String?

    // MARK: - Common metrics

    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var totalDistance: Double = 0       // km
    @Published private(set) var totalSteps: Int = 0
    @Published private(set) var currentPace: TimeInterval?       // seconds per km, average
    @Published private(set) var currentCadence: Int = 0          // spm

    // HR is owned by the monitor; the view binds directly to it. We re-expose
    // a couple of conveniences for the metric pills.
    let heartRateMonitor: iOSHeartRateMonitor = .init()

    // MARK: - Interval mode

    @Published var intervalEngine: IntervalEngine?
    private var intervalEngineCancellables: Set<AnyCancellable> = []
    private var activeTemplate: WorkoutTemplate?

    // MARK: - Gym recovery mode

    @Published private(set) var recoveryState: SegmentState = .idle
    @Published private(set) var stationElapsedTime: TimeInterval = 0
    @Published private(set) var restElapsedTime: TimeInterval = 0
    @Published private(set) var recoverySetNumber: Int = 0
    @Published private(set) var latestHRR1: Int?
    @Published private(set) var latestHRR2: Int?
    @Published private(set) var completedCaptures: [HRRCapture] = []
    private var recoverySegmenter: RecoverySegmenter?
    // Fully qualified — the iOS app target also defines a `DetectedActivity`
    // (in ShuttlX/Models/ActivitySegment.swift) which would shadow the Shared
    // one. The segmenter expects the Shared version, so we pin it explicitly.
    private var lastDetectedActivity: ShuttlXShared.DetectedActivity = .unknown

    // MARK: - Private state

    private var workoutStartTime: Date?
    private var accumulatedPauseTime: TimeInterval = 0
    private var pauseStartDate: Date?
    private var displayTimer: DispatchSourceTimer?
    // Cadence fallback (used when CMPedometer.currentCadence returns nil)
    private var lastCadenceStepCount: Int = 0
    private var lastCadenceTimestamp: Date?
    // Rolling pace window — previously `currentPace = elapsedTime / totalDistance`
    // was cumulative-average from t=0, which got pinned at ~10:00/km due to the
    // pedometer warmup ratio at the workout's first 30s. Rolling window over the
    // last 30 seconds reflects actual current speed.
    private var paceWindowSamples: [(time: TimeInterval, distance: Double)] = []
    private let paceWindowSec: TimeInterval = 30

    // GPS/pedometer fusion — GPS distance is preferred when the fix quality is
    // good; pedometer distance is the fallback (treadmill, indoor, poor signal).
    //
    // Tuning constants (named so they can be adjusted without hunting magic numbers):
    /// Horizontal accuracy threshold above which a GPS sample is discarded (metres).
    private let gpsAccuracyThresholdM: Double = 20
    /// Maximum inter-sample displacement allowed before treating it as a teleport (metres).
    private let gpsTeleportFilterM: Double = 100
    /// Minimum inter-sample displacement required to count as real movement (metres).
    private let gpsNoiseFloorM: Double = 1
    /// Number of consecutive valid samples required before GPS is considered usable.
    private let gpsWarmupSamples: Int = 3

    private var gpsAccumulatedDistanceKm: Double = 0
    private var lastGPSLocation: CLLocation?
    private var gpsHasUsableFix: Bool = false
    private var gpsValidSampleCount: Int = 0
    private var fusion = DistanceFusion()
    private var lastGPSFixAt: Date?

    private let haptics = iPhoneHapticPlayer()
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "iPhoneWorkoutController")

    // Sensor sources
    private let pedometer = CMPedometer()
    private let motion = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private var routePoints: [RoutePoint] = []
    /// ~8 h at 1 point per 5 s; past this the route is re-sampled evenly down to `routeThinTarget` (checkpoint bounded).
    static let maxRoutePoints = 6000
    static let routeThinTarget = 4500
    private var locationDelegate: LocationProxy?

    weak var dataManager: DataManager?

    // MARK: - Watch link, steps offset, checkpoint

    /// A workout recorded on the iPhone shorter than this is not saved (an accidental start).
    static let minimumSavedDuration: TimeInterval = 5

    /// Stable id from start to save: the checkpoint, the placeholder and the final session share it.
    private var sessionID = UUID()
    /// The watch was asked to record this same workout. Then pause/resume/stop reach it, and the watch
    /// session is authoritative: ours is stored only as a placeholder that the watch session replaces.
    private(set) var watchLinked = false
    private var lastCheckpointAt = Date()
    /// Steps / pedometer km before the current pedometer run (a pause restarts the pedometer from the resume time).
    private var stepOffset = 0
    private var pedometerKmOffset = 0.0
    private var pedometerKm = 0.0

    /// Set at launch when the previous run was interrupted mid-workout; the app offers to save or discard it.
    @Published var interruptedWorkout: PhoneWorkoutCheckpoint?

    // MARK: - Convenience start-and-present helpers (used by entry-point views)

    /// Start a free-run workout AND present the timer view. Use from buttons
    /// in DashboardView / etc. so the caller doesn't have to manage cover state.
    func presentFreeRun() {
        guard !isActive else { isPresentingTimer = true; return }
        startFreeRun()
        isPresentingTimer = true
    }

    func presentInterval(template: WorkoutTemplate) {
        guard !isActive else { isPresentingTimer = true; return }
        startInterval(template: template)
        isPresentingTimer = true
    }

    func presentGymRecovery() {
        guard !isActive else { isPresentingTimer = true; return }
        startGymRecovery()
        isPresentingTimer = true
    }

    // MARK: - Lifecycle

    /// Stops the iPhone workout in response to the Watch stopping first.
    /// Saves and dismisses the timer, mirroring what the user would do manually.
    func remoteStop() {
        guard isActive, watchLinked else { return }   // a stop of some other watch workout is not ours
        _ = finish(notifyWatch: false)   // the watch stopped first; do not send it a second stop
        isPresentingTimer = false
    }

    func startFreeRun() {
        guard !isActive else { return }
        mode = .freeRun
        workoutName = "Free Run"
        beginCommonStart()
        linkWatch(mode: "freeRun")
    }

    func startInterval(template: WorkoutTemplate) {
        guard !isActive else { return }
        mode = .interval
        workoutName = template.name
        activeTemplate = template

        // Build the Shared engine with our iPhone haptic player and the
        // Combine-forwarding pattern shipped in commit 080b57a — the engine's
        // objectWillChange is wired into ours so the timer view never freezes.
        let engine = IntervalEngine(haptics: haptics)
        let steps = template.allSteps.map { step in
            IntervalStepDescriptor(
                type: ShuttlXShared.IntervalType(rawValue: step.type.rawValue) ?? .work,
                label: step.label,
                duration: step.duration
            )
        }
        engine.configure(steps: steps, templateName: template.name, templateID: template.id)
        intervalEngine = engine
        intervalEngineCancellables.removeAll()
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &intervalEngineCancellables)

        beginCommonStart()
        linkWatch(mode: "interval", template: template)
    }

    func startGymRecovery() {
        guard !isActive else { return }
        mode = .gymRecovery
        workoutName = "Gym Recovery"
        var config = SegmenterConfig()
        config.profile = .cardiacRehab
        // Sprint-7 default — manualStationsOnly is already true, but make it
        // explicit at the call site so a future SegmenterConfig flip never
        // silently regresses the iOS gym-recovery UX.
        config.manualStationsOnly = true
        recoverySegmenter = RecoverySegmenter(config: config)
        recoveryState = .idle
        stationElapsedTime = 0
        restElapsedTime = 0
        recoverySetNumber = 0
        latestHRR1 = nil
        latestHRR2 = nil
        completedCaptures = []
        startMotionUpdates()
        beginCommonStart()
        linkWatch(mode: "gymRecovery")
    }

    /// Asks the watch to record the same workout. It counts as linked only after the watch answers
    /// `workoutStarted` for this workout's id; an answer of "already recording" or no answer within a few
    /// seconds leaves it unlinked, so Discard / Stop on the phone never touch a recording the phone did not start.
    private func linkWatch(mode: String, template: WorkoutTemplate? = nil) {
        let id = sessionID
        watchNotice = nil
        PhoneSyncCoordinator.shared.startWatchWorkout(mode: mode, template: template, phoneSessionId: id) { [weak self] reply in
            guard let self, self.isActive, self.sessionID == id else { return }
            switch reply {
            case .started?:
                self.watchLinked = true
                if self.isPaused { PhoneSyncCoordinator.shared.pauseWatchWorkout() }
                self.writeCheckpoint()
            case .ignored?:
                self.watchNotice = "Your watch did not start this workout (it may already be recording, or Health is not allowed there)."
            case nil:
                break
            }
        }
    }

    /// Live Activity buttons while a workout recorded on the iPhone is running. False = not ours (a watch-only workout).
    func handleLiveActivityControl(_ command: String) -> Bool {
        guard isActive else { return false }
        switch command {
        case "pause": pause()
        case "resume": resume()
        case "stop": finish()
        case "show": isPresentingTimer = true
        default: return false
        }
        return true
    }

    private func beginCommonStart() {
        haptics.prepare()
        let now = Date()
        workoutStartTime = now
        sessionID = UUID()
        watchLinked = false
        lastCheckpointAt = now
        stepOffset = 0
        pedometerKmOffset = 0
        pedometerKm = 0
        accumulatedPauseTime = 0
        pauseStartDate = nil
        elapsedTime = 0
        totalDistance = 0
        totalSteps = 0
        currentPace = nil
        currentCadence = 0
        lastCadenceStepCount = 0
        lastCadenceTimestamp = nil
        paceWindowSamples.removeAll(keepingCapacity: true)
        gpsAccumulatedDistanceKm = 0
        lastGPSLocation = nil
        gpsHasUsableFix = false
        gpsValidSampleCount = 0
        fusion = DistanceFusion()
        lastGPSFixAt = nil
        routePoints = []
        heartRateMonitor.reset()
        heartRateMonitor.start(from: now)
        startPedometer(from: now)
        if mode != .gymRecovery { startLocationUpdates() }
        startDisplayTimer()
        isActive = true
        isPaused = false
        LiveActivityManager.shared.startActivity(activityType: lastDetectedActivity.rawValue)
        logger.info("Workout started — mode=\(String(describing: self.mode))")
    }

    func pause() {
        guard isActive, !isPaused else { return }
        isPaused = true
        pauseStartDate = Date()
        stopDisplayTimer()
        pedometer.stopUpdates()
        // The next pedometer run starts at the resume time; what was counted so far is the offset.
        stepOffset = totalSteps
        pedometerKmOffset = pedometerKm
        stopLocationUpdates()
        if mode == .gymRecovery { motion.stopActivityUpdates() }
        if watchLinked { PhoneSyncCoordinator.shared.pauseWatchWorkout() }
        writeCheckpoint()
    }

    func resume() {
        guard isActive, isPaused else { return }
        if let start = pauseStartDate {
            accumulatedPauseTime += Date().timeIntervalSince(start)
            pauseStartDate = nil
        }
        isPaused = false
        // Steps and distance taken while paused are not counted: restart from now.
        startPedometer(from: Date())
        lastCadenceTimestamp = nil
        lastGPSLocation = nil   // the first fix after the pause must not add the ground covered while paused
        if mode != .gymRecovery { startLocationUpdates() }
        if mode == .gymRecovery { startMotionUpdates() }
        startDisplayTimer()
        if watchLinked { PhoneSyncCoordinator.shared.resumeWatchWorkout() }
    }

    private func activeDuration(at now: Date) -> TimeInterval {
        guard let start = workoutStartTime else { return 0 }
        let paused = accumulatedPauseTime + (pauseStartDate.map { now.timeIntervalSince($0) } ?? 0)
        return max(0, now.timeIntervalSince(start) - paused)
    }

    /// The session as recorded so far (no side effects, used by finish and by the checkpoint).
    private func snapshotSession(at now: Date) -> TrainingSession? {
        guard let startTime = workoutStartTime else { return nil }
        var session = TrainingSession(
            id: sessionID,
            startDate: startTime,
            endDate: now,
            duration: activeDuration(at: now),
            averageHeartRate: heartRateMonitor.sampleCount > 0 ? Double(heartRateMonitor.average) : nil,
            maxHeartRate: heartRateMonitor.maxBPM > 0 ? Double(heartRateMonitor.maxBPM) : nil,
            caloriesBurned: nil,    // calories not yet tracked iPhone-side; HKWorkout writer will fill
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: [],
            route: routePoints.isEmpty ? nil : routePoints,
            kmSplits: nil
        )
        if mode == .interval {
            session.templateID = activeTemplate?.id
            session.programName = activeTemplate?.name
        } else if mode == .gymRecovery {
            session.sessionMode = .gymRecovery
            session.programName = "Gym Recovery"
            session.recoveryReport = RecoveryReport(
                sets: completedCaptures.count,
                captures: completedCaptures,
                avgWorkHR: nil,
                avgRestHR: nil
            )
        }
        return session
    }

    /// Writes the recovery file (15 s cadence from `tick`, on pause, and when the app goes to the background).
    func writeCheckpoint() {
        let now = Date()
        lastCheckpointAt = now
        guard isActive, let session = snapshotSession(at: now) else { return }
        PhoneWorkoutCheckpoint(session: session, watchLinked: watchLinked, savedAt: now).writeAsync()
    }

    /// Tells the watch to stop (it saves its own session). Safe when it is not recording: the command is a no-op there.
    private func stopWatchIfLinked(_ notify: Bool) {
        if notify, watchLinked { PhoneSyncCoordinator.shared.stopWatchWorkout() }
    }

    /// Builds the `TrainingSession`, hands it to `DataManager`, tears down all
    /// sensors. Returns the session so the view can present a summary.
    ///
    /// With a linked watch the WATCH session is the authoritative record:
    /// - the watch is told to stop (`notifyWatch`; false when the watch itself stopped first),
    /// - a session of the same workout that already arrived (watch or Health) means ours is not saved,
    /// - otherwise ours is saved as a placeholder that the watch session replaces when it arrives
    ///   (`DataManager.handleReceivedSessions`), so there is never a second entry and a watch that
    ///   never delivers still leaves the phone's record.
    /// A workout shorter than `minimumSavedDuration` is not saved.
    @discardableResult
    func finish(notifyWatch: Bool = true) -> TrainingSession? {
        guard isActive else { return nil }
        let now = Date()
        guard var session = snapshotSession(at: now) else { return nil }
        stopWatchIfLinked(notifyWatch)

        guard session.duration >= Self.minimumSavedDuration else {
            logger.info("Workout shorter than \(Self.minimumSavedDuration)s not saved")
            tearDown()
            return nil
        }

        if mode == .interval, let engine = intervalEngine {
            let result = engine.stop(finalDistance: totalDistance)
            session.templateID = result.templateID
            session.programName = result.templateName
            session.completedIntervalResults = result.results.map { ir in
                CompletedInterval(
                    intervalType: IntervalType(rawValue: ir.intervalType.rawValue) ?? .work,
                    label: ir.label,
                    targetDuration: ir.targetDuration,
                    actualDuration: ir.actualDuration,
                    averageHeartRate: ir.averageHeartRate,
                    distance: ir.distance
                )
            }
        }

        if let dataManager {
            if watchLinked {
                if dataManager.watchRecordedAlready(session) {
                    logger.info("Watch already recorded this workout — phone session not saved")
                } else {
                    dataManager.markPhonePlaceholder(session.id)
                    dataManager.handleReceivedSessions([session])
                }
            } else {
                dataManager.handleReceivedSessions([session])
            }
        } else {
            logger.error("finish(): no DataManager — session \(session.id) kept only in the checkpoint")
            writeCheckpoint()
            tearDownKeepingCheckpoint()
            return session
        }
        tearDown()
        return session
    }

    /// Discards the in-progress workout. No `TrainingSession` is saved on the phone. A linked watch is told to
    /// discard its own recording too (`discardWorkout`).
    func cancel() {
        guard isActive else { return }
        if watchLinked { PhoneSyncCoordinator.shared.discardWatchWorkout() }
        tearDown()
    }

    // MARK: - Recovery after a kill

    /// Called once at launch (after `dataManager` is set). Looks for a checkpoint of an interrupted workout.
    func loadInterruptedWorkout() {
        guard !isActive, interruptedWorkout == nil else { return }
        interruptedWorkout = PhoneWorkoutCheckpoint.load()
    }

    func saveInterruptedWorkout() {
        guard let cp = interruptedWorkout else { return }
        interruptedWorkout = nil
        guard cp.session.duration >= Self.minimumSavedDuration else { PhoneWorkoutCheckpoint.removeAsync(); return }
        guard let dataManager else { logger.error("Recovered workout not saved: no DataManager"); return }
        if cp.watchLinked {
            if dataManager.watchRecordedAlready(cp.session) { PhoneWorkoutCheckpoint.removeAsync(); return }
            dataManager.markPhonePlaceholder(cp.session.id)
        }
        dataManager.handleReceivedSessions([cp.session])
        PhoneWorkoutCheckpoint.removeAsync()
    }

    func discardInterruptedWorkout() {
        interruptedWorkout = nil
        PhoneWorkoutCheckpoint.removeAsync()
    }

    // MARK: - Manual station control (gymRecovery)

    /// Patient tapped **Start Station** in the timer view.
    func manualStartStation() {
        guard mode == .gymRecovery, var seg = recoverySegmenter else { return }
        let events = seg.manualStartStation(hr: heartRateMonitor.current, now: Date())
        recoverySegmenter = seg
        processRecoveryEvents(events)
        publishRecoveryState()
        haptics.play(.workStart)
    }

    /// Patient tapped **End Station** in the timer view.
    func manualEndStation() {
        guard mode == .gymRecovery, var seg = recoverySegmenter else { return }
        let events = seg.manualEndStation(hr: heartRateMonitor.current, now: Date())
        recoverySegmenter = seg
        processRecoveryEvents(events)
        publishRecoveryState()
        haptics.play(.restStart)
    }

    private func publishRecoveryState() {
        guard let seg = recoverySegmenter else { return }
        let now = Date()
        restElapsedTime = seg.restStartTime.map { now.timeIntervalSince($0) } ?? 0
        stationElapsedTime = seg.workStartTime.map { now.timeIntervalSince($0) } ?? 0
        recoveryState = seg.state
        recoverySetNumber = seg.setNumber
    }

    func skipStep() {
        guard mode == .interval, let engine = intervalEngine, !engine.isComplete else { return }
        // Fast-forward by ticking through the remaining time of the current step.
        let remaining = max(0, Int(engine.currentStepTimeRemaining.rounded(.up)))
        for _ in 0..<remaining {
            engine.tick(heartRate: heartRateMonitor.current, distance: totalDistance)
        }
        // While paused the display timer is stopped, so `tick()` would never notice the last step ended and
        // the workout would sit finished-but-open. Finish from here.
        if engine.isComplete { finish() }
    }

    // MARK: - Teardown

    private func tearDown() {
        PhoneWorkoutCheckpoint.removeAsync()
        tearDownKeepingCheckpoint()
    }

    private func tearDownKeepingCheckpoint() {
        LiveActivityManager.shared.endActivity()
        stopDisplayTimer()
        heartRateMonitor.stop()
        pedometer.stopUpdates()
        stopLocationUpdates()
        motion.stopActivityUpdates()
        watchLinked = false
        watchNotice = nil
        PhoneSyncCoordinator.shared.endPhoneLink()
        stepOffset = 0
        pedometerKmOffset = 0
        pedometerKm = 0
        intervalEngineCancellables.removeAll()
        intervalEngine = nil
        recoverySegmenter = nil
        activeTemplate = nil
        isActive = false
        isPaused = false
        // Dismiss the timer cover that present*() raised.
        isPresentingTimer = false
        elapsedTime = 0
        totalDistance = 0
        totalSteps = 0
        currentPace = nil
        currentCadence = 0
        lastCadenceStepCount = 0
        lastCadenceTimestamp = nil
        paceWindowSamples.removeAll(keepingCapacity: true)
        gpsAccumulatedDistanceKm = 0
        lastGPSLocation = nil
        gpsHasUsableFix = false
        gpsValidSampleCount = 0
        fusion = DistanceFusion()
        lastGPSFixAt = nil
        routePoints = []
        workoutStartTime = nil
        accumulatedPauseTime = 0
        pauseStartDate = nil
        recoveryState = .idle
        stationElapsedTime = 0
        restElapsedTime = 0
        recoverySetNumber = 0
        latestHRR1 = nil
        latestHRR2 = nil
        completedCaptures = []
    }

    // MARK: - Display timer (1 Hz)

    private func startDisplayTimer() {
        stopDisplayTimer()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in self?.tick() }
        }
        displayTimer = t
        t.resume()
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    private func tick() {
        guard let start = workoutStartTime else { return }

        // Tick engines BEFORE writing elapsedTime — same order discipline that
        // unfroze the watch's interval timer in commit 080b57a.
        if mode == .interval, let engine = intervalEngine {
            engine.tick(heartRate: heartRateMonitor.current, distance: totalDistance)
            if engine.isComplete {
                finish()
                return
            }
        }

        if mode == .gymRecovery, var seg = recoverySegmenter {
            let maxHR = HeartRateZoneCalculator.fromSharedDefaults().estimatedMaxHR
            let events = seg.tick(
                hr: heartRateMonitor.current,
                activity: lastDetectedActivity,
                maxHR: maxHR,
                now: Date()
            )
            recoverySegmenter = seg
            processRecoveryEvents(events)
            let now = Date()
            restElapsedTime = seg.restStartTime.map { now.timeIntervalSince($0) } ?? 0
            stationElapsedTime = seg.workStartTime.map { now.timeIntervalSince($0) } ?? 0
            recoveryState = seg.state
            recoverySetNumber = seg.setNumber
        }

        elapsedTime = Date().timeIntervalSince(start) - accumulatedPauseTime
        if Date().timeIntervalSince(lastCheckpointAt) >= PhoneWorkoutCheckpoint.interval { writeCheckpoint() }

        LiveActivityManager.shared.updateActivity(
            elapsedTime: elapsedTime,
            heartRate: heartRateMonitor.current,
            distance: totalDistance,
            calories: 0,
            currentActivity: lastDetectedActivity.rawValue,   // "running" / "walking" / ... (was the workout's name)
            isPaused: isPaused,
            pace: currentPace ?? 0,
            zoneWord: HeartSafetySettings.load().zoneWord(hr: heartRateMonitor.current, age: DeviceManager.shared.userAge)
        )
    }

    private func processRecoveryEvents(_ events: [SegmenterEvent]) {
        for event in events {
            switch event {
            case .enteredWork(let setNum):
                latestHRR1 = nil
                latestHRR2 = nil
                _ = setNum    // already reflected via segmenter.setNumber
                haptics.play(.workStart)
            case .enteredRest(let peakHR, let setNumber, let restEntryTime):
                let capture = HRRCapture(setNumber: setNumber, peakHR: peakHR, restEntryTime: restEntryTime)
                completedCaptures.append(capture)
                haptics.play(.restStart)
            case .hrrCapture(let minuteMark, let hrDrop):
                guard !completedCaptures.isEmpty else { break }
                let idx = completedCaptures.count - 1
                if minuteMark == 1 {
                    completedCaptures[idx].hrAt60s = max(0, completedCaptures[idx].peakHR - hrDrop)
                    latestHRR1 = hrDrop
                    haptics.play(.complete)
                } else {
                    completedCaptures[idx].hrAt120s = max(0, completedCaptures[idx].peakHR - hrDrop)
                    latestHRR2 = hrDrop
                }
            case .restExited(let duration):
                if !completedCaptures.isEmpty {
                    completedCaptures[completedCaptures.count - 1].restDuration = duration
                }
            }
        }
    }

    // MARK: - Pedometer (steps + distance + cadence)

    private func startPedometer(from start: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: start) { [weak self] data, _ in
            Task { @MainActor [weak self] in
                guard let self = self, let data = data, !self.isPaused else { return }
                // The pedometer run starts at workout start or at the last resume; earlier runs are the offset.
                self.totalSteps = self.stepOffset + data.numberOfSteps.intValue
                if let dist = data.distance {
                    self.pedometerKm = self.pedometerKmOffset + dist.doubleValue / 1000.0
                    self.refreshDistance()
                }
                if let cadence = data.currentCadence {
                    // Preferred: Apple's instantaneous cadence (steps/sec → steps/min)
                    self.currentCadence = Int(cadence.doubleValue * 60)
                } else if let lastTS = self.lastCadenceTimestamp {
                    // Fallback: derive from step delta over a ≥3s window. Required
                    // because CMPedometer.currentCadence is nil for the first
                    // 30-60s of a workout + always nil in the simulator.
                    let dt = Date().timeIntervalSince(lastTS)
                    if dt >= 3.0 {
                        let stepDelta = self.totalSteps - self.lastCadenceStepCount
                        let derived = Int(Double(stepDelta) * 60.0 / dt)
                        self.currentCadence = max(0, derived)
                        self.lastCadenceStepCount = self.totalSteps
                        self.lastCadenceTimestamp = Date()
                    }
                } else {
                    self.lastCadenceStepCount = self.totalSteps
                    self.lastCadenceTimestamp = Date()
                }
            }
        }
    }

    /// GPS distance when its fix is usable, else the pedometer (`DistanceFusion`). Called from BOTH sources.
    private func refreshDistance() {
        totalDistance = fusion.update(gpsKm: gpsAccumulatedDistanceKm, pedometerKm: pedometerKm,
                                      gpsUsable: gpsHasUsableFix,
                                      gpsFixAge: lastGPSFixAt.map { Date().timeIntervalSince($0) })
        updateRollingPace()
    }

    /// Rolling pace from a sliding 30s window of (elapsedTime, totalDistance)
    /// samples. Replaces the cumulative-average `elapsedTime / totalDistance`
    /// that was pinned at ~10:00/km by the pedometer warmup spike.
    ///
    /// Guards:
    /// - Workout must be >= 20s old (avoid pedometer-warmup ratio)
    /// - Total distance must be >= 0.05 km
    /// - Window must span >= 5s and >= 5 m
    /// Falls back to `currentPace = nil` (renders as "—") when guards fail.
    private func updateRollingPace() {
        let now = elapsedTime
        paceWindowSamples.append((time: now, distance: totalDistance))
        let cutoff = now - paceWindowSec
        paceWindowSamples.removeAll { $0.time < cutoff }

        guard now >= 20,
              totalDistance >= 0.05,
              let oldest = paceWindowSamples.first else {
            currentPace = nil
            return
        }
        let dt = now - oldest.time
        let dDist = totalDistance - oldest.distance
        guard dt >= 5, dDist >= 0.005 else {
            // Not enough movement in the window to compute a meaningful pace.
            // Keep the last published value (don't flip to nil mid-workout).
            return
        }
        currentPace = dt / dDist
    }

    // MARK: - Motion (gym-recovery activity classification)

    private func startMotionUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let a = activity else { return }
            if a.walking { self.lastDetectedActivity = .walking }
            else if a.running { self.lastDetectedActivity = .running }
            else if a.stationary { self.lastDetectedActivity = .stationary }
            else { self.lastDetectedActivity = .unknown }
        }
    }

    // MARK: - Location (free-run + interval distance/route)

    private func startLocationUpdates() {
        let delegate = locationDelegate ?? LocationProxy { [weak self] location in
            Task { @MainActor [weak self] in
                guard let self = self, self.isActive, !self.isPaused else { return }

                // Always record the route point for the map.
                self.routePoints.append(
                    RoutePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        timestamp: location.timestamp
                    )
                )
                self.routePoints.thinEvenlyIfOver(Self.maxRoutePoints, to: Self.routeThinTarget)

                // GPS distance accumulation.
                // Discard samples whose horizontal accuracy is worse than the threshold.
                guard location.horizontalAccuracy >= 0,
                      location.horizontalAccuracy <= self.gpsAccuracyThresholdM else {
                    return
                }

                self.gpsValidSampleCount += 1
                self.lastGPSFixAt = Date()

                guard let last = self.lastGPSLocation else {
                    // First valid sample — anchor the reference point, do not
                    // accumulate distance yet.
                    self.lastGPSLocation = location
                    return
                }

                let deltaM = location.distance(from: last)

                // Filter teleports (GPS jump > teleportFilterM) and stationary
                // noise drift (delta < noiseFloorM).
                if deltaM >= self.gpsNoiseFloorM && deltaM < self.gpsTeleportFilterM {
                    self.gpsAccumulatedDistanceKm += deltaM / 1000.0
                }
                self.lastGPSLocation = location

                // Mark the fix as usable once enough consecutive valid samples
                // have arrived — prevents the pedometer→GPS handoff from
                // triggering on a single lucky reading at workout start.
                if !self.gpsHasUsableFix,
                   self.gpsValidSampleCount >= self.gpsWarmupSamples {
                    self.gpsHasUsableFix = true
                    self.logger.info("GPS fix usable after \(self.gpsValidSampleCount) valid samples — switching totalDistance to GPS")
                }
                // GPS alone must move the display too (no pedometer data: Motion denied, simulator).
                self.refreshDistance()
            }
        }
        locationDelegate = delegate
        locationManager.delegate = delegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        // Outdoor workouts keep recording the route with the screen off (UIBackgroundModes: location).
        // Only while a workout is active; `stopLocationUpdates` switches it off again.
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.startUpdatingLocation()
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = false
    }

    #if DEBUG
    /// Seed representative interval-workout state for snapshot/preview rendering
    /// only. Never called in production paths. Drives the Arcade handheld hero
    /// at stage 3/8 with a 01:48 countdown, HR 142, and live SPM/distance.
    func applyPreviewSnapshot() {
        mode = .interval
        workoutName = "5K INTERVAL"
        isActive = true
        isPaused = false
        elapsedTime = 22 * 60 + 14
        totalDistance = 3.42
        totalSteps = 4187
        currentPace = 5 * 60 + 38
        currentCadence = 168

        let engine = IntervalEngine()
        engine.configure(
            steps: [
                IntervalStepDescriptor(type: .warmup, label: "WARM UP", duration: 1),
                IntervalStepDescriptor(type: .work,   label: "RUN",     duration: 1),
                IntervalStepDescriptor(type: .work,   label: "RUN",     duration: 120),
                IntervalStepDescriptor(type: .rest,   label: "WALK",    duration: 60),
                IntervalStepDescriptor(type: .work,   label: "RUN",     duration: 120),
                IntervalStepDescriptor(type: .rest,   label: "WALK",    duration: 60),
                IntervalStepDescriptor(type: .work,   label: "RUN",     duration: 120),
                IntervalStepDescriptor(type: .cooldown, label: "COOL DOWN", duration: 120)
            ],
            templateName: "5K INTERVAL",
            templateID: nil
        )
        // Advance to step 3/8 (index 2) by exhausting the first two 1s steps.
        engine.tick(heartRate: 142, distance: 3.42)
        engine.tick(heartRate: 142, distance: 3.42)
        // Burn the 120s work step down to 01:48 remaining (120 - 108 = 12 ticks).
        for _ in 0..<12 { engine.tick(heartRate: 142, distance: 3.42) }
        intervalEngine = engine

        heartRateMonitor._previewSet(bpm: 142)
    }
    #endif
}

/// Thin `CLLocationManagerDelegate` shim so `iPhoneWorkoutController` can stay
/// a pure `@MainActor` controller without subclassing `NSObject`.
private final class LocationProxy: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let onLocation: (CLLocation) -> Void
    init(onLocation: @escaping (CLLocation) -> Void) { self.onLocation = onLocation }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations { onLocation(loc) }
    }
}
