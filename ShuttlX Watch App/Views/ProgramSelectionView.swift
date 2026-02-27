import SwiftUI
import os.log
import WatchConnectivity

struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var lastSession: TrainingSession?
    #if DEBUG
    @State private var showingDebugView = false
    #endif

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "StartTrainingView")

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Error states
                if workoutManager.authorizationDenied {
                    ErrorBanner(
                        icon: "heart.slash.fill",
                        message: "HealthKit access denied. Open Settings to enable.",
                        color: ShuttlXColor.heartRate
                    )
                }

                if !isConnected {
                    ErrorBanner(
                        icon: "iphone.slash",
                        message: "iPhone not connected",
                        color: .secondary
                    )
                }

                Spacer(minLength: 8)

                // Last workout mini-summary
                if let last = lastSession, !workoutManager.authorizationDenied {
                    LastWorkoutMini(session: last)
                }

                // Start button
                Button(action: {
                    logger.info("Start Training tapped")
                    workoutManager.startWorkout()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .font(.title3)
                        Text("Start")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start Training")
                .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

                Text("Auto-detects running & walking")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                #if DEBUG
                Button(action: { showingDebugView = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Debug")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .sheet(isPresented: $showingDebugView) {
                    DebugView()
                }
                #endif
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("ShuttlX")
        .onAppear { loadLastSession() }
    }

    private var isConnected: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    private func loadLastSession() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
        guard let url = container?.appendingPathComponent("sessions.json"),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let sessions = try? JSONDecoder().decode([TrainingSession].self, from: data) else {
            return
        }
        lastSession = sessions.sorted(by: { $0.startDate > $1.startDate }).first
    }
}

// MARK: - Last Workout Mini-Summary

private struct LastWorkoutMini: View {
    let session: TrainingSession

    var body: some View {
        VStack(spacing: 4) {
            Text("Last Workout")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(FormattingUtils.formatDuration(session.duration))
                        .font(.caption.monospacedDigit())
                }

                if let distance = session.distance, distance > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(FormattingUtils.formatDistance(distance))
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(ShuttlXColor.running)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.darkGray).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last workout, \(FormattingUtils.formatDuration(session.duration))")
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview {
    NavigationStack {
        StartTrainingView()
            .environmentObject(WatchWorkoutManager())
    }
}
