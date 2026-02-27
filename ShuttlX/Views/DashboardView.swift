import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var sharedData = SharedDataManager.shared

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
                    }

                    // 2. Start on Watch card (when idle)
                    if !sharedData.isWorkoutActiveOnWatch {
                        StartOnWatchCard()
                    }

                    // 3. Last workout card
                    if let session = lastSession {
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            LastWorkoutCard(session: session)
                        }
                        .buttonStyle(.plain)
                    }

                    // 4. Week summary
                    WeekSummaryCard(sessions: dataManager.sessions)

                    // 5. Streak badge
                    if currentStreak > 1 {
                        StreakBadge(streakDays: currentStreak)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Training")
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sharedData.isWorkoutActiveOnWatch)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
}
