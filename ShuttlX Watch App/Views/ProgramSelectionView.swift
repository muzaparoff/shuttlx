import SwiftUI
import os.log
import WatchConnectivity

struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var sharedDataManager: WatchSyncCoordinator
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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                // Greeting header
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(ShuttlXFont.watchHeroTitle)
                        .foregroundStyle(ShuttlXColor.textPrimary)

                    if let last = lastSession {
                        let minutes = Int(last.duration / 60)
                        Text("Last: \(minutes)m \(relativeDate(last.startDate))")
                            .font(ShuttlXFont.cardCaption)
                            .monospacedDigit()
                            .foregroundStyle(ShuttlXColor.textSecondary)
                    } else {
                        Text("Ready to train?")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(ShuttlXColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ShuttlXSpacing.xl)

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
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.start)
                    #endif
                    workoutManager.startWorkout()
                }) {
                    HStack(spacing: ShuttlXSpacing.md) {
                        if workoutManager.isStarting && workoutManager.workoutMode == .freeRun {
                            ProgressView()
                                .frame(width: 28)
                        } else {
                            Image(systemName: "figure.run")
                                .font(ShuttlXFont.watchTemplateTitle)
                                .foregroundStyle(ShuttlXColor.running)
                                .frame(width: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Free Run")
                                .font(ShuttlXFont.watchTemplateTitle)
                                .foregroundStyle(ShuttlXColor.textPrimary)
                            if lastWasFreeRun, let last = lastSession {
                                lastSubtitle(last)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ShuttlXSpacing.lg)
                    .padding(.vertical, ShuttlXSpacing.md)
                }
                .buttonStyle(ShuttlXCardButtonStyle())
                .padding(.horizontal, ShuttlXSpacing.xl)
                .accessibilityLabel("Start Free Run")
                .accessibilityHint("Begins a free-form workout that auto-detects running and walking")

                // Gym Heart Recovery card
                Button(action: {
                    logger.info("Start Gym Recovery tapped")
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.start)
                    #endif
                    workoutManager.startGymRecoveryWorkout()
                }) {
                    HStack(spacing: ShuttlXSpacing.md) {
                        if workoutManager.isStarting && workoutManager.workoutMode == .gymRecovery {
                            ProgressView()
                                .frame(width: 28)
                        } else {
                            Image(systemName: "heart.circle.fill")
                                .font(ShuttlXFont.watchTemplateTitle)
                                .foregroundStyle(ShuttlXColor.heartRate)
                                .frame(width: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gym Recovery")
                                .font(ShuttlXFont.watchTemplateTitle)
                                .foregroundStyle(ShuttlXColor.textPrimary)
                            Text("HR recovery between sets")
                                .font(ShuttlXFont.cardCaption)
                                .foregroundStyle(ShuttlXColor.textSecondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ShuttlXSpacing.lg)
                    .padding(.vertical, ShuttlXSpacing.md)
                }
                .buttonStyle(ShuttlXCardButtonStyle())
                .padding(.horizontal, ShuttlXSpacing.xl)
                .accessibilityLabel("Start Gym Recovery session")
                .accessibilityHint("Monitors heart rate recovery between your gym sets automatically")

                // Templates
                ForEach(sharedDataManager.workoutTemplates) { template in
                    Button(action: {
                        logger.info("Starting interval workout: \(template.name)")
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.start)
                        #endif
                        workoutManager.startIntervalWorkout(template: template)
                    }) {
                        HStack(spacing: ShuttlXSpacing.md) {
                            if workoutManager.isStarting && workoutManager.workoutName == template.name {
                                ProgressView()
                                    .frame(width: 28)
                            } else {
                                Image(systemName: "flame.fill")
                                    .font(ShuttlXFont.watchTemplateTitle)
                                    .foregroundStyle(ShuttlXColor.calories)
                                    .frame(width: 28)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(ShuttlXFont.watchTemplateTitle)
                                    .foregroundStyle(ShuttlXColor.textPrimary)
                                Text(template.summaryText)
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(ShuttlXColor.textSecondary)
                                if let last = lastSessionFor(template: template) {
                                    lastSubtitle(last)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ShuttlXSpacing.lg)
                        .padding(.vertical, ShuttlXSpacing.md)
                    }
                    .buttonStyle(ShuttlXCardButtonStyle())
                    .padding(.horizontal, ShuttlXSpacing.xl)
                    .accessibilityLabel("\(template.name), \(template.summaryText)")
                    .accessibilityHint("Start this interval workout")
                }

                #if DEBUG
                Button(action: { showingDebugView = true }) {
                    Image(systemName: "ant")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                .sheet(isPresented: $showingDebugView) {
                    DebugView()
                }
                #endif
            }
            .padding(.vertical, ShuttlXSpacing.xs)
        }
        .navigationTitle("")
        .themedScreenBackground()
        .onAppear { loadLastSession() }
    }

    // MARK: - Last Session Subtitle

    private func lastSubtitle(_ session: TrainingSession) -> some View {
        let minutes = Int(session.duration / 60)
        return Text("Last: \(minutes)m \(relativeDate(session.startDate))")
            .font(ShuttlXFont.cardCaption)
            .monospacedDigit()
            .foregroundStyle(ShuttlXColor.textSecondary)
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
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared"
        )?.appendingPathComponent("sessions.json"),
        FileManager.default.fileExists(atPath: url.path) else { return }

        // Task.detached escapes @MainActor — Data(contentsOf:) + JSONDecoder must
        // not run on the main thread (decoding full session history blocks UI).
        Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url),
                  let sessions = try? JSONDecoder().decode([TrainingSession].self, from: data) else { return }
            let last = sessions.max(by: { $0.startDate < $1.startDate })
            await MainActor.run { lastSession = last }
        }
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
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(color)
            Text(message)
                .font(ShuttlXFont.watchControlLabel)
                .foregroundStyle(ShuttlXColor.textSecondary)
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
            .environmentObject(WatchSyncCoordinator.shared)
    }
}
