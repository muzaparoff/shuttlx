import XCTest
@testable import ShuttlXShared

final class MedicineVaultTests: XCTestCase {
    private final class Memory: SecretBackend {
        var items: [String: String] = [:]
        func read(_ key: String) -> String? { items[key] }
        func write(_ key: String, _ value: String?) -> Bool { items[key] = value; return true }
    }

    /// A Keychain that refuses to store (locked device, full, entitlement problem).
    private final class Failing: SecretBackend {
        func read(_ key: String) -> String? { nil }
        func write(_ key: String, _ value: String?) -> Bool { value == nil }
    }

    private var memory = Memory()
    private let suite = UserDefaults(suiteName: "group.com.shuttlx.shared")
    private var savedBackend: SecretBackend?
    private var savedJSON: Data?

    override func setUp() {
        savedBackend = MedicineVault.backend
        savedJSON = suite?.data(forKey: HeartSafetySettings.defaultsKey)
        memory = Memory()
        MedicineVault.backend = memory
    }

    override func tearDown() {
        if let savedBackend { MedicineVault.backend = savedBackend }
        if let savedJSON { suite?.set(savedJSON, forKey: HeartSafetySettings.defaultsKey) }
        else { suite?.removeObject(forKey: HeartSafetySettings.defaultsKey) }
    }

    func testSaveKeepsNotesOutOfDefaults() throws {
        HeartSafetySettings(upperLimit: 120, medicineName: "Metoprolol", dailyDose: "50 mg").saveForEditing()
        let json = try XCTUnwrap(suite?.data(forKey: HeartSafetySettings.defaultsKey))
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("Metoprolol"))
        XCTAssertEqual(memory.items["name"], "Metoprolol")
        let plain = HeartSafetySettings.load()
        XCTAssertNil(plain.medicineName)
        XCTAssertEqual(plain.upperLimit, 120)
        XCTAssertEqual(HeartSafetySettings.loadForEditing().dailyDose, "50 mg")
    }

    func testPlainSaveDoesNotEraseVault() {
        HeartSafetySettings(medicineName: "Bisoprolol").saveForEditing()
        HeartSafetySettings.load().save()   // e.g. a toggle in Settings
        XCTAssertEqual(MedicineVault.name, "Bisoprolol")
    }

    func testLegacyJSONIsMigratedOnce() throws {
        // What an older build wrote: the notes inside the UserDefaults JSON.
        let legacy = HeartSafetySettings(upperLimit: 110, medicineName: "Metoprolol", dailyDose: "25 mg")
        suite?.set(try JSONEncoder().encode(legacy), forKey: HeartSafetySettings.defaultsKey)
        let loaded = HeartSafetySettings.load()
        XCTAssertNil(loaded.medicineName)
        XCTAssertEqual(MedicineVault.name, "Metoprolol")
        XCTAssertEqual(MedicineVault.dose, "25 mg")
        let json = try XCTUnwrap(suite?.data(forKey: HeartSafetySettings.defaultsKey))
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("Metoprolol"))
        XCTAssertEqual(HeartSafetySettings.load().upperLimit, 110)
    }

    func testLegacyNotesStayInJSONWhenTheKeychainWriteFails() throws {
        MedicineVault.backend = Failing()
        let legacy = HeartSafetySettings(upperLimit: 110, medicineName: "Metoprolol", dailyDose: "25 mg")
        suite?.set(try JSONEncoder().encode(legacy), forKey: HeartSafetySettings.defaultsKey)
        let loaded = HeartSafetySettings.load()
        XCTAssertNil(loaded.medicineName, "callers of load() never see the notes")
        var json = String(decoding: try XCTUnwrap(suite?.data(forKey: HeartSafetySettings.defaultsKey)), as: UTF8.self)
        XCTAssertTrue(json.contains("Metoprolol"), "the only copy must not be erased")
        // An ordinary save (a toggle in Settings) must not erase it either.
        HeartSafetySettings.load().save()
        json = String(decoding: try XCTUnwrap(suite?.data(forKey: HeartSafetySettings.defaultsKey)), as: UTF8.self)
        XCTAssertTrue(json.contains("Metoprolol"))
        // Keychain works again: the next load moves it and strips the JSON.
        MedicineVault.backend = memory
        _ = HeartSafetySettings.load()
        XCTAssertEqual(MedicineVault.name, "Metoprolol")
        json = String(decoding: try XCTUnwrap(suite?.data(forKey: HeartSafetySettings.defaultsKey)), as: UTF8.self)
        XCTAssertFalse(json.contains("Metoprolol"))
    }

    func testClearEmptiesTheVault() {
        MedicineVault.name = "Bisoprolol"
        MedicineVault.dose = "5 mg"
        MedicineVault.clear()
        XCTAssertNil(MedicineVault.name)
        XCTAssertNil(MedicineVault.dose)
    }
}
