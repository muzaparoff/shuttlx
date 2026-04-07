import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var sharedData = SharedDataManager.shared
    @State private var cachedStreak: Int = 0
    @State private var cachedLastSession: TrainingSession?
    @State private var lastSessionCount: Int = 0

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
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))

                        // Inline live route map
                        if sharedData.liveRoutePoints.count >= 2 {
                            LiveRouteView(routePoints: sharedData.liveRoutePoints, compact: true)
                                .transition(.opacity)
                        }
                    }

                    // 2. Start on Watch card (when idle)
                    if !sharedData.isWorkoutActiveOnWatch {
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sharedData.isWorkoutActiveOnWatch)
            .themedScreenBackground()
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
        .environmentObject(PlanManager())
        .environmentObject(AuthenticationManager.shared)
}
