import XCTest
@testable import ShuttlXShared

// MARK: - Helpers

private let baseDate = Date(timeIntervalSinceReferenceDate: 0)

private func cardiacConfig() -> SegmenterConfig {
    var c = SegmenterConfig()
    c.profile = .cardiacRehab
    // Existing cardiac-rehab tests exercise the auto-detect path. After
    // Sprint 7, manualStationsOnly defaults to true; opt out explicitly here
    // so the auto path is still under test.
    c.manualStationsOnly = false
    return c
}

private func gymConfig() -> SegmenterConfig {
    var c = SegmenterConfig()
    c.profile = .gymStrength
    return c
}

/// Drives the segmenter for `seconds` consecutive ticks. The `cursor` is the
/// caller-owned wall-clock offset (in whole seconds since baseDate) and is
/// advanced past the last tick — so chained calls remain in temporal order.
private func tickFor(_ seconds: Int,
                     hr: Int,
                     activity: DetectedActivity,
                     maxHR: Double = 180,
                     segmenter: inout RecoverySegmenter,
                     cursor: inout Int,
                     hrRamp: ((Int) -> Int)? = nil) -> [SegmenterEvent] {
    var allEvents: [SegmenterEvent] = []
    for i in 0..<seconds {
        let stepHR = hrRamp?(i) ?? hr
        let events = segmenter.tick(hr: stepHR,
                                    activity: activity,
                                    maxHR: maxHR,
                                    now: baseDate.addingTimeInterval(Double(cursor + i)))
        allEvents.append(contentsOf: events)
    }
    cursor += seconds
    return allEvents
}

// MARK: - Cardiac Rehab Profile

final class CardiacRehabSegmenterTests: XCTestCase {

    // Sitting on a cardio machine with rising HR should trigger station start
    // after the dual condition is met (>= 15s stationary AND HR rise >= 6 BPM).
    func testIdleToWork_DualCondition_Met() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        // 15+ seconds stationary, HR rises from 80 → ~95 (+15 BPM, clears 6 BPM threshold)
        let events = tickFor(16, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor,
                             hrRamp: { i in 80 + i })
        XCTAssertEqual(segmenter.state, .work)
        XCTAssertEqual(segmenter.setNumber, 1)
        XCTAssertTrue(events.contains { if case .enteredWork(setNumber: 1) = $0 { return true } else { return false } })
    }

    // Stationary for 15s with flat HR (no rise) should NOT trigger station start.
    // This is the false-positive guard against "patient sitting in waiting area".
    func testIdleToWork_FlatHR_DoesNotTrigger() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        _ = tickFor(20, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .idle, "Flat HR over 15s must not enter work — the patient is just sitting")
        XCTAssertEqual(segmenter.setNumber, 0)
    }

    // Beta-blocker patients have blunted HR response. The fallback should fire
    // after `workFallbackDuration` (45s) regardless of HR rise.
    func testIdleToWork_FallbackAfter45s_WithFlatHR() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        _ = tickFor(46, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .work)
        XCTAssertEqual(segmenter.setNumber, 1, "Fallback must trigger after 45s even without HR rise")
    }

    // Walking during a station should immediately end the work period and enter rest.
    func testWorkToRest_WalkingTriggersImmediateRest() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        _ = tickFor(16, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor, hrRamp: { 80 + $0 })
        XCTAssertEqual(segmenter.state, .work)
        let restEvents = tickFor(1, hr: 100, activity: .walking, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .rest)
        XCTAssertTrue(restEvents.contains { if case .enteredRest = $0 { return true } else { return false } })
    }

    // Rest → next station: walking must stop for at least walkStopConfirmDuration (15s).
    func testRestToWork_RequiresWalkStopDebounce() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        _ = tickFor(16, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor, hrRamp: { 80 + $0 })
        _ = tickFor(1, hr: 100, activity: .walking, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .rest)

        // 14 seconds non-walking — still in rest (debounce not yet met)
        _ = tickFor(14, hr: 90, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .rest, "14s of non-walking is below the 15s debounce")

        // 2 more seconds crosses the threshold
        _ = tickFor(2, hr: 90, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .work, "After 15s+ of non-walking, next station begins")
        XCTAssertEqual(segmenter.setNumber, 2)
    }

    // HRR captures should fire at +60s and +120s into rest.
    func testHRRCapturesFireAtCorrectWindows() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        // Enter work via dual condition: 16s stationary with HR ramping 140 → 155 (+15 BPM).
        // Peak HR during work will end at 155.
        _ = tickFor(16, hr: 0, activity: .stationary, segmenter: &segmenter, cursor: &cursor, hrRamp: { i in 140 + i })
        XCTAssertEqual(segmenter.state, .work)
        // Walking flips to rest immediately. Peak captured at rest entry was 155 (or 154 if i=15 was the last sample).
        _ = tickFor(1, hr: 150, activity: .walking, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .rest)
        // Stay walking through 120s+ so the rest→work debounce doesn't fire.
        // The capture windows tolerate ±3s, so HRR-1 fires near i=56 (restElapsed ~57s)
        // and HRR-2 near i=116. Ramp HR DOWN before each window so the captured drop
        // is large: 150 → 130 at i=30, → 110 at i=90.
        let events = tickFor(125, hr: 0, activity: .walking, segmenter: &segmenter, cursor: &cursor, hrRamp: { i in
            if i < 30 { return 150 }
            if i < 90 { return 130 }
            return 110
        })
        let hrr1 = events.compactMap { if case let .hrrCapture(mark, drop) = $0, mark == 1 { return drop } else { return nil } }
        let hrr2 = events.compactMap { if case let .hrrCapture(mark, drop) = $0, mark == 2 { return drop } else { return nil } }
        XCTAssertEqual(hrr1.count, 1, "Exactly one HRR-1 capture expected")
        XCTAssertEqual(hrr2.count, 1, "Exactly one HRR-2 capture expected")
        // Peak (~155) − HR at 60s (130) = 25 drop.
        XCTAssertGreaterThanOrEqual(hrr1.first ?? -1, 20, "HRR-1 drop should reflect peak→60s decline")
        // Peak (~155) − HR at 120s (110) = 45 drop.
        XCTAssertGreaterThanOrEqual(hrr2.first ?? -1, 40, "HRR-2 drop should reflect peak→120s decline")
    }

    // candidateProgress is reachable and bounded while in idle candidate state.
    func testCandidateProgress_BoundedWhileIdle() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        XCTAssertEqual(segmenter.candidateProgress, 0)
        _ = tickFor(1, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        // candidateProgress is computed against wall-clock Date() at access time, so we just verify it's bounded.
        XCTAssertGreaterThanOrEqual(segmenter.candidateProgress, 0)
        XCTAssertLessThanOrEqual(segmenter.candidateProgress, 1)
    }

    // Walking during an idle candidate should reset the candidate.
    func testIdleCandidate_ResetByWalking() {
        var segmenter = RecoverySegmenter(config: cardiacConfig())
        var cursor = 0
        _ = tickFor(10, hr: 80, activity: .stationary, segmenter: &segmenter, cursor: &cursor, hrRamp: { 80 + $0 })
        XCTAssertEqual(segmenter.state, .idle, "Should still be in idle 10s in")
        _ = tickFor(2, hr: 90, activity: .walking, segmenter: &segmenter, cursor: &cursor)
        // Now sit stationary again for only 10s — should NOT trigger (candidate restarts).
        // We restart the HR ramp from a fresh baseline so the +6 BPM rise condition can be evaluated cleanly.
        _ = tickFor(10, hr: 90, activity: .stationary, segmenter: &segmenter, cursor: &cursor, hrRamp: { 90 + $0 })
        XCTAssertEqual(segmenter.state, .idle, "Walking should have reset the stationary candidate")
    }
}

// MARK: - Gym Strength Profile (legacy)

final class GymStrengthSegmenterTests: XCTestCase {

    // Elevated HR + motion sustained for minWorkDuration should enter work.
    func testIdleToWork_ElevatedHRAndMotion() {
        var segmenter = RecoverySegmenter(config: gymConfig())
        var cursor = 0
        let events = tickFor(13, hr: 150, activity: .running, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .work)
        XCTAssertEqual(segmenter.setNumber, 1)
        XCTAssertTrue(events.contains { if case .enteredWork(setNumber: 1) = $0 { return true } else { return false } })
    }

    // Elevated HR but no motion (stationary) should NOT enter work.
    func testIdleToWork_StationaryDoesNotTrigger() {
        var segmenter = RecoverySegmenter(config: gymConfig())
        var cursor = 0
        _ = tickFor(20, hr: 150, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .idle, "GymStrength requires motion, not just elevated HR")
    }

    // Work → rest: motion stops + peak HR clears the minWorkPeakHR floor.
    func testWorkToRest_MotionStopsWithSufficientPeakHR() {
        var segmenter = RecoverySegmenter(config: gymConfig())
        var cursor = 0
        _ = tickFor(13, hr: 150, activity: .running, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .work)
        // Stop motion (stationary) and wait through the restEntryDelay
        _ = tickFor(5, hr: 140, activity: .stationary, segmenter: &segmenter, cursor: &cursor)
        XCTAssertEqual(segmenter.state, .rest)
    }
}

// MARK: - Manual stations (cardiacRehab)
//
// New API for the explicit Start/End Station UX. In manual mode the segmenter
// only flips state via the public manualStartStation / manualEndStation calls;
// motion classification is ignored, but HRR captures + the rest-elapsed clock
// continue to fire from tick().

private func cardiacManualConfig() -> SegmenterConfig {
    var c = SegmenterConfig()
    c.profile = .cardiacRehab
    c.manualStationsOnly = true   // explicit (matches the post-Sprint-7 default)
    return c
}

final class ManualStationsSegmenterTests: XCTestCase {

    func testManualStartStation_FromIdle_EntersWork() {
        var segmenter = RecoverySegmenter(config: cardiacManualConfig())
        let events = segmenter.manualStartStation(hr: 120, now: baseDate)
        XCTAssertEqual(segmenter.state, .work)
        XCTAssertEqual(segmenter.setNumber, 1)
        XCTAssertTrue(events.contains { if case .enteredWork(setNumber: 1) = $0 { return true } else { return false } })
    }

    func testManualEndStation_FromWork_EntersRest_WithPeakHR() {
        var segmenter = RecoverySegmenter(config: cardiacManualConfig())
        var cursor = 0
        _ = segmenter.manualStartStation(hr: 110, now: baseDate)
        // 10 ticks of climbing HR — segmenter should track peak through tick().
        _ = tickFor(10, hr: 0, activity: .unknown, segmenter: &segmenter, cursor: &cursor,
                    hrRamp: { i in 110 + i })   // 110 → 119
        // Tap End Station. Peak HR seen = 119.
        let events = segmenter.manualEndStation(hr: 118, now: baseDate.addingTimeInterval(10))
        XCTAssertEqual(segmenter.state, .rest)
        // The .enteredRest event carries peakHR — confirm it matches what we ramped to.
        let peakInEvent: Int? = events.compactMap { e -> Int? in
            if case let .enteredRest(peakHR, _, _) = e { return peakHR } else { return nil }
        }.first
        XCTAssertEqual(peakInEvent, 119, "Peak HR should reflect ramped max during the manual station")
    }

    func testManualStartStation_DuringRest_RestExitedFiresWithDuration() {
        var segmenter = RecoverySegmenter(config: cardiacManualConfig())
        _ = segmenter.manualStartStation(hr: 120, now: baseDate)
        _ = segmenter.manualEndStation(hr: 140, now: baseDate.addingTimeInterval(60))
        // 30s into rest, patient taps Start Station for station 2.
        let events = segmenter.manualStartStation(hr: 105, now: baseDate.addingTimeInterval(90))
        XCTAssertEqual(segmenter.state, .work)
        XCTAssertEqual(segmenter.setNumber, 2)
        let restDuration: TimeInterval? = events.compactMap { e -> TimeInterval? in
            if case let .restExited(duration) = e { return duration } else { return nil }
        }.first
        XCTAssertEqual(restDuration ?? -1, 30, accuracy: 0.5,
                       "rest duration recorded should match the wall-clock gap")
    }

    func testManualMode_DoesNotAutoTransition_OnMotionClassification() {
        var segmenter = RecoverySegmenter(config: cardiacManualConfig())
        var cursor = 0
        // Even with the dual-condition signal that would trigger auto mode
        // (stationary 16s + HR rising past +6 BPM), manual mode should not
        // advance to .work.
        _ = tickFor(16, hr: 0, activity: .stationary, segmenter: &segmenter, cursor: &cursor,
                    hrRamp: { i in 80 + i })
        XCTAssertEqual(segmenter.state, .idle,
                       "Manual mode must not transition on motion classification")
    }

    func testHRRCaptures_StillFire_DuringManualRest() {
        var segmenter = RecoverySegmenter(config: cardiacManualConfig())
        var cursor = 0
        _ = segmenter.manualStartStation(hr: 150, now: baseDate)
        // tickFor doesn't advance state in manual mode but still tracks peak in .work.
        _ = tickFor(10, hr: 150, activity: .unknown, segmenter: &segmenter, cursor: &cursor)
        // End Station at cursor=10 with peak HR = 155.
        _ = segmenter.manualEndStation(hr: 155, now: baseDate.addingTimeInterval(10))
        // Drive rest forward via tick() — drop HR before each HRR window so the
        // captured drop is large.
        cursor = 10
        let events = tickFor(125, hr: 0, activity: .unknown, segmenter: &segmenter, cursor: &cursor,
                             hrRamp: { i in
                                 if i < 30  { return 150 }
                                 if i < 90  { return 130 }
                                 return 110
                             })
        let hrr1 = events.compactMap { if case let .hrrCapture(mark, drop) = $0, mark == 1 { return drop } else { return nil } }
        let hrr2 = events.compactMap { if case let .hrrCapture(mark, drop) = $0, mark == 2 { return drop } else { return nil } }
        XCTAssertEqual(hrr1.count, 1, "HRR-1 must fire during manual rest")
        XCTAssertEqual(hrr2.count, 1, "HRR-2 must fire during manual rest")
        XCTAssertGreaterThanOrEqual(hrr1.first ?? -1, 20, "drop should reflect 155→130")
        XCTAssertGreaterThanOrEqual(hrr2.first ?? -1, 40, "drop should reflect 155→110")
    }
}

// MARK: - Config defaults

final class SegmenterConfigTests: XCTestCase {

    func testDefaultProfile_IsGymStrength() {
        let c = SegmenterConfig()
        XCTAssertEqual(c.profile, .gymStrength)
    }

    func testCardiacRehab_DefaultThresholds() {
        var c = SegmenterConfig()
        c.profile = .cardiacRehab
        XCTAssertEqual(c.stationaryConfirmDuration, 15)
        XCTAssertEqual(c.hrRiseForWork, 6)
        XCTAssertEqual(c.workFallbackDuration, 45)
        XCTAssertEqual(c.walkStopConfirmDuration, 15)
    }

    func testManualStationsOnly_DefaultsTrue() {
        // Sprint-7 default flipped manual-on. Locking it down so future refactors
        // don't silently regress the cardiac-rehab UX back to auto-only.
        XCTAssertTrue(SegmenterConfig().manualStationsOnly)
    }
}
