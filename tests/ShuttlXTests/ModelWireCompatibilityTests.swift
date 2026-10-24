import XCTest
@testable import ShuttlXShared

/// `Fixtures/session_v1.json` and `template_v1.json` were written by the per-target model copies
/// before they moved into the package (Wave 4 A0). Every store, WatchConnectivity payload and CloudKit
/// asset uses this JSON, so the shared models must read it and write it back unchanged.
final class ModelWireCompatibilityTests: XCTestCase {
    static func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// Every key path in a JSON value ("recoveryReport.captures[].hrAt60s").
    private func keyPaths(_ value: Any, _ prefix: String = "") -> Set<String> {
        if let dict = value as? [String: Any] {
            return dict.reduce(into: Set<String>()) { result, pair in
                let path = prefix.isEmpty ? pair.key : prefix + "." + pair.key
                result.insert(path)
                result.formUnion(keyPaths(pair.value, path))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: Set<String>()) { $0.formUnion(keyPaths($1, prefix + "[]")) }
        }
        return []
    }

    private func assertRoundTrip<T: Codable>(_ type: T.Type, fixture name: String,
                                             file: StaticString = #filePath, line: UInt = #line) throws {
        let original = try Self.fixture(name)
        let reencoded = try JSONEncoder().encode(JSONDecoder().decode(T.self, from: original))
        let before = try JSONSerialization.jsonObject(with: original)
        let after = try JSONSerialization.jsonObject(with: reencoded)
        XCTAssertEqual(keyPaths(after), keyPaths(before), file: file, line: line)
        XCTAssertEqual(after as? NSDictionary, before as? NSDictionary, "values changed", file: file, line: line)
    }

    func testSessionFixtureRoundTrips() throws {
        try assertRoundTrip(TrainingSession.self, fixture: "session_v1")
    }

    func testTemplateFixtureRoundTrips() throws {
        try assertRoundTrip(WorkoutTemplate.self, fixture: "template_v1")
    }

    func testSessionFixtureIsFullyPopulated() throws {
        let s = try JSONDecoder().decode(TrainingSession.self, from: Self.fixture("session_v1"))
        XCTAssertEqual(s.route?.count, 2)
        XCTAssertEqual(s.completedIntervalResults?.map(\.intervalType), [.work, .rest])
        XCTAssertEqual(s.recoveryReport?.averageHRR1, 22)
        XCTAssertEqual(s.kmSplits?.count, 1)
        XCTAssertEqual(s.completedIntervals?.count, 1)
        XCTAssertEqual(s.effortRPE, 5)
        XCTAssertEqual(s.autoEnded, false)
        XCTAssertEqual(s.pausedPeakHeartRate, 125)
        XCTAssertEqual(s.segments.count, 2)
        XCTAssertEqual(s.displayName, "Run/Walk 6x")
    }

    func testIntervalTypeRawValuesArePinned() {
        XCTAssertEqual(IntervalType.allCases.map(\.rawValue), ["warmup", "work", "rest", "cooldown"])
        XCTAssertEqual(IntervalType.allCases.map(\.displayName), ["Warm Up", "Work", "Rest", "Cool Down"])
    }
}
