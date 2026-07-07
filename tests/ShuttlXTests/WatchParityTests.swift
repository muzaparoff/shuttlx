import XCTest

/// Guards against drift between `Shared/RecoverySegmenter.swift` (the canonical
/// ShuttlXShared copy, covered by RecoverySegmenterTests) and the watch target's
/// `ShuttlX Watch App/Services/RecoverySegmenter.swift`, which is a semantically
/// identical duplicate kept only until the watch target adopts ShuttlXShared.
///
/// The two files are allowed to differ ONLY in:
///   - `public` access modifiers (package copy is public, watch copy internal)
///   - `Sendable` conformances (package copy declares them)
///   - the explicit `init() {}` the package copy needs for public visibility
///   - comments and blank lines
///
/// Any other difference means the copies have functionally diverged and the
/// 19 RecoverySegmenterTests no longer vouch for the watch's behavior.
/// If this test fails: re-align the two files (or finish the ShuttlXShared
/// migration and delete the watch copy — see docs/plans/2026-07-codebase-refactor-plan.md Phase 4).
final class WatchParityTests: XCTestCase {

    func testWatchRecoverySegmenterMatchesSharedCopy() throws {
        let root = packageRoot()
        let shared = root.appendingPathComponent("Shared/RecoverySegmenter.swift")
        let watch = root.appendingPathComponent("ShuttlX Watch App/Services/RecoverySegmenter.swift")

        let sharedLines = try normalize(contentsOf: shared)
        let watchLines = try normalize(contentsOf: watch)

        if sharedLines != watchLines {
            let count = min(sharedLines.count, watchLines.count)
            var firstDiff = "one file is a prefix of the other (line counts: shared \(sharedLines.count), watch \(watchLines.count))"
            for i in 0..<count where sharedLines[i] != watchLines[i] {
                firstDiff = "first difference at normalized line \(i + 1):\n  shared: \(sharedLines[i])\n  watch:  \(watchLines[i])"
                break
            }
            XCTFail("""
            Watch RecoverySegmenter has drifted from Shared/RecoverySegmenter.swift — \
            the shared test suite no longer vouches for watch behavior. \
            Re-align the copies or complete the ShuttlXShared migration.
            \(firstDiff)
            """)
        }
    }

    // MARK: - Helpers

    /// tests/ShuttlXTests/WatchParityTests.swift → repo root is two levels up.
    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ShuttlXTests
            .deletingLastPathComponent() // tests
            .deletingLastPathComponent() // repo root
    }

    /// Strips the differences the two copies are allowed to have, so anything
    /// left unequal is a real functional divergence.
    private func normalize(contentsOf url: URL) throws -> [String] {
        let source = try String(contentsOf: url, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .map { line -> String in
                var l = line
                if let commentRange = l.range(of: "//") {
                    l = String(l[..<commentRange.lowerBound])
                }
                l = l.replacingOccurrences(of: "public ", with: "")
                l = l.replacingOccurrences(of: ", Sendable", with: "")
                l = l.replacingOccurrences(of: ": Sendable", with: "")
                return l.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty && $0 != "init() {}" }
    }
}
