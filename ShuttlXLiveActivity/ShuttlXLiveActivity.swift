import ActivityKit
import WidgetKit
import SwiftUI

struct ShuttlXLiveActivity: Widget {
    private static let url = URL(string: "shuttlx://workout/active")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LATimer(state: state)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundStyle(state.isPaused ? .secondary : .primary)
                        .widgetURL(Self.url)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.heartRate > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(state.heartRate)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(LAStyle.heartRed)
                            Text("bpm").font(.system(size: 11)).opacity(0.7)
                            if let zone = state.zoneWord {
                                Text(zone)
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(LAStyle.zoneColor(zone))
                                    .padding(.leading, 4)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        LARibbon(state: state)
                        LAButtons(state: state)
                    }
                }
            } compactLeading: {
                // "● 48:12" — dot in the activity colour, then the clock. Width-clamped:
                // the timer is wider than a fixed string once past an hour.
                HStack(spacing: 3) {
                    Text("●")
                        .font(.system(size: 9))
                        .foregroundStyle(state.isPaused ? Color.orange : LAStyle.color(state.currentActivity))
                    LATimer(state: state)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 52, alignment: .leading)
                }
            } compactTrailing: {
                if state.heartRate > 0 {
                    Text("♥ \(state.heartRate)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(LAStyle.heartRed)
                }
            } minimal: {
                Text("●")
                    .foregroundStyle(state.isPaused ? Color.orange : LAStyle.color(state.currentActivity))
            }
            .widgetURL(Self.url)
        }
    }
}

#if DEBUG
private let previewState = LAState(
    elapsedTime: 48 * 60 + 12, heartRate: 152, distance: 6.9, calories: 410,
    currentActivity: "running", isPaused: false, pace: 358,
    zoneWord: "STEADY",
    parts: [.init(activity: "walking", seconds: 720), .init(activity: "running", seconds: 2160)],
    timerReferenceDate: Date().addingTimeInterval(-2892))

#Preview("Lock screen", as: .content, using: WorkoutActivityAttributes(workoutStartDate: Date(), activityType: "running")) {
    ShuttlXLiveActivity()
} contentStates: {
    previewState
}
#endif
