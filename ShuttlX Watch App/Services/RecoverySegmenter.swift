import Foundation

// MARK: - Segmenter State

enum SegmentState: String {
    case idle    // no active work or rest period detected
    case work    // user is performing a set (elevated HR + motion)
    case rest    // user is resting between sets (motion stopped, HR dropping)
}

// MARK: - Events emitted by the segmenter each tick

enum SegmenterEvent {
    case enteredWork(setNumber: Int)
    case enteredRest(peakHR: Int, setNumber: Int, restEntryTime: Date)
    case hrrCapture(minuteMark: Int, hrDrop: Int)  // emitted at +60s and +120s into rest
    case restExited(duration: TimeInterval)
}

// MARK: - Threshold configuration

struct SegmenterConfig {
    /// Fraction of maxHR above which HR is considered "elevated" during a work set. Default 55%.
    var workHRThreshold: Double = 0.55
    /// Minimum HR (absolute) that must have been reached for a "work" period to be valid.
    var minWorkPeakHR: Int = 80
    /// Seconds of elevated HR + motion required before confirming a work period.
    var minWorkDuration: TimeInterval = 12
    /// Seconds after motion stops before declaring rest entry (in the gym profile motion stops
    /// quickly — use 4s rather than the 5s auto-detect debounce on WatchWorkoutManager).
    var restEntryDelay: TimeInterval = 4
    /// If rest exceeds this duration without motion resuming the session is treated as paused.
    var restTimeoutDuration: TimeInterval = 300
    /// Target seconds after rest entry for the first HRR capture.
    var hrrWindow1: TimeInterval = 60
    /// Target seconds after rest entry for the second HRR capture.
    var hrrWindow2: TimeInterval = 120
    /// Half-width of the capture window: capture fires when |elapsed - target| ≤ tolerance.
    var hrrTolerance: TimeInterval = 3
}

// MARK: - Recovery Segmenter (pure value-type state machine)

struct RecoverySegmenter {
    let config: SegmenterConfig

    private(set) var state: SegmentState = .idle
    private(set) var setNumber: Int = 0

    // Work period tracking
    private var workCandidateStart: Date?   // when elevated HR + motion first detected
    private var peakHRDuringWork: Int = 0
    private var lastMotionActiveTime: Date? // last tick where motion was non-stationary

    // Rest period tracking
    private(set) var restStartTime: Date?
    private var peakHRAtRestEntry: Int = 0
    private var hrr1Captured: Bool = false
    private var hrr2Captured: Bool = false

    init(config: SegmenterConfig = SegmenterConfig()) {
        self.config = config
    }

    /// Called once per second. Returns 0…N events describing state transitions and captures.
    mutating func tick(hr: Int, activity: DetectedActivity, maxHR: Double, now: Date) -> [SegmenterEvent] {
        var events: [SegmenterEvent] = []

        let workHRMin = Int(maxHR * config.workHRThreshold)
        let isMotionActive = activity != .stationary && activity != .unknown
        let isHRElevated = hr >= workHRMin

        switch state {

        case .idle:
            // Candidate work detection: both HR and motion must be elevated
            if isHRElevated && isMotionActive {
                if workCandidateStart == nil {
                    workCandidateStart = now
                    peakHRDuringWork = hr
                } else {
                    if hr > peakHRDuringWork { peakHRDuringWork = hr }
                    let elapsed = now.timeIntervalSince(workCandidateStart!)
                    if elapsed >= config.minWorkDuration {
                        state = .work
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

            // Detect rest entry: motion has stopped for restEntryDelay seconds
            let timeSinceMotion = lastMotionActiveTime.map { now.timeIntervalSince($0) } ?? now.timeIntervalSince(now)
            let motionHasStopped = !isMotionActive && timeSinceMotion >= config.restEntryDelay

            if motionHasStopped && peakHRDuringWork >= config.minWorkPeakHR {
                let peak = peakHRDuringWork
                restStartTime = now
                peakHRAtRestEntry = peak
                hrr1Captured = false
                hrr2Captured = false
                state = .rest
                workCandidateStart = nil
                peakHRDuringWork = 0
                events.append(.enteredRest(peakHR: peak, setNumber: setNumber, restEntryTime: now))
            }

        case .rest:
            guard let restStart = restStartTime else {
                state = .idle
                break
            }

            let restElapsed = now.timeIntervalSince(restStart)

            // Timeout: rest too long → session is paused or finished
            if restElapsed > config.restTimeoutDuration {
                state = .idle
                restStartTime = nil
                events.append(.restExited(duration: restElapsed))
                break
            }

            // HRR capture at window 1 (+60s)
            if !hrr1Captured && abs(restElapsed - config.hrrWindow1) <= config.hrrTolerance {
                hrr1Captured = true
                let drop = max(0, peakHRAtRestEntry - hr)
                events.append(.hrrCapture(minuteMark: 1, hrDrop: drop))
            }

            // HRR capture at window 2 (+120s)
            if !hrr2Captured && abs(restElapsed - config.hrrWindow2) <= config.hrrTolerance {
                hrr2Captured = true
                let drop = max(0, peakHRAtRestEntry - hr)
                events.append(.hrrCapture(minuteMark: 2, hrDrop: drop))
            }

            // Exit rest: motion resumes
            if isMotionActive {
                let duration = restElapsed
                state = .work
                restStartTime = nil
                workCandidateStart = now
                peakHRDuringWork = hr
                lastMotionActiveTime = now
                events.append(.restExited(duration: duration))
                // Don't immediately emit .enteredWork — wait for minWorkDuration confirmation
                // in the next idle→work transition from the .work case's candidate logic.
                // (We're already in .work state, so we skip that; the set counter stays.)
                setNumber += 1
                events.append(.enteredWork(setNumber: setNumber))
            }
        }

        return events
    }
}
