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

                // Free Run — hero card
                Button(action: {
                    logger.info("Start Free Run tapped")
                    workoutManager.startWorkout()
                }) {
                    VStack(spacing: ShuttlXSpacing.sm) {
                        Image(systemName: "figure.run")
                            .font(ShuttlXFont.watchHeroIcon)
                        Text("Free Run")
                            .font(ShuttlXFont.watchHeroTitle)
                        if lastWasFreeRun, let last = lastSession {
                            lastSubtitle(last)
                        }
                    }
                    .foregroundStyle(ShuttlXColor.iconOnCTA)
                    .padding(.vertical, ShuttlXSpacing.xl)
                }
                .buttonStyle(ShuttlXPrimaryCTAStyle())
                .padding(.horizontal, ShuttlXSpacing.xl)
                .accessibilityLabel("Start Free Run")
                .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

                // Templates list
                if !sharedDataManager.workoutTemplates.isEmpty {
                    VStack(alignment: .leading, spacing: ShuttlXSpacing.md) {
                        Text("Programs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, ShuttlXSpacing.xl)

                        ForEach(sharedDataManager.workoutTemplates) { template in
                            Button(action: {
                                logger.info("Starting interval workout: \(template.name)")
                                workoutManager.startIntervalWorkout(template: template)
                            }) {
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, ShuttlXSpacing.lg)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(ShuttlXCardButtonStyle())
                            .padding(.horizontal, ShuttlXSpacing.xl)
                            .accessibilityLabel("\(template.name), \(template.summaryText)")
                            .accessibilityHint("Start this interval workout")
                        }
                    }
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
        .onAppear { loadLastSession() }
    }

    // MARK: - Last Session Subtitle

    private func lastSubtitle(_ session: TrainingSession) -> some View {
        Text("Last: \(FormattingUtils.formatDuration(session.duration)) · \(relativeDate(session.startDate))")
            .font(.system(.caption2, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityLabel("Last workout \(FormattingUtils.formatDuration(session.duration)), \(relativeDate(session.startDate))")
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
