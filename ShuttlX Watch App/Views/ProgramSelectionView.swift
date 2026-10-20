import SwiftUI
import os.log
import WatchConnectivity

/// Watch home (timeline mockup screen 1): one Start button for free run and a
/// Programs row. Gym Recovery is no longer on Home — it stays reachable from
/// the iPhone (`startWatchWorkout` "gymRecovery" -> WatchSyncCoordinator).
struct StartTrainingView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var sharedDataManager: WatchSyncCoordinator

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "StartTrainingView")

    var body: some View {
        VStack(spacing: 0) {
            Text("SHUTTLX")
                .font(.system(size: WatchScale.pt(11), weight: .bold))
                .tracking(WatchScale.pt(11) * 0.08)
                .foregroundStyle(ShuttlXColor.ctaPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if workoutManager.authorizationDenied {
                ErrorBanner(icon: "heart.slash.fill",
                            message: "HealthKit access denied. Open Settings to enable.",
                            color: ShuttlXColor.heartRate)
                    .padding(.top, 4)
            } else if let error = workoutManager.startupError {
                ErrorBanner(icon: "exclamationmark.triangle.fill", message: error,
                            color: ShuttlXColor.ctaWarning)
                    .padding(.top, 4)
            }

            Button(action: {
                logger.info("Start Free Run tapped")
                #if os(watchOS)
                WKInterfaceDevice.current().play(.start)
                #endif
                workoutManager.startWorkout()
            }) {
                Group {
                    if workoutManager.isStarting && workoutManager.workoutMode == .freeRun {
                        ProgressView().tint(ShuttlXColor.iconOnCTA)
                    } else {
                        Text("Start")
                            .font(.system(size: WatchScale.pt(22), weight: .heavy))
                    }
                }
                .foregroundStyle(ShuttlXColor.iconOnCTA)
                .frame(width: WatchScale.pt(104), height: WatchScale.pt(104))
                .background(ShuttlXColor.ctaPrimary, in: Circle())
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, WatchScale.pt(12))
            .accessibilityLabel("Start Free Run")
            .accessibilityHint("Begins a free-form workout that finds running and walking by itself")

            Text("Free Run \u{00B7} finds Run / Walk itself")
                .font(.system(size: WatchScale.pt(11)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.top, WatchScale.pt(8))
                .accessibilityHidden(true)

            Spacer(minLength: 4)

            NavigationLink {
                ProgramsListView()
            } label: {
                HStack {
                    Text("Programs")
                    Spacer()
                    Text("\u{203A}").foregroundStyle(ShuttlXColor.textSecondary)
                }
                .font(.system(size: WatchScale.pt(13), weight: .semibold))
                .foregroundStyle(ShuttlXColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(ShuttlXColor.watchCardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Interval programs synced from your iPhone")
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black.ignoresSafeArea())
    }
}

/// Interval programs synced from the iPhone (was inline on the old Home).
struct ProgramsListView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @EnvironmentObject var sharedDataManager: WatchSyncCoordinator
    @State private var lastSession: TrainingSession?
    #if DEBUG
    @State private var showingDebugView = false
    #endif

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ProgramsListView")

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                if sharedDataManager.workoutTemplates.isEmpty {
                    Text("No programs yet. Make one on your iPhone.")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, ShuttlXSpacing.lg)
                }
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
                                if let last = lastSession, last.templateID == template.id {
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
            .padding(.horizontal, ShuttlXSpacing.xs)
        }
        .navigationTitle("Programs")
        .onAppear { loadLastSession() }
    }

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

    private func loadLastSession() {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared"
        )?.appendingPathComponent("sessions.json"),
        FileManager.default.fileExists(atPath: url.path) else { return }

        // Task.detached escapes @MainActor — decoding full session history must
        // not run on the main thread.
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
