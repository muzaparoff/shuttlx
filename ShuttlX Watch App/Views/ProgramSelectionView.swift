import SwiftUI
import os.log
import WatchConnectivity
import ShuttlXShared

/// Watch home: the two programs. Run/Walk = the big Start (free run, finds run and
/// walk itself); Mixed = Heart Recovery (gym) and the interval programs list. The
/// iPhone can still start gym recovery too (`"gymRecovery"` -> WatchSyncCoordinator).
struct StartTrainingView: View {
    @Environment(WatchWorkoutManager.self) var workoutManager
    @Environment(WatchSyncCoordinator.self) var sharedDataManager

    /// This week's active minutes (D1 ring); nil until the first read.
    @State private var weekMinutes: Int?

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "StartTrainingView")

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let weekMinutes {
                    Text("\(weekMinutes) of \(WeekMinutes.goal) min")
                        .accessibilityLabel("This week")
                        .accessibilityValue("\(weekMinutes) of \(WeekMinutes.goal) minutes")
                } else {
                    Text("SHUTTLX")
                }
            }
                .font(.system(size: WatchScale.text(11), weight: .bold))
                .tracking(WatchScale.text(11) * 0.08)
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.ctaPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if workoutManager.authorizationDenied {
                ErrorBanner(icon: "heart.slash.fill",
                            message: "Allow Health access in the Health app on your iPhone.",
                            color: ShuttlXColor.heartRate)
                    .padding(.top, 4)
            } else if let error = workoutManager.startupError {
                ErrorBanner(icon: "exclamationmark.triangle.fill", message: error,
                            color: ShuttlXColor.ctaWarning)
                    .padding(.top, 4)
            }

            Button(action: {
                logger.info("Start Run/Walk tapped")
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
            // D1: thin static week ring around Start, drawn outside the layout (no
            // added height). Dim so it never reads as a pressed or selected state.
            .background {
                GlassRing(progress: Double(weekMinutes ?? 0) / Double(WeekMinutes.goal),
                          accentColor: ShuttlXColor.ctaPrimary.opacity(0.4),
                          trackOpacity: 0.35, lineWidth: WatchScale.pt(3))
                    .frame(width: WatchScale.pt(104) + 2 * WatchScale.pt(6),
                           height: WatchScale.pt(104) + 2 * WatchScale.pt(6))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.top, WatchScale.pt(12))
            .accessibilityLabel("Start Run/Walk")
            .accessibilityHint("Begins an open-ended workout that finds running and walking by itself")

            Text("Run/Walk")
                .font(.system(size: WatchScale.text(11)))
                .foregroundStyle(ShuttlXColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.top, WatchScale.pt(8))
                .accessibilityHidden(true)

            Spacer(minLength: 4)

            NavigationLink {
                ProgramsListView()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Mixed")
                    Spacer(minLength: 4)
                    Text("Intervals \u{203A}")
                        .font(.system(size: WatchScale.text(11)))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
                .font(.system(size: WatchScale.pt(13), weight: .semibold))
                .foregroundStyle(ShuttlXColor.textPrimary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .secondaryGlass(ShuttlXColor.watchCardBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mixed")
            .accessibilityHint("Interval programs synced from your iPhone")
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black.ignoresSafeArea())
        // Home reappears after every workout (summary Done), so this also refreshes then.
        .task { weekMinutes = await loadWeekMinutes() }
    }

    private func loadWeekMinutes() async -> Int {
        #if DEBUG
        if let fake = ProcessInfo.processInfo.environment["SHUTTLX_SNAPSHOT_WEEKMIN"].flatMap(Int.init) { return fake }
        #endif
        return await sharedDataManager.thisWeekMinutes()
    }
}

/// "Mixed": Heart Recovery (gym sets with rest checks) first, then the interval
/// programs synced from the iPhone.
struct ProgramsListView: View {
    @Environment(WatchWorkoutManager.self) var workoutManager
    @Environment(WatchSyncCoordinator.self) var sharedDataManager
    @State private var lastSession: TrainingSession?
    #if DEBUG
    @State private var showingDebugView = false
    #endif

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ProgramsListView")

    var body: some View {
        ScrollView {
            VStack(spacing: ShuttlXSpacing.lg) {
                heartRecoveryRow

                if sharedDataManager.workoutTemplates.isEmpty {
                    Text("Add interval programs on your iPhone.")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .multilineTextAlignment(.center)
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
                    .buttonStyle(WatchGlassRowButtonStyle())
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
        .navigationTitle("Mixed")
        .onAppear { loadLastSession() }
    }

    /// Starts gym recovery on the watch alone (no phone needed), like the template rows.
    /// The heart sits inline with the title (no icon column), so on 40mm the title
    /// keeps one line and the subtitle gets the full row width (two lines at most).
    private var heartRecoveryRow: some View {
        let title = "Heart Recovery"
        // Row content width: list padding (xs) and row padding (lg) on both sides.
        let contentWidth = WatchScale.width - 2 * ShuttlXSpacing.xs - 2 * ShuttlXSpacing.lg
        let gap: CGFloat = 4
        // Solved, not scaled: semibold advance ~0.6em per glyph plus a 1em icon.
        let titleSize = min(WatchScale.pt(17), (contentWidth - gap) / (CGFloat(title.count) * 0.6 + 1))
        return Button(action: {
            logger.info("Starting heart recovery workout")
            #if os(watchOS)
            WKInterfaceDevice.current().play(.start)
            #endif
            workoutManager.startGymRecoveryWorkout(phoneSessionID: nil)
        }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: gap) {
                    if workoutManager.isStarting && workoutManager.workoutMode == .gymRecovery {
                        ProgressView()
                            .frame(width: titleSize, height: titleSize)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: titleSize * 0.9, weight: .semibold))
                            .foregroundStyle(ShuttlXColor.heartRate)
                            .frame(width: titleSize)
                    }
                    Text(title)
                        .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(ShuttlXColor.textPrimary)
                        .fixedSize()
                }
                Text("Sets with rest checks")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ShuttlXSpacing.lg)
            .padding(.vertical, ShuttlXSpacing.md)
        }
        .buttonStyle(WatchGlassRowButtonStyle())
        .accessibilityLabel("Heart Recovery, sets with rest checks")
        .accessibilityHint("Starts a gym session. You start and end each set yourself.")
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
            .environment(WatchWorkoutManager())
            .environment(WatchSyncCoordinator.shared)
    }
}
