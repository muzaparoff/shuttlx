import XCTest
@testable import ShuttlXShared

final class ThemeIDTests: XCTestCase {
    func testRetiredAndUnknownIDsFallBackToClean() {
        XCTAssertEqual(ThemeID.resolve("mixtape"), "clean")
        XCTAssertEqual(ThemeID.resolve("nonsense"), "clean")
        XCTAssertEqual(ThemeID.resolve(nil), "clean")
    }

    func testCleanIsKept() {
        XCTAssertEqual(ThemeID.resolve("clean"), "clean")
    }
}
