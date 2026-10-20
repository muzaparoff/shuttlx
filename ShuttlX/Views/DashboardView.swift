import SwiftUI
import ShuttlXShared

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @ObservedObject var sharedData = PhoneSyncCoordinator.shared
    @State private var cachedStreak: Int = 0
    @State private var showingPrograms = false
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
    @State private var lastSessionCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var todaySessions: [TrainingSession] {
        dataManager.sessions
            .filter { Calendar.current.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    private func consumePendingPrograms() {
        guard deepLinkRouter.showPrograms else { return }
        deepLinkRouter.showPrograms = false
        showingPrograms = true
    }

    private func refreshCachedData() {
        guard dataManager.sessions.count != lastSessionCount else { return }
        lastSessionCount = dataManager.sessions.count
        cachedStreak = computeStreak()
    }

    private func computeStreak() -> Int {
        let calendar = Calendar.current
        let sessions = dataManager.sessions
        guard !sessions.isEmpty else { return 0 }

        let workoutDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        if !workoutDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }

        return streak
    }

    private var emptyTodayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No workouts yet today")
                .font(ShuttlXFont.cardTitle)
                .foregroundStyle(ShuttlXColor.textPrimary)
            if !sharedData.isWorkoutActiveOnWatch {
                Button {
                    workoutController.presentFreeRun()
                } label: {
                    Label("Start Free Run on iPhone", systemImage: "figure.run")
                        .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.ctaPrimary)
                }
                .accessibilityHint("Starts an open-ended run on your iPhone")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
    }

    private var programsRow: some View {
        Button { showingPrograms = true } label: {
            HStack {
                Label("Programs & plans", systemImage: "calendar.badge.clock")
                    .font(ShuttlXFont.cardTitle)
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .padding(16)
            .themedCard()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint("Interval workouts and training plans")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(ShuttlXFont.cardSubtitle)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Today, \(Date.now.formatted(date: .complete, time: .omitted))")

                    // 1. Live workout card (when Watch workout is active)
                    if sharedData.isWorkoutActiveOnWatch {
                        LiveWorkoutCard(sharedData: sharedData)
                            .transition(reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )

                        // Inline live route map
                        if sharedData.liveRoutePoints.count >= 2 {
                            LiveRouteView(routePoints: sharedData.liveRoutePoints, compact: true)
                                .transition(.opacity)
                        }
                    }

                    // 2. Start on Watch card (when idle). Start-workout CTAs
                    // for iPhone-driven workouts (Free Run, Gym Recovery,
                    // every interval template) live in the Programs tab —
                    // the Dashboard stays focused on "what's happening now"
                    // (active workout widget + last session + week summary +
                    // streak), not "what could you start".
                    if !sharedData.isWorkoutActiveOnWatch {
                        StartOnWatchCard()
                    }

                    // 3. Today's sessions, oldest first (timeline)
                    if todaySessions.isEmpty {
                        emptyTodayCard
                    } else {
                        ForEach(todaySessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                TodaySessionCard(session: session)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }

                    // 4. Programs & plans
                    programsRow

                    // 5. Week summary
                    WeekSummaryCard(sessions: dataManager.sessions)

                    // 7. Streak badge
                    if cachedStreak > 1 {
                        StreakBadge(streakDays: cachedStreak)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Today")
            .navigationDestination(isPresented: $showingPrograms) { ProgramsTabView() }
            .task { consumePendingPrograms() }
            .onChange(of: deepLinkRouter.showPrograms) { consumePendingPrograms() }
            .onAppear { refreshCachedData() }
            .onChange(of: dataManager.sessions.count) { refreshCachedData() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: authManager.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                            .foregroundStyle(authManager.isSignedIn ? ShuttlXColor.ctaPrimary : .secondary)
                    }
                    .accessibilityLabel(authManager.isSignedIn ? "Settings, signed in" : "Settings, not signed in")
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: sharedData.isWorkoutActiveOnWatch)
            .themedScreenBackground()
        }
    }

}

/// One card of the Today timeline: time range, activity ribbon, headline numbers.
private struct TodaySessionCard: View {
    let session: TrainingSession

    private var timeRange: String {
        let end = session.endDate ?? session.startDate.addingTimeInterval(session.duration)
        return "\(session.startDate.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    private var stats: String {
        var parts = [FormattingUtils.formatDuration(session.duration)]
        if let km = session.distance, km > 0 { parts.append(FormattingUtils.formatDistance(km)) }
        if let hr = session.averageHeartRate, hr > 0 { parts.append("\(Int(hr)) BPM avg") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(timeRange)
                .font(ShuttlXFont.cardTitle.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textPrimary)
            if !session.segments.isEmpty {
                ActivityRibbon(segments: session.segments)
            }
            Text(stats)
                .font(ShuttlXFont.cardSubtitle.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .themedCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout \(timeRange), \(stats)")
        .accessibilityHint("Opens session details")
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
        .environmentObject(PlanManager())
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(DeepLinkRouter())
        .environmentObject(iPhoneWorkoutController())
}
