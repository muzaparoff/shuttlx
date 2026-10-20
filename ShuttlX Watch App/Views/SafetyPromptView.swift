import SwiftUI

/// Full-screen "Still training?" prompt shown at 3h50m of active time
/// (`SafetyPromptSchedule`). No answer within 5 active minutes ends and saves
/// the workout — that timeout lives in WatchWorkoutManager, not here.
struct SafetyPromptView: View {
    let onContinue: () -> Void
    let onEndAndSave: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Still training?")
                .font(ShuttlXFont.cardTitle)
                .foregroundColor(ShuttlXColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("Ends and saves in 5 min if there's no answer.")
                .font(ShuttlXFont.cardCaption)
                .foregroundColor(ShuttlXColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onContinue) {
                Text("Continue")
                    .font(ShuttlXFont.watchControlLabel)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(ShuttlXColor.ctaPrimary)
            .accessibilityHint("Keeps the workout running")

            Button(action: onEndAndSave) {
                Text("End & Save")
                    .font(ShuttlXFont.watchControlLabel)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(ShuttlXColor.ctaDestructive)
            .accessibilityHint("Ends the workout and saves it")
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShuttlXColor.background.ignoresSafeArea())
        .contentShape(Rectangle())
    }
}
