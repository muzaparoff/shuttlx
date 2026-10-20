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

    func testStaleHRDoesNotTriggerAbove() {
        var e = HeartAlertEvaluator()
        _ = run(&e, from: 0, to: 0, hr: 160)
        let fired = run(&e, from: 1, to: 59, hr: 160, hrFresh: false, lastHR: t0,
                        flags: HeartAlertFlags(signalLost: false))
        // Fires at 10 while sample is fresh, then stale after 30 s re-arms.
        XCTAssertEqual(fired.map(\.0), [10])
    }

    // MARK: Sudden jump / configurable no-motion window

    func testSuddenJumpFiresOncePerRiseWithCooldown() {
        var e = HeartAlertEvaluator()
        var fired: [Int] = []
        for s in 0...200 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            let hr = (s >= 20 && s < 130) || s >= 150 ? 120 : 75   // +45 at 20 and again at 150
            let a = e.tick(now: now, hr: hr, lastHRDate: now, lastMotionDate: now,
                           limits: HeartAlertLimits(upper: 200, low: nil), flags: flags)
            if a.contains(where: { $0.kind == .suddenJump }) { fired.append(s) }
        }
        XCTAssertEqual(fired, [20, 150]) // one alert per rise, 2 min apart
    }

    func testSlowRiseDoesNotJump() {
        var e = HeartAlertEvaluator()
        var hr = 70
        for s in 0...60 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            hr = 70 + s            // +1 bpm/s: 10 s window rises 10 only
            XCTAssertTrue(e.tick(now: now, hr: hr, lastHRDate: now, lastMotionDate: now,
                                 limits: HeartAlertLimits(upper: 300, low: nil), flags: flags).isEmpty)
        }
    }

    func testJumpOffByFlag() {
        var e = HeartAlertEvaluator()
        var f = flags; f.suddenJump = false
        for s in 0...20 {
            let now = t0.addingTimeInterval(TimeInterval(s))
            XCTAssertTrue(e.tick(now: now, hr: s < 10 ? 70 : 130, lastHRDate: now, lastMotionDate: now,
                                 limits: HeartAlertLimits(upper: 300, low: nil), flags: f).isEmpty)
        }
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
}
