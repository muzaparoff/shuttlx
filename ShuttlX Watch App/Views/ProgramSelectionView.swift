import SwiftUI
import os.log
import WatchConnectivity

struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var lastSession: TrainingSession?
    @State private var weekSessions: [TrainingSession] = []
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

                // Weekly stats
                if !weekSessions.isEmpty {
                    WeekStatsCard(sessions: weekSessions)
                }

                // Last workout expanded summary
                if let last = lastSession, !workoutManager.authorizationDenied {
                    LastWorkoutCard(session: last)
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
        .onAppear { loadSessions() }
    }

    private var isConnected: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    private func loadSessions() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
        guard let url = container?.appendingPathComponent("sessions.json"),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let sessions = try? JSONDecoder().decode([TrainingSession].self, from: data) else {
            return
        }

        let sorted = sessions.sorted(by: { $0.startDate > $1.startDate })
        lastSession = sorted.first

        // This week's sessions
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        weekSessions = sorted.filter { $0.startDate >= startOfWeek }
    }
}

// MARK: - Weekly Stats Card

private struct WeekStatsCard: View {
    let sessions: [TrainingSession]

    private var totalDistance: Double {
        sessions.compactMap(\.distance).reduce(0, +)
    }

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private var streakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        return uniqueDays.count
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("This Week")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Duration
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    Text(FormattingUtils.formatDuration(totalDuration))
                        .font(.caption.monospacedDigit().weight(.medium))
                }

                // Distance
                if totalDistance > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(FormattingUtils.formatDistance(totalDistance))
                            .font(.caption.monospacedDigit().weight(.medium))
                    }
                }

                // Streak
                if streakDays > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(streakDays)d")
                            .font(.caption.monospacedDigit().weight(.medium))
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week, \(sessions.count) sessions, \(FormattingUtils.formatDuration(totalDuration))")
    }
}

// MARK: - Last Workout Card (Expanded)

private struct LastWorkoutCard: View {
    let session: TrainingSession

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Last Workout")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Duration
            Text(FormattingUtils.formatDuration(session.duration))
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            // Metrics row
            HStack(spacing: 10) {
                if let distance = session.distance, distance > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(FormattingUtils.formatDistance(distance))
                            .font(.caption.monospacedDigit())
                    }
                }

                if let hr = session.averageHeartRate, hr > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(Int(hr))")
                            .font(.caption.monospacedDigit())
                    }
                }

                if let cal = session.caloriesBurned, cal > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(Int(cal))")
                            .font(.caption.monospacedDigit())
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.darkGray).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last workout, \(FormattingUtils.formatDuration(session.duration))")
    }

    private var relativeDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(session.startDate) { return "Today" }
        if calendar.isDateInYesterday(session.startDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: session.startDate)
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
