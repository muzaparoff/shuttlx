import SwiftUI
import WidgetKit
import AppIntents

// MARK: - W2: Quick Start Control (iOS 18 Control Center / Lock Screen / Action button)
//
// `OpenURLIntent` is a system-provided AppIntent (AppIntents framework) whose
// entire purpose is "open this URL" — using it directly as the control's
// action is the cleanest compiling form for iOS 18 and avoids hand-rolling a
// custom AppIntent that just re-wraps `OpenURLIntent` internally. Tapping the
// control opens the app via `shuttlx://start-freerun`, which
// `ShuttlXApp.onOpenURL` already routes to `startWatchWorkoutWithRetry(mode:
// "freeRun")`.
//
// Monochrome system tint only — Controls render as SF Symbol + label with no
// per-theme art (design system: "no per-theme icon sets" anti-goal).

struct QuickStartControl: ControlWidget {
    /// `URL(string:)` on a fixed, compile-time-valid literal never fails in
    /// practice; the `??` fallback avoids a force unwrap without changing
    /// behavior (the fallback branch is unreachable).
    private static let freeRunURL: URL = URL(string: "shuttlx://start-freerun")
        ?? URL(fileURLWithPath: "/dev/null")

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.shuttlx.ShuttlX.QuickStartControl") {
            ControlWidgetButton(action: OpenURLIntent(Self.freeRunURL)) {
                Label("Start Free Run", systemImage: "figure.run")
            }
        }
        .displayName("Start Free Run")
        .description("Starts a Free Run workout on your Apple Watch.")
    }
}
