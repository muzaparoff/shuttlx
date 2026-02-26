import SwiftUI
import os.log

struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    #if DEBUG
    @State private var showingDebugView = false
    #endif

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "StartTrainingView")

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .accessibilityHidden(true)

            Button(action: {
                logger.info("Start Training tapped")
                workoutManager.startWorkout()
            }) {
                Text("Start Training")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Start Training")
            .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

            Text("Auto-detects running & walking")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            #if DEBUG
            Button(action: {
                showingDebugView = true
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Debug")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .accessibilityLabel("Debug Info")
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
            #endif
        }
        .padding()
        .navigationTitle("ShuttlX")
    }
}

#Preview {
    NavigationView {
        StartTrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
