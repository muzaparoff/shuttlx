import XCTest
@testable import ShuttlXShared

final class HeartSafetySettingsTests: XCTestCase {
    func testEstimateAndBetaBlocker() {
        var s = HeartSafetySettings()
        XCTAssertNil(s.effectiveUpperLimit(age: nil))
        XCTAssertEqual(s.effectiveUpperLimit(age: 60), 136)  // 0.85 * 160
        s.onBetaBlocker = true
        XCTAssertEqual(s.effectiveUpperLimit(age: 60), 110)  // 0.85 * 160 * 0.81 = 110.16
    }

    func testOwnLimitWins() {
        let s = HeartSafetySettings(onBetaBlocker: true, upperLimit: 120)
        XCTAssertEqual(s.effectiveUpperLimit(age: 40), 120)
    }

    func testZoneWordCutoffs() {
        let s = HeartSafetySettings(upperLimit: 100)
        XCTAssertEqual(s.zoneWord(hr: 69), "EASY")
        XCTAssertEqual(s.zoneWord(hr: 70), "STEADY")
        XCTAssertEqual(s.zoneWord(hr: 89), "STEADY")
        XCTAssertEqual(s.zoneWord(hr: 90), "HARD")
        XCTAssertNil(HeartSafetySettings().zoneWord(hr: 90))
    }

    func testWatchPayloadStripsMedicationAndResolvesLimit() throws {
        let s = HeartSafetySettings(onBetaBlocker: true, lowLimit: 50, useAirPodsHeartRate: true)
        let p = s.watchPayload(age: 60)
        XCTAssertNil(p.onBetaBlocker)
        XCTAssertEqual(p.upperLimit, 110)
        XCTAssertEqual(p.lowLimit, 50)
        XCTAssertFalse(p.useAirPodsHeartRate)
        let json = String(data: try JSONEncoder().encode(p), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("onBetaBlocker"))
    }

    /// Watch path: it only has the resolved payload (no age), and zoneWord must still work.
    func testZoneWordFromWatchPayloadNeedsNoAge() {
        let p = HeartSafetySettings().watchPayload(age: 60) // estimate 136
        XCTAssertEqual(p.zoneWord(hr: 90), "EASY")    // 0.66
        XCTAssertEqual(p.zoneWord(hr: 110), "STEADY") // 0.81
        XCTAssertEqual(p.zoneWord(hr: 125), "HARD")   // 0.92
    }

    func testDecodesPartialJSONWithDefaults() throws {
        let s = try JSONDecoder().decode(HeartSafetySettings.self, from: Data("{\"upperLimit\":150}".utf8))
        XCTAssertEqual(s.upperLimit, 150)
        XCTAssertTrue(s.alertNoMotion)
        XCTAssertNil(s.lowLimit)
    }

    func testWatchPayloadStripsMedicationNotes() {
        let s = HeartSafetySettings(onBetaBlocker: true, medicineName: "Metoprolol", dailyDose: "50 mg")
        let p = s.watchPayload(age: 60)
        XCTAssertNil(p.medicineName)
        XCTAssertNil(p.dailyDose)
        XCTAssertFalse(String(decoding: try! JSONEncoder().encode(p), as: UTF8.self).contains("Metoprolol"))
        XCTAssertEqual(s.medicineName, "Metoprolol")
    }

    func testEffortOnlyDropsLimitAndForcesEffortOn() {
        let s = HeartSafetySettings(upperLimit: 125, effortOnly: true, showEffortOnWatch: false)
        XCTAssertNil(s.effectiveUpperLimit(age: 60))
        XCTAssertNil(s.zoneWord(hr: 100, age: 60))
        let p = s.watchPayload(age: 60)
        XCTAssertNil(p.upperLimit)
        XCTAssertTrue(p.showEffortOnWatch)
    }

    func testBetaBlockerForcesEffortOnButOtherwiseRespectsToggle() {
        XCTAssertTrue(HeartSafetySettings(onBetaBlocker: true, showEffortOnWatch: false).watchPayload(age: nil).showEffortOnWatch)
        XCTAssertFalse(HeartSafetySettings(onBetaBlocker: false, showEffortOnWatch: false).watchPayload(age: nil).showEffortOnWatch)
    }

    func testNewFieldsDefaultWhenMissing() throws {
        let s = try JSONDecoder().decode(HeartSafetySettings.self, from: Data("{}".utf8))
        XCTAssertTrue(s.showEffortOnWatch && s.autoSwitchActivity)
        XCTAssertFalse(s.alertSuddenJump)   // off by default since settingsVersion 1
        XCTAssertEqual(s.noMotionSeconds, 60)
        XCTAssertEqual(s.heartRateSource, .best)
    }
}

final class HeartSafetyMigrationTests: XCTestCase {
    private func decode(_ json: String) throws -> HeartSafetySettings {
        try JSONDecoder().decode(HeartSafetySettings.self, from: Data(json.utf8))
    }

    func testNewInstallsHaveSuddenJumpOff() {
        XCTAssertFalse(HeartSafetySettings().alertSuddenJump)
        XCTAssertEqual(HeartSafetySettings().settingsVersion, HeartSafetySettings.currentVersion)
    }

    /// Saved before versioning: the old default was ON, the user never chose it.
    func testLegacyDefaultOnIsMigratedToOff() throws {
        XCTAssertFalse(try decode("{\"alertSuddenJump\":true,\"upperLimit\":140}").alertSuddenJump)
        XCTAssertFalse(try decode("{\"upperLimit\":140}").alertSuddenJump)
    }

    /// After the migration the version is saved, so a later explicit ON is kept across load/save cycles.
    func testExplicitLaterChoiceSurvives() throws {
        var s = try decode("{\"alertSuddenJump\":true}")
        s.alertSuddenJump = true
        let again = try JSONDecoder().decode(HeartSafetySettings.self, from: JSONEncoder().encode(s))
        XCTAssertTrue(again.alertSuddenJump)
        XCTAssertEqual(again.settingsVersion, HeartSafetySettings.currentVersion)
    }

    func testSanitizedDropsOutOfRangeLimits() {
        XCTAssertNil(HeartSafetySettings(upperLimit: 12).sanitized().upperLimit)
        XCTAssertNil(HeartSafetySettings(upperLimit: 400).sanitized().upperLimit)
        XCTAssertEqual(HeartSafetySettings(upperLimit: 150).sanitized().upperLimit, 150)
        XCTAssertEqual(HeartSafetySettings(upperLimit: 120, lowLimit: 115).sanitized().lowLimit, 110)   // clamped to keep the gap
        XCTAssertEqual(HeartSafetySettings(upperLimit: 120, lowLimit: 50).sanitized().lowLimit, 50)
    }

    /// Age 65 on a beta-blocker estimates 107 bpm, so the low limit may be at most 97. The watch applies the same
    /// range, so a typed 110 used to be dropped there while the phone still showed it.
    func testLowLimitIsClampedAgainstTheEstimatedUpperLimit() {
        let s = HeartSafetySettings(onBetaBlocker: true, lowLimit: 110)
        XCTAssertEqual(s.effectiveUpperLimit(age: 65), 107)
        XCTAssertEqual(s.clampedLowLimit(age: 65), 97)
        let p = s.watchPayload(age: 65)
        XCTAssertEqual(p.upperLimit, 107)
        XCTAssertEqual(p.lowLimit, 97)
        XCTAssertEqual(s.lowLimit, 110, "the phone's stored value is only changed by the screen that shows the note")
    }

    func testReconcileMovesTheStoredLowLimitAndSaysSo() {
        var s = HeartSafetySettings(onBetaBlocker: true, lowLimit: 110)
        XCTAssertEqual(s.reconcileLowLimit(age: 65), "Low limit changed to 97 bpm to stay 10 below the upper limit.")
        XCTAssertEqual(s.lowLimit, 97)
        XCTAssertNil(s.reconcileLowLimit(age: 65))
    }

    func testLowLimitWithinRangeIsUntouched() {
        XCTAssertEqual(HeartSafetySettings(onBetaBlocker: true, lowLimit: 90).watchPayload(age: 65).lowLimit, 90)
        XCTAssertNil(HeartSafetySettings(onBetaBlocker: true).watchPayload(age: 65).lowLimit)
    }

    func testHasNoLimit() {
        XCTAssertTrue(HeartSafetySettings().hasNoLimit(age: nil))
        XCTAssertFalse(HeartSafetySettings().hasNoLimit(age: 50))
        XCTAssertFalse(HeartSafetySettings(effortOnly: true).hasNoLimit(age: nil))
        XCTAssertFalse(HeartSafetySettings(upperLimit: 130).hasNoLimit(age: nil))
    }
}
