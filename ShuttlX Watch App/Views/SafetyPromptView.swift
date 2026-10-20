import SwiftUI
import WatchKit

/// Full-screen "Still training?" prompt shown at 3h50m of active time
/// (`SafetyPromptSchedule`). No answer within 5 active minutes ends and saves
/// the workout — that timeout lives in WatchWorkoutManager, not here.
struct SafetyPromptView: View {
    let onContinue: () -> Void
    let onEndAndSave: () -> Void

    var body: some View {
        WatchPromptCard {
            Text("Still training?")
                .font(.system(size: WatchScale.pt(19), weight: .heavy))
            Text("Ends and saves in 5 min if there's no answer.")
                .font(.system(size: WatchScale.pt(11)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, WatchScale.pt(4))
        } buttons: {
            Button("Continue", action: onContinue)
                .buttonStyle(WatchPillButtonStyle.primary)
                .accessibilityHint("Keeps the workout running")
            Button("End & Save", action: onEndAndSave)
                .buttonStyle(WatchPillButtonStyle.endAndSave)
                .accessibilityHint("Ends the workout and saves it")
        }
    }
}

/// Auto-paused by the presence heuristic (no heart rate and no motion).
struct AutoPausedView: View {
    let seconds: Int
    let onResume: () -> Void
    let onEndAndSave: () -> Void

    var body: some View {
        WatchPromptCard {
            Text("\u{23F8} PAUSED")
                .font(.system(size: WatchScale.pt(11), weight: .bold))
                .tracking(WatchScale.pt(11) * 0.08)
                .foregroundStyle(ShuttlXColor.ctaWarning)
            Text("Still training?")
                .font(.system(size: WatchScale.pt(17), weight: .heavy))
                .padding(.top, WatchScale.pt(6))
            Text("No heart rate for \(seconds) s.")
                .font(.system(size: WatchScale.pt(11)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.top, WatchScale.pt(3))
        } buttons: {
            Button("Resume", action: onResume)
                .buttonStyle(WatchPillButtonStyle.primary)
                .accessibilityHint("Resumes the workout")
            Button("End & Save", action: onEndAndSave)
                .buttonStyle(WatchPillButtonStyle.endAndSave)
                .accessibilityHint("Ends the workout and saves it")
        }
    }
}

/// Sudden heart-rate jump (HeartAlertEvaluator `.suddenJump`). Stays until tapped.
struct UnusualHeartRateView: View {
    let bpm: Int
    let rise: Int
    let onOK: () -> Void
    let onPause: () -> Void

    var body: some View {
        WatchPromptCard(background: LinearGradient(
            stops: [.init(color: ShuttlXColor.heartRate.opacity(0.22), location: 0),
                    .init(color: .black, location: 0.7)],
            startPoint: .top, endPoint: .bottom)) {
            Text("UNUSUAL HEART RATE")
                .font(.system(size: WatchScale.pt(11), weight: .bold))
                .tracking(WatchScale.pt(11) * 0.08)
                .foregroundStyle(ShuttlXColor.heartRate)
                .lineLimit(1)
                .fixedSize()
            Text("\(bpm)")
                .font(.system(size: WatchScale.pt(52), weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.heartRate)
                .fixedSize()
                .padding(.top, WatchScale.pt(6))
            Text("+\(rise) in 10 s")
                .font(.system(size: WatchScale.pt(12), weight: .bold))
        } buttons: {
            HStack(spacing: 6) {
                Button("OK", action: onOK)
                    .buttonStyle(WatchPillButtonStyle.neutral)
                Button("Pause", action: onPause)
                    .buttonStyle(WatchPillButtonStyle.warning)
                    .accessibilityHint("Pauses the workout")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unusual heart rate \(bpm), up \(rise) in 10 seconds")
    }
}

/// Centered message + full-width pill buttons over an opaque background that
/// swallows touches (an overlay, not a sheet, so no system close button).
struct WatchPromptCard<Message: View, Buttons: View, Background: View>: View {
    let background: Background
    @ViewBuilder let message: Message
    @ViewBuilder let buttons: Buttons

    init(background: Background = Color.black,
         @ViewBuilder message: () -> Message, @ViewBuilder buttons: () -> Buttons) {
        self.background = background
        self.message = message()
        self.buttons = buttons()
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) { message }
                .multilineTextAlignment(.center)
                .foregroundStyle(ShuttlXColor.textPrimary)
            VStack(spacing: 7) { buttons }
                .padding(.top, WatchScale.pt(10))
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque base: the card must hide the workout underneath it.
        .background(ZStack { Color.black; background }.ignoresSafeArea())
        .contentShape(Rectangle())
    }
}
