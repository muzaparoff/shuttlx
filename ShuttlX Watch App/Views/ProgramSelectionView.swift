import SwiftUI
import os.log
import WatchConnectivity

struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var sharedDataManager: SharedDataManager
    @State private var lastSession: TrainingSession?
    #if DEBUG
    @State private var showingDebugView = false
    #endif

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "StartTrainingView")

    /// Whether the last session was a free run (no template)
    private var lastWasFreeRun: Bool {
        guard let last = lastSession else { return false }
        return last.templateID == nil
    }

    /// Returns the last session if it matches the given template
    private func lastSessionFor(template: WorkoutTemplate) -> TrainingSession? {
        guard let last = lastSession, last.templateID == template.id else { return nil }
        return last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                // Error states
                if workoutManager.authorizationDenied {
                    ErrorBanner(
                        icon: "heart.slash.fill",
                        message: "HealthKit access denied. Open Settings to enable.",
                        color: ShuttlXColor.heartRate
                    )
                    .padding(.horizontal, ShuttlXSpacing.md)
                }

                // Free Run card
                Button(action: {
                    logger.info("Start Free Run tapped")
                    workoutManager.startWorkout()
                }) {
                    HStack(spacing: ShuttlXSpacing.md) {
                        Image(systemName: "figure.run")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ShuttlXColor.running)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Free Run")
                                .font(ShuttlXFont.watchTemplateTitle)
                                .foregroundStyle(.primary)
                            if lastWasFreeRun, let last = lastSession {
                                lastSubtitle(last)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ShuttlXSpacing.lg)
                    .padding(.vertical, 10)
                }
                .buttonStyle(ShuttlXCardButtonStyle())
                .padding(.horizontal, ShuttlXSpacing.xl)
                .accessibilityLabel("Start Free Run")
                .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

                // Templates
                ForEach(sharedDataManager.workoutTemplates) { template in
                    Button(action: {
                        logger.info("Starting interval workout: \(template.name)")
                        workoutManager.startIntervalWorkout(template: template)
                    }) {
                        HStack(spacing: ShuttlXSpacing.md) {
                            Image(systemName: "flame.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ShuttlXColor.calories)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(ShuttlXFont.watchTemplateTitle)
                                    .foregroundStyle(.primary)
                                Text(template.summaryText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let last = lastSessionFor(template: template) {
                                    lastSubtitle(last)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ShuttlXSpacing.lg)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(ShuttlXCardButtonStyle())
                    .padding(.horizontal, ShuttlXSpacing.xl)
                    .accessibilityLabel("\(template.name), \(template.summaryText)")
                    .accessibilityHint("Start this interval workout")
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
            .padding(.vertical, ShuttlXSpacing.xs)
        }
        .navigationTitle("ShuttlX")
        .themedScreenBackground()
        .onAppear { loadLastSession() }
    }

    // MARK: - Last Session Subtitle

    private func lastSubtitle(_ session: TrainingSession) -> some View {
        let minutes = Int(session.duration / 60)
        return Text("Last: \(minutes)m · \(relativeDate(session.startDate))")
            .font(.system(.caption2, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityLabel("Last workout \(minutes) minutes, \(relativeDate(session.startDate))")
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
        HStack(spacing: ShuttlXSpacing.sm) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(ShuttlXSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: ShuttlXSpacing.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview {
    NavigationStack {
        StartTrainingView()
            .environmentObject(WatchWorkoutManager())
            .environmentObject(SharedDataManager.shared)
    }
}
