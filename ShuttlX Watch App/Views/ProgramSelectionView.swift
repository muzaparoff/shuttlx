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
        VStack(spacing: 0) {
            Spacer()

            // Error states
            if workoutManager.authorizationDenied {
                ErrorBanner(
                    icon: "heart.slash.fill",
                    message: "HealthKit access denied. Open Settings to enable.",
                    color: ShuttlXColor.heartRate
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Start button — the hero
            Button(action: {
                logger.info("Start Training tapped")
                workoutManager.startWorkout()
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 32, weight: .medium))
                    Text("Start")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel("Start Training")
            .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

            Spacer()

            // Last workout — compact inline
            if let last = lastSession, !workoutManager.authorizationDenied {
                lastWorkoutRow(last)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            #if DEBUG
            Button(action: { showingDebugView = true }) {
                Image(systemName: "ant")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
            #endif
        }
        .navigationTitle("ShuttlX")
        .onAppear { loadLastSession() }
    }

    // MARK: - Last Workout Row

    private func lastWorkoutRow(_ session: TrainingSession) -> some View {
        HStack(spacing: 8) {
            Text("Last")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(FormattingUtils.formatDuration(session.duration))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .monospacedDigit()

            if let distance = session.distance, distance > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text(FormattingUtils.formatDistance(distance))
                        .font(.caption2.monospacedDigit())
                }
            }

            if let hr = session.averageHeartRate, hr > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                    Text("\(Int(hr))")
                        .font(.caption2.monospacedDigit())
                }
            }

            Spacer()

            Text(relativeDate(session.startDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last workout, \(FormattingUtils.formatDuration(session.duration))")
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Data

    private func loadLastSession() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
        guard let url = container?.appendingPathComponent("sessions.json"),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let sessions = try? JSONDecoder().decode([TrainingSession].self, from: data) else {
            return
        }
        lastSession = sessions.max(by: { $0.startDate < $1.startDate })
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
