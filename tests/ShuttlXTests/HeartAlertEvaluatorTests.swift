import XCTest
@testable import ShuttlXShared

final class HeartAlertEvaluatorTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let limits = HeartAlertLimits(upper: 150, low: 50)
    let flags = HeartAlertFlags()

    /// Ticks every second from `from` to `to` (inclusive) with fresh HR and motion,
    /// returning (second, alert) pairs.
    private func run(_ e: inout HeartAlertEvaluator, from: Int, to: Int, hr: Int,
                     hrFresh: Bool = true, lastHR: Date? = nil, lastMotion: Date? = nil,
                     flags: HeartAlertFlags? = nil) -> [(Int, HeartAlert)] {
        var out: [(Int, HeartAlert)] = []
        for s in from...to {
            let now = t0.addingTimeInterval(TimeInterval(s))
            let alerts = e.tick(now: now, hr: hr,
                                lastHRDate: hrFresh ? now : lastHR,
                                lastMotionDate: lastMotion ?? now,
                                limits: limits, flags: flags ?? self.flags)
            out += alerts.map { (s, $0) }
        }
        return out
    }

    func testAboveFiresAfter10sThenCooldown2Min() {
        var e = HeartAlertEvaluator()
        let fired = run(&e, from: 0, to: 250, hr: 160)
        XCTAssertEqual(fired.map(\.0), [10, 130, 250])
        XCTAssertEqual(fired.first?.1, HeartAlert(kind: .aboveLimit, value: 150))
        XCTAssertEqual(fired.first?.1.message, "Heart rate above 150")
    }

    func testAboveRearmsWhenConditionClears() {
        var e = HeartAlertEvaluator()
        XCTAssertEqual(run(&e, from: 0, to: 12, hr: 160).map(\.0), [10])
        XCTAssertTrue(run(&e, from: 13, to: 14, hr: 140).isEmpty)  // clears
        XCTAssertEqual(run(&e, from: 15, to: 30, hr: 160).map(\.0), [25]) // fresh 10 s, no cooldown
    }

    func testAboveNeedsSustained10s() {
        var e = HeartAlertEvaluator()
        XCTAssertTrue(run(&e, from: 0, to: 8, hr: 160).isEmpty)
        XCTAssertTrue(run(&e, from: 9, to: 9, hr: 140).isEmpty)
        XCTAssertTrue(run(&e, from: 10, to: 18, hr: 160).isEmpty)
    }

    func testBelowFiresAfter30sAndOffWhenNoLowLimit() {
        var e = HeartAlertEvaluator()
        let fired = run(&e, from: 0, to: 40, hr: 45)
        XCTAssertEqual(fired.map(\.0), [30])
        XCTAssertEqual(fired.first?.1.message, "Heart rate below 50")

        var e2 = HeartAlertEvaluator()
        var none: [HeartAlert] = []
        for s in 0...60 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            none += e2.tick(now: now, hr: 45, lastHRDate: now, lastMotionDate: now,
                            limits: HeartAlertLimits(upper: 150, low: nil), flags: flags)
        }
        XCTAssertTrue(none.isEmpty)
    }

    func testFlagOffSuppresses() {
        var e = HeartAlertEvaluator()
        XCTAssertTrue(run(&e, from: 0, to: 60, hr: 160, flags: HeartAlertFlags(aboveLimit: false)).isEmpty)
    }

    func testSignalLostAt30sThenNoMotionAt60s() {
        var e = HeartAlertEvaluator()
        let lastHR = t0
        _ = run(&e, from: 0, to: 0, hr: 100)
        // HR stops after t0; motion also stopped at t0.
        let fired = run(&e, from: 1, to: 61, hr: 100, hrFresh: false, lastHR: lastHR, lastMotion: t0)
        XCTAssertEqual(fired.map(\.1.kind), [.signalLost, .noMotion])
        XCTAssertEqual(fired.map(\.0), [30, 60])
    }

    func testNoMotionNeedsBothAbsent() {
        var e = HeartAlertEvaluator()
        _ = run(&e, from: 0, to: 0, hr: 100)
        // HR gone but still moving: signal lost only.
        let moving = run(&e, from: 1, to: 90, hr: 100, hrFresh: false, lastHR: t0)
        XCTAssertEqual(moving.map(\.1.kind), [.signalLost])

        // Still but HR present (interval rest standing): nothing.
        var e2 = HeartAlertEvaluator()
        XCTAssertTrue(run(&e2, from: 0, to: 120, hr: 100, lastMotion: t0).isEmpty)
    }

    func testNoHRAlertsBeforeFirstSample() {
        var e = HeartAlertEvaluator()
        XCTAssertTrue(run(&e, from: 0, to: 120, hr: 0, hrFresh: false, lastHR: nil, lastMotion: t0).isEmpty)
    }

    func testResetGivesFreshGraceAfterResume() {
        var e = HeartAlertEvaluator()
        _ = run(&e, from: 0, to: 0, hr: 100)
        // Paused for 10 min with HR and motion long stale; resume at 600.
        e.reset()
        let fired = run(&e, from: 600, to: 661, hr: 100, hrFresh: false, lastHR: t0, lastMotion: t0)
        XCTAssertEqual(fired.map(\.0), [630, 660])
    }

    /// One sample above the limit, then no samples: held on screen for its whole 30 s life. It used to
    /// fire at 10 s; above limit now needs two real samples (algorithms §5 pick A).
    func testSingleStaleSampleAboveLimitNeverFires() {
        var e = HeartAlertEvaluator()
        _ = run(&e, from: 0, to: 0, hr: 160)
        let fired = run(&e, from: 1, to: 59, hr: 160, hrFresh: false, lastHR: t0,
                        flags: HeartAlertFlags(signalLost: false))
        XCTAssertTrue(fired.isEmpty)
    }

    /// Samples every 5 s above the limit: fires 10 s after the first sample (hard rule: <= 15 s).
    func testSamplesEvery5sAboveLimitFireWithin15s() {
        var e = HeartAlertEvaluator()
        var hrDate: Date?
        var fired: [Int] = []
        for s in 0...40 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            if s % 5 == 0 { hrDate = now }
            if e.tick(now: now, hr: 170, lastHRDate: hrDate, lastMotionDate: now,
                      limits: HeartAlertLimits(upper: 130, low: nil), flags: flags).contains(where: { $0.kind == .aboveLimit }) {
                fired.append(s)
            }
        }
        XCTAssertEqual(fired, [10])
    }

    /// A sample at or below the limit between two high ones restarts the count.
    func testLowerSampleBetweenRestartsTheRun() {
        var e = HeartAlertEvaluator()
        var fired: [Int] = []
        let samples: [Int: Int] = [0: 170, 5: 120, 10: 170, 15: 170]
        var hr = 0, hrDate: Date?
        for s in 0...30 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            if let v = samples[s] { hr = v; hrDate = now }
            if e.tick(now: now, hr: hr, lastHRDate: hrDate, lastMotionDate: now,
                      limits: HeartAlertLimits(upper: 130, low: nil), flags: flags).contains(where: { $0.kind == .aboveLimit }) {
                fired.append(s)
            }
        }
        XCTAssertEqual(fired, [20])   // run starts at 10, second sample at 15, window ends 20
    }

    // MARK: Sudden jump / configurable no-motion window

    func testSuddenJumpFiresOncePerRiseWithCooldown() {
        var e = HeartAlertEvaluator()
        // Samples every 5 s: +45 at 20 (confirmed at 25) and again at 150 (confirmed at 155).
        let samples = every5(stride(from: 0, through: 200, by: 5)) { s in
            (s >= 20 && s < 130) || s >= 150 ? 120 : 75
        }
        XCTAssertEqual(jumpRun(&e, to: 200, samples: samples), [25, 155]) // 2 min apart
    }

    func testSlowRiseDoesNotJump() {
        var e = HeartAlertEvaluator()
        // +1 bpm/s, one sample a second: the 10 s window rises 10 only.
        let samples = Dictionary(uniqueKeysWithValues: (0...60).map { ($0, 70 + $0) })
        XCTAssertEqual(jumpRun(&e, to: 60, samples: samples), [])
    }

    func testJumpOffByFlag() {
        var e = HeartAlertEvaluator()
        var f = flags; f.suddenJump = false
        let samples = every5(stride(from: 0, through: 30, by: 5)) { $0 < 10 ? 70 : 130 }
        XCTAssertEqual(jumpRun(&e, to: 30, samples: samples, flags: f), [])
    }

    func testStaleReplayedSampleDoesNotJump() {
        // Crash-recovery replays old samples: only a fresh newest sample can confirm.
        var e = HeartAlertEvaluator()
        var fired: [HeartAlert] = []
        for (s, hr) in [(0, 95), (5, 136), (10, 136)] {
            let sample = t0.addingTimeInterval(TimeInterval(s))
            fired += e.tick(now: t0.addingTimeInterval(600), hr: hr, lastHRDate: sample, lastMotionDate: nil,
                            limits: HeartAlertLimits(upper: 300, low: nil),
                            flags: HeartAlertFlags(signalLost: false, noMotion: false))
        }
        XCTAssertTrue(fired.isEmpty)
    }

    // MARK: Paused (audit 2026-10): above-limit + signal-lost every 60 s, no-motion never

    /// Ticks every 5 s while paused.
    private func pausedRun(_ e: inout HeartAlertEvaluator, from: Int, to: Int, hr: Int,
                           lastHR: (Date) -> Date?, lastMotion: Date?) -> [(Int, HeartAlert.Kind)] {
        var out: [(Int, HeartAlert.Kind)] = []
        for s in stride(from: from, through: to, by: Int(HeartAlertEvaluator.pausedTickInterval)) {
            let now = t0.addingTimeInterval(TimeInterval(s))
            out += e.tick(now: now, hr: hr, lastHRDate: lastHR(now), lastMotionDate: lastMotion,
                          limits: limits, flags: flags, paused: true).map { (s, $0.kind) }
        }
        return out
    }

    func testPausedAboveLimitRepeatsEveryMinute() {
        var e = HeartAlertEvaluator()
        let fired = pausedRun(&e, from: 0, to: 200, hr: 160, lastHR: { $0 }, lastMotion: t0)
        XCTAssertEqual(fired.map(\.1), [.aboveLimit, .aboveLimit, .aboveLimit, .aboveLimit])
        XCTAssertEqual(fired.map(\.0), [10, 70, 130, 190])
    }

    func testPausedBelowLowAndJumpWaitForResume() {
        var e = HeartAlertEvaluator()
        XCTAssertTrue(pausedRun(&e, from: 0, to: 120, hr: 40, lastHR: { $0 }, lastMotion: t0).isEmpty)
    }

    func testAfterNoMotionAutoPauseSignalLostRepeatsAndNoMotionNeverRefires() {
        var e = HeartAlertEvaluator()
        _ = run(&e, from: 0, to: 0, hr: 100)
        // Running: HR and motion stop after t0 -> signal lost at 30, no motion (auto-pause) at 60.
        let running = run(&e, from: 1, to: 60, hr: 100, hrFresh: false, lastHR: t0, lastMotion: t0)
        XCTAssertEqual(running.map(\.1.kind), [.signalLost, .noMotion])
        // Paused from 65: signal lost every 60 s after its last alert, no motion never again.
        let paused = pausedRun(&e, from: 65, to: 300, hr: 100, lastHR: { _ in self.t0 }, lastMotion: t0)
        XCTAssertEqual(paused.map(\.1), [.signalLost, .signalLost, .signalLost, .signalLost])
        XCTAssertEqual(paused.map(\.0), [90, 150, 210, 270])
    }

    func testPausedAlertStopsWhenConditionClears() {
        var e = HeartAlertEvaluator()
        XCTAssertEqual(pausedRun(&e, from: 0, to: 15, hr: 160, lastHR: { $0 }, lastMotion: t0).map(\.0), [10])
        XCTAssertTrue(pausedRun(&e, from: 20, to: 25, hr: 120, lastHR: { $0 }, lastMotion: t0).isEmpty)
        // Back above: fresh 10 s window, not the old repeat clock.
        XCTAssertEqual(pausedRun(&e, from: 30, to: 45, hr: 160, lastHR: { $0 }, lastMotion: t0).map(\.0), [40])
    }

    func testNoMotionWindowIsConfigurable() {
        var e = HeartAlertEvaluator()
        let l = HeartAlertLimits(upper: nil, low: nil, noMotionWindow: 30)
        var firstNoMotion: Int?
        for s in 0...100 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            // HR seen at t0 only, no motion ever.
            let a = e.tick(now: now, hr: 0, lastHRDate: t0, lastMotionDate: nil, limits: l, flags: flags)
            if firstNoMotion == nil, a.contains(where: { $0.kind == .noMotion }) { firstNoMotion = s }
        }
        XCTAssertEqual(firstNoMotion, 30)
    }

    // MARK: Sudden jump needs two real samples (audit 2026-10)

    /// Ticks 1 Hz; `samples` maps second -> bpm of a NEW HR sample. Between samples
    /// the display keeps the latest value, exactly as the watch does.
    private func jumpRun(_ e: inout HeartAlertEvaluator, to: Int, samples: [Int: Int],
                         flags: HeartAlertFlags? = nil) -> [Int] {
        var hr = 0
        var last: Date?
        var fired: [Int] = []
        for s in 0...to {
            let now = t0.addingTimeInterval(TimeInterval(s))
            if let v = samples[s] { hr = v; last = now }
            let a = e.tick(now: now, hr: hr, lastHRDate: last, lastMotionDate: now,
                           limits: HeartAlertLimits(upper: 300, low: nil), flags: flags ?? self.flags)
            if a.contains(where: { $0.kind == .suddenJump }) { fired.append(s) }
        }
        return fired
    }

    private func every5(_ range: StrideThrough<Int>, _ hr: (Int) -> Int) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: range.map { ($0, hr($0)) })
    }

    func testSingleHighSampleDoesNotJump() {
        var e = HeartAlertEvaluator()
        // 95 held, ONE 136 sample at 30 s (held on screen for 5 ticks), back to 95.
        let samples = every5(stride(from: 0, through: 60, by: 5)) { $0 == 30 ? 136 : 95 }
        XCTAssertEqual(jumpRun(&e, to: 60, samples: samples), [])
    }

    func testTwoHighSamplesFiveSecondsApartJump() {
        var e = HeartAlertEvaluator()
        let samples = every5(stride(from: 0, through: 60, by: 5)) { $0 >= 30 ? 136 : 95 }
        XCTAssertEqual(jumpRun(&e, to: 60, samples: samples), [35])
    }

    func testTwoHighSamplesTooCloseTogetherDoNotJump() {
        var e = HeartAlertEvaluator()
        var samples = every5(stride(from: 0, through: 60, by: 5)) { _ in 95 }
        samples[30] = 136; samples[32] = 137   // 2 s apart, then back to 95 at 35
        XCTAssertEqual(jumpRun(&e, to: 60, samples: samples), [])
    }

    /// A lone spike must not be confirmed by a sample minutes later (no samples between).
    func testJumpStartExpiresAfterWindow() {
        var e = HeartAlertEvaluator()
        let samples = [0: 80, 3: 80, 6: 125, 186: 125]
        XCTAssertEqual(jumpRun(&e, to: 190, samples: samples), [])
    }

    /// Confirmation inside the window still fires after the expiry change.
    func testJumpConfirmedWithinWindowStillFires() {
        var e = HeartAlertEvaluator()
        let samples = [0: 80, 3: 80, 6: 125, 15: 126]
        XCTAssertEqual(jumpRun(&e, to: 20, samples: samples), [15])
    }
}
