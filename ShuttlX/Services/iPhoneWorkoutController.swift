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
    private let haptics = iPhoneHapticPlayer()
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX", category: "iPhoneWorkoutController")

    // Sensor sources
    private let pedometer = CMPedometer()
    private let motion = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private var routePoints: [RoutePoint] = []
    private var locationDelegate: LocationProxy?

    weak var dataManager: DataManager?

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

    func startFreeRun() {
        guard !isActive else { return }
        mode = .freeRun
        workoutName = "Free Run"
        beginCommonStart()
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
    }

    func startGymRecovery() {
        guard !isActive else { return }
        mode = .gymRecovery
        workoutName = "Gym Recovery"
        var config = SegmenterConfig()
        config.profile = .cardiacRehab
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
    }

    private func beginCommonStart() {
        haptics.prepare()
        let now = Date()
        workoutStartTime = now
        accumulatedPauseTime = 0
        pauseStartDate = nil
        elapsedTime = 0
        totalDistance = 0
        totalSteps = 0
        currentPace = nil
        currentCadence = 0
        routePoints = []
        heartRateMonitor.reset()
        heartRateMonitor.start(from: now)
        startPedometer(from: now)
        if mode != .gymRecovery { startLocationUpdates() }
        startDisplayTimer()
        isActive = true
        isPaused = false
        logger.info("Workout started — mode=\(String(describing: self.mode))")
    }

    func pause() {
        guard isActive, !isPaused else { return }
        isPaused = true
        pauseStartDate = Date()
        stopDisplayTimer()
        pedometer.stopUpdates()
        locationManager.stopUpdatingLocation()
        if mode == .gymRecovery { motion.stopActivityUpdates() }
    }

    func resume() {
        guard isActive, isPaused else { return }
        if let start = pauseStartDate {
            accumulatedPauseTime += Date().timeIntervalSince(start)
            pauseStartDate = nil
        }
        isPaused = false
        if let start = workoutStartTime { startPedometer(from: start) }
        if mode != .gymRecovery { startLocationUpdates() }
        if mode == .gymRecovery { startMotionUpdates() }
        startDisplayTimer()
    }

    /// Builds the `TrainingSession`, hands it to `DataManager`, tears down all
    /// sensors. Returns the session so the view can present a summary.
    @discardableResult
    func finish() -> TrainingSession? {
        guard isActive, let startTime = workoutStartTime else { return nil }
        let totalPause = accumulatedPauseTime + (pauseStartDate.map { Date().timeIntervalSince($0) } ?? 0)
        let duration = Date().timeIntervalSince(startTime) - totalPause

        var session = TrainingSession(
            startDate: startTime,
            endDate: Date(),
            duration: duration,
            averageHeartRate: heartRateMonitor.sampleCount > 0 ? Double(heartRateMonitor.average) : nil,
            maxHeartRate: heartRateMonitor.maxBPM > 0 ? Double(heartRateMonitor.maxBPM) : nil,
            caloriesBurned: nil,    // calories not yet tracked iPhone-side; HKWorkout writer will fill
            distance: totalDistance > 0 ? totalDistance : nil,
            totalSteps: totalSteps > 0 ? totalSteps : nil,
            segments: [],
            route: routePoints.isEmpty ? nil : routePoints,
            kmSplits: nil
        )

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

        dataManager?.handleReceivedSessions([session])
        tearDown()
        return session
    }

    /// Discards the in-progress workout. No `TrainingSession` is saved.
    func cancel() {
        guard isActive else { return }
        tearDown()
    }

    func skipStep() {
        guard mode == .interval, let engine = intervalEngine, !engine.isComplete else { return }
        // Fast-forward by ticking through the remaining time of the current step.
        let remaining = max(0, Int(engine.currentStepTimeRemaining.rounded(.up)))
        for _ in 0..<remaining {
            engine.tick(heartRate: heartRateMonitor.current, distance: totalDistance)
        }
    }

    // MARK: - Teardown

    private func tearDown() {
        stopDisplayTimer()
        heartRateMonitor.stop()
        pedometer.stopUpdates()
        locationManager.stopUpdatingLocation()
        motion.stopActivityUpdates()
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
                guard let self = self, let data = data else { return }
                self.totalSteps = data.numberOfSteps.intValue
                if let dist = data.distance {
                    self.totalDistance = dist.doubleValue / 1000.0
                    if self.totalDistance > 0 {
                        self.currentPace = self.elapsedTime / self.totalDistance
                    }
                }
                if let cadence = data.currentCadence {
                    self.currentCadence = Int(cadence.doubleValue * 60)
                }
            }
        }
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
            guard let self = self else { return }
            self.routePoints.append(
                RoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp
                )
            )
        }
        locationDelegate = delegate
        locationManager.delegate = delegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }
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
