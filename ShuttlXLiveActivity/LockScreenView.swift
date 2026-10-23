import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

// The extension does not link ShuttlXShared or the Theme files, so ShuttlXColor / ShuttlXFont
// are unavailable here. Colours below are the Clean theme's own values (.green running,
// .orange walking, .red heart rate / destructive) and fonts are system fonts at the sizes
// the mockup specifies.

typealias LAState = WorkoutActivityAttributes.ContentState

enum LAStyle {
    static func color(_ activity: String) -> Color {
        switch activity {
        case "running": return .green
        case "walking": return .orange
        default: return .secondary
        }
    }

    static func label(_ activity: String) -> String {
        switch activity {
        case "running": return "RUN"
        case "walking": return "WALK"
        default: return "WORKOUT"
        }
    }

    static func zoneColor(_ word: String) -> Color {
        word == "HARD" ? .red : .green
    }

    /// Heart red from the mockup (#FF6961), lighter than .red so it reads on black.
    static let heartRed = Color(red: 1.0, green: 0.412, blue: 0.38)

    static func formatTimer(_ interval: TimeInterval) -> String {
        let t = Int(interval)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

/// Elapsed time: system-ticking while running, static while paused (the watch stops broadcasting).
struct LATimer: View {
    let state: LAState
    var body: some View {
        Group {
            if state.isPaused {
                Text(LAStyle.formatTimer(state.elapsedTime))
            } else {
                Text(timerInterval: state.timerReferenceDate...Date.distantFuture, countsDown: false)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.leading)
    }
}

/// 7pt ribbon of parts so far; falls back to one capsule in the current activity colour.
struct LARibbon: View {
    let state: LAState
    var height: CGFloat = 7

    private var parts: [WorkoutActivityAttributes.Part] {
        if let p = state.parts, !p.isEmpty { return p }
        return [.init(activity: state.currentActivity, seconds: 1)]
    }

    var body: some View {
        let total = Double(max(1, parts.reduce(0) { $0 + $1.seconds }))
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Capsule()
                        .fill(LAStyle.color(part.activity))
                        .frame(width: max(6, geo.size.width * Double(part.seconds) / total))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

struct LAButtons: View {
    let state: LAState
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: PauseResumeWorkoutIntent(resume: state.isPaused)) {
                Text(state.isPaused ? "Resume" : "Pause")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            Button(intent: EndWorkoutIntent()) {
                Text("Finish…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.016, green: 0.129, blue: 0.05))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.green, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View { LockScreenCard(state: context.state) }
}

/// Pure-state card so a DEBUG host (and previews) can render it without an ActivityViewContext.
struct LockScreenCard: View {
    let state: LAState

    private var statusText: String {
        if state.isPaused { return state.pauseReason == "noMotion" ? "Paused – no motion" : "Paused" }
        return LAStyle.label(state.currentActivity)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("● \(statusText)")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(state.isPaused ? Color.orange : LAStyle.color(state.currentActivity))
                Spacer()
                Text("Apple Watch")
                    .font(.system(size: 12))
                    .opacity(0.7)
            }

            HStack(alignment: .center) {
                LATimer(state: state)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .foregroundStyle(state.isPaused ? .secondary : .primary)
                Spacer(minLength: 8)
                if state.heartRate > 0 {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(state.heartRate)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(LAStyle.heartRed)
                            Text("bpm")
                                .font(.system(size: 11))
                                .opacity(0.7)
                        }
                        if let zone = state.zoneWord {
                            Text(zone)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(LAStyle.zoneColor(zone))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Heart rate \(state.heartRate) beats per minute\(state.zoneWord.map { ", " + $0.lowercased() } ?? "")")
                }
            }

            LARibbon(state: state)
            LAButtons(state: state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(.black.opacity(0.75))
        // Tapping deep-links into ShuttlX (handled by ShuttlXApp.onOpenURL).
        .widgetURL(URL(string: "shuttlx://workout/active"))
    }
}
