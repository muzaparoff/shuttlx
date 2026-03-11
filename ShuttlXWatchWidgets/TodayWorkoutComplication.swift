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
            totalSteps: "3500"
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
        guard let session = WatchWidgetDataProvider.todaySession() else {
            return TodayWorkoutEntry(
                date: Date(),
                hasSession: false,
                sportTypeName: "",
                sportTypeIcon: "figure.run",
                caloriesBurned: "--",
                heartRate: "--",
                totalSteps: "--"
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
            totalSteps: steps
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
}

struct TodayWorkoutComplication: Widget {
    let kind = "TodayWorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayWorkoutProvider()) { entry in
            TodayWorkoutComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "shuttlx://start-workout"))
        }
        .configurationDisplayName("Today's Workout")
        .description("Today's workout summary or quick start.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct TodayWorkoutComplicationView: View {
    let entry: TodayWorkoutEntry

    var body: some View {
        if entry.hasSession {
            // Trained today — show summary
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.sportTypeIcon)
                        .foregroundStyle(.green)
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
            }
        } else {
            // No workout today — quick start prompt
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("No workout yet")
                        .font(.headline)
                    Text("Tap to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
