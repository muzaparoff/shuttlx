#if DEBUG
import Foundation
import os

/// DEBUG-only body counter (Wave 5 C2). Launch with `SHUTTLX_PRINT_CHANGES=1`: every counted
/// body emits an `OSSignposter` event (Instruments, "BodyCount") and the totals are logged
/// every 30 s as `[body] ...` (category BodyCount). Views also call `Self._printChanges()`.
@MainActor
enum BodyCounter {
    static let enabled = ProcessInfo.processInfo.environment["SHUTTLX_PRINT_CHANGES"] == "1"
    private static let signposter = OSSignposter(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "BodyCount")
    private static let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "BodyCount")
    private static var counts: [String: Int] = [:]
    private static var lastDump = Date()

    static func hit(_ name: StaticString) {
        guard enabled else { return }
        signposter.emitEvent(name)
        counts["\(name)", default: 0] += 1
        guard Date().timeIntervalSince(lastDump) >= 30 else { return }
        lastDump = Date()
        let line = counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.info("[body] \(line, privacy: .public)")
    }
}
#endif
