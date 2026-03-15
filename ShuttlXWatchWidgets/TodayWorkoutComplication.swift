import WidgetKit
import SwiftUI

struct TodayWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayWorkoutEntry {
        TodayWorkoutEntry(
            date: Date(),
            hasSession: true,
            sportTypeName: "Free Run",
            sportTypeIcon: "figure.run",
            caloriesBurned: "245",
            heartRate: "142",
            totalSteps: "3500",
            weekCount: 3,
            weekGoal: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayWorkoutEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayWorkoutEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> TodayWorkoutEntry {
        let weekCount = WatchWidgetDataProvider.thisWeekSessionCount()
        let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared")
        let rawGoal = defaults?.integer(forKey: "weeklyWorkoutGoal") ?? 0
        let weekGoal = max(1, rawGoal == 0 ? 5 : rawGoal)

        guard let session = WatchWidgetDataProvider.todaySession() else {
            return TodayWorkoutEntry(
                date: Date(),
                hasSession: false,
                sportTypeName: "",
                sportTypeIcon: "figure.run",
                caloriesBurned: "--",
                heartRate: "--",
                totalSteps: "--",
                weekCount: weekCount,
                weekGoal: weekGoal
            )
        }

        let cal = session.caloriesBurned.map { "\(Int($0))" } ?? "--"
        let hr = session.averageHeartRate.map { "\(Int($0))" } ?? "--"
        let steps = session.totalSteps.map { "\($0)" } ?? "--"

        return TodayWorkoutEntry(
            date: Date(),
            hasSession: true,
            sportTypeName: session.displayName,
            sportTypeIcon: session.sportType?.systemImage ?? "figure.run",
            caloriesBurned: cal,
            heartRate: hr,
            totalSteps: steps,
            weekCount: weekCount,
            weekGoal: weekGoal
        )
    }
}

struct TodayWorkoutEntry: TimelineEntry {
    let date: Date
    let hasSession: Bool
    let sportTypeName: String
    let sportTypeIcon: String
    let caloriesBurned: String
    let heartRate: String
    let totalSteps: String
    let weekCount: Int
    let weekGoal: Int
}

struct TodayWorkoutComplication: Widget {
    let kind = "TodayWorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWorkoutProvider()) { entry in
            TodayWorkoutComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "shuttlx://start-workout"))
        }
        .configurationDisplayName("Today's Workout")
        .description("Today's workout summary or quick start.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct TodayWorkoutComplicationView: View {
    let entry: TodayWorkoutEntry

    private var weekRemaining: Int { max(0, entry.weekGoal - entry.weekCount) }
    private var weekGoalText: String {
        weekRemaining == 0
            ? "Weekly goal done"
            : "\(weekRemaining) of \(entry.weekGoal) left"
    }

    var body: some View {
        if entry.hasSession {
            // Trained today — show summary
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.sportTypeIcon)
                        .widgetAccentable()
                    Text(entry.sportTypeName)
                        .font(.headline)
                        .lineLimit(1)
                        .widgetAccentable()
                }
                HStack(spacing: 6) {
                    Label(entry.caloriesBurned, systemImage: "flame.fill")
                    Label(entry.heartRate, systemImage: "heart.fill")
                    Label(entry.totalSteps, systemImage: "shoeprints.fill")
                }
                .font(.caption2)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today's workout: \(entry.sportTypeName), \(entry.caloriesBurned) calories, \(entry.heartRate) bpm, \(entry.totalSteps) steps")
        } else {
            // No workout today — show weekly goal progress
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("No workout yet")
                        .font(.headline)
                    Text(weekGoalText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No workout today. \(weekGoalText) this week.")
        }
    }
}
