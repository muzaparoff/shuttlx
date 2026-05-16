import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var workoutController: iPhoneWorkoutController
    @ObservedObject var sharedData = SharedDataManager.shared
    @State private var cachedStreak: Int = 0
    @State private var cachedLastSession: TrainingSession?
    @State private var lastSessionCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var greetingTitle: String {
        if authManager.isSignedIn, let name = authManager.userName {
            let firstName = name.components(separatedBy: " ").first ?? name
            return "Hi, \(firstName)"
        }
        return "Training"
    }

    private func refreshCachedData() {
        guard dataManager.sessions.count != lastSessionCount else { return }
        lastSessionCount = dataManager.sessions.count
        cachedLastSession = dataManager.sessions.max(by: { $0.startDate < $1.startDate })
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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

                    // 2. Start workout on iPhone — two CTAs (Free Run + Gym
                    // Recovery). Interval templates have their own start path
                    // from the Programs tab. These cards are gated on no-watch-
                    // workout-active so iPhone and Watch can't run in parallel.
                    if !sharedData.isWorkoutActiveOnWatch {
                        VStack(spacing: 10) {
                            startCard(
                                title: "Free Run",
                                subtitle: "Open-ended workout · HR · GPS",
                                systemImage: "figure.run.circle.fill",
                                color: ShuttlXColor.running
                            ) {
                                workoutController.presentFreeRun()
                            }
                            startCard(
                                title: "Gym Recovery",
                                subtitle: "HR recovery between sets · cardiac rehab",
                                systemImage: "heart.circle.fill",
                                color: ShuttlXColor.heartRate
                            ) {
                                workoutController.presentGymRecovery()
                            }
                        }
                        StartOnWatchCard()
                    }

                    // 3. Active plan progress
                    if let active = planManager.activePlan() {
                        NavigationLink(destination: PlanDetailView(plan: active.plan)) {
                            PlanProgressCard(
                                plan: active.plan,
                                progress: active.progress,
                                completion: planManager.completionPercentage(for: active.progress),
                                nextWorkout: planManager.nextWorkout(for: active.progress)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }

                    // 4. Last workout card
                    if let session = cachedLastSession {
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            LastWorkoutCard(session: session)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }

                    // 5. Week summary
                    WeekSummaryCard(sessions: dataManager.sessions)

                    // 6. Streak badge
                    if cachedStreak > 1 {
                        StreakBadge(streakDays: cachedStreak)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle(greetingTitle)
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

    private func startCard(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(ShuttlXFont.heroIcon)
                    .foregroundStyle(color)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ShuttlXFont.cardTitle)
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    Text(subtitle)
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(color)
            }
            .padding(14)
            .themedCard(accent: color)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Starts the workout on your iPhone")
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
        .environmentObject(PlanManager())
        .environmentObject(AuthenticationManager.shared)
}
