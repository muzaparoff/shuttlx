import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var planManager: PlanManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var sharedData = SharedDataManager.shared

    private var greetingTitle: String {
        if authManager.isSignedIn, let name = authManager.userName {
            let firstName = name.components(separatedBy: " ").first ?? name
            return "Hi, \(firstName)"
        }
        return "Training"
    }

    private var lastSession: TrainingSession? {
        dataManager.sessions.sorted(by: { $0.startDate > $1.startDate }).first
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let sorted = dataManager.sessions.sorted(by: { $0.startDate > $1.startDate })
        guard !sorted.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's a session today
        let todaySessions = sorted.filter { calendar.isDate($0.startDate, inSameDayAs: checkDate) }
        if todaySessions.isEmpty {
            // No session today — check from yesterday
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let daySessions = sorted.filter { calendar.isDate($0.startDate, inSameDayAs: checkDate) }
            if daySessions.isEmpty { break }
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
                        .buttonStyle(.plain)
                    }

                    // 4. Last workout card
                    if let session = lastSession {
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            LastWorkoutCard(session: session)
                        }
                        .buttonStyle(.plain)
                    }

                    // 5. Week summary
                    WeekSummaryCard(sessions: dataManager.sessions)

                    // 6. Streak badge
                    if currentStreak > 1 {
                        StreakBadge(streakDays: currentStreak)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle(greetingTitle)
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
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
        .environmentObject(PlanManager())
        .environmentObject(AuthenticationManager.shared)
}
