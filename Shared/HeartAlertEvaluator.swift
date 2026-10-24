import Foundation

/// One alert raised during an active workout.
public struct HeartAlert: Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case aboveLimit, belowLow, signalLost, noMotion, suddenJump
    }
    public let kind: Kind
    /// The limit crossed (above/below), or the bpm rise for suddenJump. nil for signal lost / no motion.
    public let value: Int?

    public init(kind: Kind, value: Int? = nil) {
        self.kind = kind
        self.value = value
    }

    /// Short text for haptic notification / phone mirror.
    public var message: String {
        switch kind {
        case .aboveLimit: return "Heart rate above \(value ?? 0)"
        case .belowLow: return "Heart rate below \(value ?? 0)"
        case .signalLost: return "No heart rate signal"
        case .noMotion: return "Paused – no motion"
        case .suddenJump: return "Up \(value ?? 0) bpm quickly"
        }
    }
}

public struct HeartAlertLimits: Equatable, Sendable {
    public var upper: Int?
    public var low: Int?
    /// Seconds of no heart rate and no motion before auto-pause.
    public var noMotionWindow: TimeInterval
    public init(upper: Int?, low: Int?, noMotionWindow: TimeInterval = HeartAlertEvaluator.noMotionWindow) {
        self.upper = upper; self.low = low; self.noMotionWindow = noMotionWindow
    }
    /// `age`: the watch's own Health age. The upper limit is the synced one, else the age estimate
    /// (`effectiveUpperLimit`), the same number the watch screen measures "Ease off" against.
    public init(_ s: HeartSafetySettings, age: Int? = nil) {
        self.init(upper: s.effectiveUpperLimit(age: age), low: s.lowLimit, noMotionWindow: TimeInterval(s.noMotionSeconds))
    }
}

public struct HeartAlertFlags: Equatable, Sendable {
    public var aboveLimit, belowLow, signalLost, noMotion, suddenJump: Bool
    public init(aboveLimit: Bool = true, belowLow: Bool = true, signalLost: Bool = true,
                noMotion: Bool = true, suddenJump: Bool = true) {
        self.aboveLimit = aboveLimit; self.belowLow = belowLow
        self.signalLost = signalLost; self.noMotion = noMotion; self.suddenJump = suddenJump
    }
    public init(_ s: HeartSafetySettings) {
        self.init(aboveLimit: s.alertAboveLimit, belowLow: s.alertBelowLow,
                  signalLost: s.alertSignalLost, noMotion: s.alertNoMotion, suddenJump: s.alertSuddenJump)
    }
}

/// Pure alert state machine. Ticked once a second while a workout runs, and every
/// `pausedTickInterval` while it is paused (`paused: true`). Each kind fires once its
/// condition has held for its window, repeats at most every `cooldown` (`pausedRepeat`
/// while paused) while it persists, and re-arms when it clears.
///
/// While paused only above-limit and signal-lost are evaluated: a paused wearer whose
/// heart rate stays high, or whose signal is gone, is still told every minute. No
/// motion never fires while paused (it is what auto-paused the workout), and below-low
/// and sudden-jump wait for the resume.
///
/// Call `reset()` on start and on resume: the windows for signal lost / no motion
/// then count from the first tick after it, so a resume gets a fresh grace period.
///
/// Signal lost and no motion need at least one HR sample this workout
/// (`lastHRDate != nil`): a workout with HR never seen is denied permission or a
/// warming sensor, which the existing "no heart rate" banner already covers —
/// auto-pausing that wearer every minute would be wrong.
///
/// Sudden jump works on real samples, not ticks: a new sample is seen when
/// `lastHRDate` advances. It fires when two samples at least `jumpConfirmGap` apart,
/// with no lower sample between them, both sit `jumpBpm` above the lowest sample of the
/// `jumpWindow` before the first one, and the second arrives within `jumpWindow` of the
/// first. A single spike (optical sensor glitch) is ignored.
///
/// Above limit also needs real samples: at least two fresh samples in a row above the limit, and the
/// 10 s window counts from the first of them. One high sample held on screen (then no samples) never
/// fires. Nothing else suppresses it.
public struct HeartAlertEvaluator: Sendable {
    public static let aboveWindow: TimeInterval = 10
    public static let belowWindow: TimeInterval = 30
    public static let signalLostWindow: TimeInterval = 30
    public static let noMotionWindow: TimeInterval = 60
    public static let cooldown: TimeInterval = 120
    public static let jumpWindow: TimeInterval = 10
    public static let jumpBpm = 40
    public static let jumpConfirmGap: TimeInterval = 5
    /// While paused the caller ticks this often, and an alert that still holds repeats this often.
    public static let pausedTickInterval: TimeInterval = 5
    public static let pausedRepeat: TimeInterval = 60

    private var armedAt: Date?
    private var since: [HeartAlert.Kind: Date] = [:]
    private var lastFired: [HeartAlert.Kind: Date] = [:]
    private var lastJump: Date?
    /// Real HR samples from the last `jumpWindow` seconds (newest last).
    private var samples: [(date: Date, hr: Int)] = []
    /// First elevated sample of a possible jump and the baseline it rose from.
    private var jumpStart: (date: Date, baseline: Int)?
    /// Newest sample date seen by the above-limit rule (paused ticks included).
    private var lastAboveCheckSample: Date?
    /// Consecutive real samples above the upper limit: date of the first, and how many.
    private var aboveRun: (first: Date, count: Int)?

    public init() {}

    public mutating func reset() { self = HeartAlertEvaluator() }

    /// - Parameters:
    ///   - hr: latest BPM shown; ignored unless `lastHRDate` is fresh (< 30 s old).
    ///   - lastHRDate: time of the newest HR sample this workout, nil if none yet.
    ///   - lastMotionDate: last time steps/distance grew or CoreMotion said moving.
    ///   - paused: the workout is paused (see the type comment).
    public mutating func tick(now: Date, hr: Int, lastHRDate: Date?, lastMotionDate: Date?,
                              limits: HeartAlertLimits, flags: HeartAlertFlags,
                              paused: Bool = false) -> [HeartAlert] {
        let armed = armedAt ?? now
        armedAt = armed
        let hrAge = lastHRDate.map { now.timeIntervalSince(max($0, armed)) }
        let freshHR = (lastHRDate.map { now.timeIntervalSince($0) < Self.signalLostWindow } ?? false) && hr > 0
        let motionAge = now.timeIntervalSince(max(lastMotionDate ?? armed, armed))
        let repeatEvery = paused ? Self.pausedRepeat : Self.cooldown

        if freshHR, let date = lastHRDate, date > (lastAboveCheckSample ?? .distantPast) {
            lastAboveCheckSample = date
            if let upper = limits.upper, hr > upper {
                aboveRun = (aboveRun?.first ?? date, (aboveRun?.count ?? 0) + 1)
            } else {
                aboveRun = nil
            }
        }

        var out: [HeartAlert] = []
        func check(_ kind: HeartAlert.Kind, _ on: Bool, window: TimeInterval, value: Int? = nil,
                   startedAt: Date? = nil) {
            guard on else {
                since[kind] = nil
                lastFired[kind] = nil
                return
            }
            let start = since[kind] ?? startedAt ?? now
            since[kind] = start
            guard now.timeIntervalSince(start) >= window else { return }
            if let last = lastFired[kind], now.timeIntervalSince(last) < repeatEvery { return }
            lastFired[kind] = now
            out.append(HeartAlert(kind: kind, value: value))
        }

        if let upper = limits.upper {
            let run = aboveRun.flatMap { $0.count >= 2 ? $0.first : nil }
            check(.aboveLimit, flags.aboveLimit && freshHR && hr > upper && run != nil,
                  window: Self.aboveWindow, value: upper, startedAt: run)
        } else { check(.aboveLimit, false, window: 0) }
        if !paused {
            if let low = limits.low {
                check(.belowLow, flags.belowLow && freshHR && hr < low, window: Self.belowWindow, value: low)
            } else { check(.belowLow, false, window: 0) }
        }

        // Absence conditions carry their own duration, so no extra hold window.
        let noHRFor = hrAge ?? 0
        check(.signalLost, flags.signalLost && hrAge != nil && noHRFor >= Self.signalLostWindow, window: 0)
        guard !paused else { return out }
        check(.noMotion, flags.noMotion && hrAge != nil && noHRFor >= limits.noMotionWindow
              && motionAge >= limits.noMotionWindow, window: 0)

        // Own cooldown: the jump condition clears long before the 2 min cooldown ends.
        if freshHR, let date = lastHRDate, date > (samples.last?.date ?? .distantPast),
           let rise = ingestSample(hr, at: date), flags.suddenJump,
           lastJump.map({ now.timeIntervalSince($0) >= Self.cooldown }) ?? true {
            lastJump = now
            out.append(HeartAlert(kind: .suddenJump, value: rise))
        }
        return out
    }

    /// Feeds one real sample; returns the rise when it confirms a jump.
    private mutating func ingestSample(_ hr: Int, at date: Date) -> Int? {
        samples.removeAll { date.timeIntervalSince($0.date) > Self.jumpWindow }
        defer { samples.append((date, hr)) }
        // A start older than the window can't be confirmed (a spike, then minutes of no samples).
        if let start = jumpStart, date.timeIntervalSince(start.date) > Self.jumpWindow { jumpStart = nil }
        if let start = jumpStart {
            let rise = hr - start.baseline
            guard rise >= Self.jumpBpm else { jumpStart = nil; return nil }   // came back down
            guard date.timeIntervalSince(start.date) >= Self.jumpConfirmGap else { return nil }
            jumpStart = nil
            return rise
        }
        if let low = samples.map(\.hr).min(), hr - low >= Self.jumpBpm {
            jumpStart = (date, low)
        }
        return nil
    }
}
