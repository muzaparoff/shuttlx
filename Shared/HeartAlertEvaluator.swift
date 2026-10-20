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
        case .suddenJump: return "Heart rate jumped quickly"
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
    public init(_ s: HeartSafetySettings) {
        self.init(upper: s.upperLimit, low: s.lowLimit, noMotionWindow: TimeInterval(s.noMotionSeconds))
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

/// Pure alert state machine, ticked once a second while a workout is running
/// (not paused). Each kind fires once its condition has held for its window,
/// repeats at most every `cooldown` while it persists, and re-arms when it clears.
///
/// Call `reset()` on start and on resume: the windows for signal lost / no motion
/// then count from the first tick after it, so a resume gets a fresh grace period.
///
/// Signal lost and no motion need at least one HR sample this workout
/// (`lastHRDate != nil`): a workout with HR never seen is denied permission or a
/// warming sensor, which the existing "no heart rate" banner already covers —
/// auto-pausing that wearer every minute would be wrong.
public struct HeartAlertEvaluator: Sendable {
    public static let aboveWindow: TimeInterval = 10
    public static let belowWindow: TimeInterval = 30
    public static let signalLostWindow: TimeInterval = 30
    public static let noMotionWindow: TimeInterval = 60
    public static let cooldown: TimeInterval = 120
    public static let jumpWindow: TimeInterval = 10
    public static let jumpBpm = 40

    private var armedAt: Date?
    private var since: [HeartAlert.Kind: Date] = [:]
    private var lastFired: [HeartAlert.Kind: Date] = [:]
    /// Fresh HR readings from the last `jumpWindow` seconds.
    private var lastJump: Date?
    private var recent: [(date: Date, hr: Int)] = []

    public init() {}

    public mutating func reset() { self = HeartAlertEvaluator() }

    /// - Parameters:
    ///   - hr: latest BPM shown; ignored unless `lastHRDate` is fresh (< 30 s old).
    ///   - lastHRDate: time of the newest HR sample this workout, nil if none yet.
    ///   - lastMotionDate: last time steps/distance grew or CoreMotion said moving.
    public mutating func tick(now: Date, hr: Int, lastHRDate: Date?, lastMotionDate: Date?,
                              limits: HeartAlertLimits, flags: HeartAlertFlags) -> [HeartAlert] {
        let armed = armedAt ?? now
        armedAt = armed
        let hrAge = lastHRDate.map { now.timeIntervalSince(max($0, armed)) }
        let freshHR = (lastHRDate.map { now.timeIntervalSince($0) < Self.signalLostWindow } ?? false) && hr > 0
        let motionAge = now.timeIntervalSince(max(lastMotionDate ?? armed, armed))

        // Sudden jump: rise of >= jumpBpm over the lowest reading of the last 10 s.
        recent.removeAll { now.timeIntervalSince($0.date) > Self.jumpWindow }
        if freshHR { recent.append((now, hr)) }
        let rise = freshHR ? hr - (recent.map(\.hr).min() ?? hr) : 0

        var out: [HeartAlert] = []
        func check(_ kind: HeartAlert.Kind, _ on: Bool, window: TimeInterval, value: Int? = nil) {
            guard on else {
                since[kind] = nil
                lastFired[kind] = nil
                return
            }
            let start = since[kind] ?? now
            since[kind] = start
            guard now.timeIntervalSince(start) >= window else { return }
            if let last = lastFired[kind], now.timeIntervalSince(last) < Self.cooldown { return }
            lastFired[kind] = now
            out.append(HeartAlert(kind: kind, value: value))
        }

        if let upper = limits.upper {
            check(.aboveLimit, flags.aboveLimit && freshHR && hr > upper, window: Self.aboveWindow, value: upper)
        } else { check(.aboveLimit, false, window: 0) }
        if let low = limits.low {
            check(.belowLow, flags.belowLow && freshHR && hr < low, window: Self.belowWindow, value: low)
        } else { check(.belowLow, false, window: 0) }

        // Absence conditions carry their own duration, so no extra hold window.
        let noHRFor = hrAge ?? 0
        check(.signalLost, flags.signalLost && hrAge != nil && noHRFor >= Self.signalLostWindow, window: 0)
        check(.noMotion, flags.noMotion && hrAge != nil && noHRFor >= limits.noMotionWindow
              && motionAge >= limits.noMotionWindow, window: 0)
        // Own cooldown: the 10 s condition clears long before the 2 min cooldown ends.
        if flags.suddenJump, rise >= Self.jumpBpm,
           lastJump.map({ now.timeIntervalSince($0) >= Self.cooldown }) ?? true {
            lastJump = now
            out.append(HeartAlert(kind: .suddenJump, value: rise))
        }
        return out
    }
}
