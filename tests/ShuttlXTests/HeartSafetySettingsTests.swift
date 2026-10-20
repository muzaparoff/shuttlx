import XCTest
@testable import ShuttlXShared

final class HeartSafetySettingsTests: XCTestCase {
    func testEstimateAndBetaBlocker() {
        var s = HeartSafetySettings()
        XCTAssertNil(s.effectiveUpperLimit(age: nil))
        XCTAssertEqual(s.effectiveUpperLimit(age: 60), 160)
        s.onBetaBlocker = true
        XCTAssertEqual(s.effectiveUpperLimit(age: 60), 130) // 160 * 0.81 = 129.6
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
        XCTAssertEqual(p.upperLimit, 130)
        XCTAssertEqual(p.lowLimit, 50)
        XCTAssertFalse(p.useAirPodsHeartRate)
        let json = String(data: try JSONEncoder().encode(p), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("onBetaBlocker"))
    }

    /// Watch path: it only has the resolved payload (no age), and zoneWord must still work.
    func testZoneWordFromWatchPayloadNeedsNoAge() {
        let p = HeartSafetySettings().watchPayload(age: 60) // estimate 160
        XCTAssertEqual(p.zoneWord(hr: 100), "EASY")   // 0.625
        XCTAssertEqual(p.zoneWord(hr: 130), "STEADY") // 0.81
        XCTAssertEqual(p.zoneWord(hr: 150), "HARD")   // 0.94
    }

    func testDecodesPartialJSONWithDefaults() throws {
        let s = try JSONDecoder().decode(HeartSafetySettings.self, from: Data("{\"upperLimit\":150}".utf8))
        XCTAssertEqual(s.upperLimit, 150)
        XCTAssertTrue(s.alertNoMotion)
        XCTAssertNil(s.lowLimit)
    }
}
