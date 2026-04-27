import Foundation

// MARK: - Segmenter Profile

/// Determines which motion detection model the segmenter uses.
enum SegmenterProfile {
    /// Existing gym strength model: elevated HR + motion = work; stationary = rest.
    case gymStrength
    /// Cardiac rehab model: stationary/unknown = on machine (work); walking = between machines (rest).
    case cardiacRehab
}

// MARK: - Segmenter State

enum SegmentState: String {
    case idle    // no active work or rest period detected
    case work    // user is on a machine / performing a set
    case rest    // user is between machines / resting
}

// MARK: - Events emitted by the segmenter each tick

enum SegmenterEvent {
    case enteredWork(setNumber: Int)
    case enteredRest(peakHR: Int, setNumber: Int, restEntryTime: Date)
    case hrrCapture(minuteMark: Int, hrDrop: Int)  // at +60s and +120s into rest
    case restExited(duration: TimeInterval)
}

// MARK: - Threshold configuration

struct SegmenterConfig {
    /// Fraction of maxHR above which HR is considered "elevated" (gymStrength only). Default 55%.
    var workHRThreshold: Double = 0.55
    /// Minimum peak HR for a work period to be valid (HRR capture gating).
    var minWorkPeakHR: Int = 80
    /// Seconds of elevated HR + motion required before confirming a work period (gymStrength).
    var minWorkDuration: TimeInterval = 12
    /// Seconds after motion stops before declaring rest entry (gymStrength).
    var restEntryDelay: TimeInterval = 4
    /// If rest exceeds this duration without motion resuming, session is treated as paused.
    var restTimeoutDuration: TimeInterval = 300
    /// Target seconds after rest entry for the first HRR capture.
    var hrrWindow1: TimeInterval = 60
    /// Target seconds after rest entry for the second HRR capture.
    var hrrWindow2: TimeInterval = 120
    /// Half-width of the HRR capture window.
    var hrrTolerance: TimeInterval = 3
    /// Which detection model to use.
    var profile: SegmenterProfile = .gymStrength
    /// (cardiacRehab) Seconds stationary/unknown before confirming station start.
    var stationaryConfirmDuration: TimeInterval = 30
    /// (cardiacRehab) Seconds of non-walking after walk stops before confirming next station start.
    var walkStopConfirmDuration: TimeInterval = 15
}

// MARK: - Recovery Segmenter (pure value-type state machine)

struct RecoverySegmenter {
    let config: SegmenterConfig

    private(set) var state: SegmentState = .idle
    private(set) var setNumber: Int = 0
    private(set) var workStartTime: Date?

    // Work period tracking (shared)
    private var workCandidateStart: Date?
    private var peakHRDuringWork: Int = 0
    private var lastMotionActiveTime: Date?

    // Rest period tracking (shared)
    private(set) var restStartTime: Date?
    private var peakHRAtRestEntry: Int = 0
    private var hrr1Captured: Bool = false
    private var hrr2Captured: Bool = false

    // cardiacRehab: debounce for rest→work transition
    private var notWalkingCandidateStart: Date?

    init(config: SegmenterConfig = SegmenterConfig()) {
        self.config = config
    }

    /// Called once per second. Returns 0…N events describing state transitions and captures.
    mutating func tick(hr: Int, activity: DetectedActivity, maxHR: Double, now: Date) -> [SegmenterEvent] {
        switch config.profile {
        case .gymStrength:
            return tickGymStrength(hr: hr, activity: activity, maxHR: maxHR, now: now)
        case .cardiacRehab:
            return tickCardiacRehab(hr: hr, activity: activity, now: now)
        }
    }

    // MARK: - Gym Strength (original logic, unchanged)

    private mutating func tickGymStrength(hr: Int, activity: DetectedActivity, maxHR: Double, now: Date) -> [SegmenterEvent] {
        var events: [SegmenterEvent] = []
        let workHRMin = Int(maxHR * config.workHRThreshold)
        let isMotionActive = activity != .stationary && activity != .unknown
        let isHRElevated = hr >= workHRMin

        switch state {
        case .idle:
            if isHRElevated && isMotionActive {
                if workCandidateStart == nil {
                    workCandidateStart = now
                    peakHRDuringWork = hr
                } else {
                    if hr > peakHRDuringWork { peakHRDuringWork = hr }
                    let elapsed = now.timeIntervalSince(workCandidateStart!)
                    if elapsed >= config.minWorkDuration {
                        state = .work
                        workStartTime = now
                        lastMotionActiveTime = now
                        setNumber += 1
                        events.append(.enteredWork(setNumber: setNumber))
                    }
                }
            } else {
                workCandidateStart = nil
            }

        case .work:
            if hr > peakHRDuringWork { peakHRDuringWork = hr }
            if isMotionActive { lastMotionActiveTime = now }
            let timeSinceMotion = lastMotionActiveTime.map { now.timeIntervalSince($0) } ?? 0
            let motionHasStopped = !isMotionActive && timeSinceMotion >= config.restEntryDelay
            if motionHasStopped && peakHRDuringWork >= config.minWorkPeakHR {
                let peak = peakHRDuringWork
                restStartTime = now
                peakHRAtRestEntry = peak
                hrr1Captured = false
                hrr2Captured = false
                state = .rest
                workStartTime = nil
                workCandidateStart = nil
                peakHRDuringWork = 0
                events.append(.enteredRest(peakHR: peak, setNumber: setNumber, restEntryTime: now))
            }

        case .rest:
            guard let restStart = restStartTime else { state = .idle; break }
            let restElapsed = now.timeIntervalSince(restStart)
            if restElapsed > config.restTimeoutDuration {
                state = .idle
                restStartTime = nil
                events.append(.restExited(duration: restElapsed))
                break
            }
            events += captureHRR(hr: hr, restElapsed: restElapsed)
            if isMotionActive {
                let duration = restElapsed
                state = .work
                workStartTime = now
                restStartTime = nil
                workCandidateStart = now
                peakHRDuringWork = hr
                lastMotionActiveTime = now
                setNumber += 1
                events.append(.restExited(duration: duration))
                events.append(.enteredWork(setNumber: setNumber))
            }
        }

        return events
    }

    // MARK: - Cardiac Rehab

    private mutating func tickCardiacRehab(hr: Int, activity: DetectedActivity, now: Date) -> [SegmenterEvent] {
        var events: [SegmenterEvent] = []
        let isWalking = activity == .walking
        let isOnMachine = activity == .stationary || activity == .unknown

        switch state {
        case .idle:
            // Stationary/unknown sustained for stationaryConfirmDuration → station starts
            if isOnMachine {
                if workCandidateStart == nil {
                    workCandidateStart = now
                    peakHRDuringWork = hr
                } else {
                    if hr > peakHRDuringWork { peakHRDuringWork = hr }
                    let elapsed = now.timeIntervalSince(workCandidateStart!)
                    if elapsed >= config.stationaryConfirmDuration {
                        state = .work
                        workStartTime = now
                        setNumber += 1
                        events.append(.enteredWork(setNumber: setNumber))
                    }
                }
            } else {
                // Walking or running — not seated, reset candidate
                workCandidateStart = nil
            }

        case .work:
            if hr > peakHRDuringWork { peakHRDuringWork = hr }
            // Walking detected → user is moving between machines → enter rest immediately
            if isWalking {
                let peak = peakHRDuringWork
                restStartTime = now
                peakHRAtRestEntry = peak
                hrr1Captured = false
                hrr2Captured = false
                notWalkingCandidateStart = nil
                state = .rest
                workStartTime = nil
                workCandidateStart = nil
                peakHRDuringWork = 0
                events.append(.enteredRest(peakHR: peak, setNumber: setNumber, restEntryTime: now))
            }

        case .rest:
            guard let restStart = restStartTime else { state = .idle; break }
            let restElapsed = now.timeIntervalSince(restStart)
            if restElapsed > config.restTimeoutDuration {
                state = .idle
                restStartTime = nil
                notWalkingCandidateStart = nil
                events.append(.restExited(duration: restElapsed))
                break
            }
            events += captureHRR(hr: hr, restElapsed: restElapsed)
            // Exit rest: walking has stopped, debounce for walkStopConfirmDuration
            if !isWalking {
                if notWalkingCandidateStart == nil {
                    notWalkingCandidateStart = now
                } else if now.timeIntervalSince(notWalkingCandidateStart!) >= config.walkStopConfirmDuration {
                    let duration = restElapsed
                    state = .work
                    workStartTime = now
                    restStartTime = nil
                    notWalkingCandidateStart = nil
                    peakHRDuringWork = hr
                    workCandidateStart = nil
                    setNumber += 1
                    events.append(.restExited(duration: duration))
                    events.append(.enteredWork(setNumber: setNumber))
                }
            } else {
                // Still walking — reset debounce
                notWalkingCandidateStart = nil
            }
        }

        return events
    }

    // MARK: - Shared HRR capture

    private mutating func captureHRR(hr: Int, restElapsed: TimeInterval) -> [SegmenterEvent] {
        var events: [SegmenterEvent] = []
        if !hrr1Captured && abs(restElapsed - config.hrrWindow1) <= config.hrrTolerance {
            hrr1Captured = true
            events.append(.hrrCapture(minuteMark: 1, hrDrop: max(0, peakHRAtRestEntry - hr)))
        }
        if !hrr2Captured && abs(restElapsed - config.hrrWindow2) <= config.hrrTolerance {
            hrr2Captured = true
            events.append(.hrrCapture(minuteMark: 2, hrDrop: max(0, peakHRAtRestEntry - hr)))
        }
        return events
    }
}
