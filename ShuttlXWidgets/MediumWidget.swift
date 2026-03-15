import WidgetKit
import SwiftUI

struct MediumWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(
            date: Date(),
            hasSession: true,
            isToday: true,
            workoutDate: "Today, 8:30 AM",
            sportTypeName: "Free Run",
            sportTypeIcon: "figure.run",
            heartRate: "142 bpm",
            caloriesBurned: "245 cal",
            totalSteps: "3500",
            weekCount: 3
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MediumWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> MediumWidgetEntry {
        let weekCount = WidgetDataProvider.thisWeekSessionCount()

        // Prefer today's session, fall back to last session
        let todaySession = WidgetDataProvider.todaySession()
        let session: TrainingSession
        let isToday: Bool

        if let today = todaySession {
            session = today
            isToday = true
        } else if let last = WidgetDataProvider.lastSession() {
            session = last
            isToday = false
        } else {
            return MediumWidgetEntry(
                date: Date(),
                hasSession: false,
                isToday: false,
                workoutDate: "--",
                sportTypeName: "",
                sportTypeIcon: "figure.run",
                heartRate: "--",
                caloriesBurned: "--",
                totalSteps: "--",
                weekCount: weekCount
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let sportName = session.displayName
        let sportIcon = session.sportType?.systemImage ?? "figure.run"

        let hr: String
        if let avg = session.averageHeartRate, avg > 0 {
            hr = "\(Int(avg)) bpm"
        } else {
            hr = "--"
        }

        let cal: String
        if let c = session.caloriesBurned, c > 0 {
            cal = "\(Int(c)) cal"
        } else {
            cal = "--"
        }

        let steps: String
        if let s = session.totalSteps, s > 0 {
            steps = "\(s)"
        } else {
            steps = "--"
        }

        return MediumWidgetEntry(
            date: Date(),
            hasSession: true,
            isToday: isToday,
            workoutDate: dateFormatter.string(from: session.startDate),
            sportTypeName: sportName,
            sportTypeIcon: sportIcon,
            heartRate: hr,
            caloriesBurned: cal,
            totalSteps: steps,
            weekCount: weekCount
        )
    }
}

struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let hasSession: Bool
    let isToday: Bool
    let workoutDate: String
    let sportTypeName: String
    let sportTypeIcon: String
    let heartRate: String
    let caloriesBurned: String
    let totalSteps: String
    let weekCount: Int
}

struct MediumWidget: Widget {
    let kind = "MediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Workout")
        .description("Shows your latest workout at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    var body: some View {
        if entry.hasSession {
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Sport icon + name + date
                HStack {
                    Image(systemName: entry.sportTypeIcon)
                        .font(.title3)
                        .foregroundStyle(entry.isToday ? .green : .orange)
                        .frame(width: 28)

                    Text(entry.sportTypeName)
                        .font(.headline)

                    Spacer()

                    Text(entry.workoutDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Row 2: Metrics (calories, bpm, steps) — matches history list
                HStack(spacing: 12) {
                    MetricRow(icon: "flame.fill", color: .orange, value: entry.caloriesBurned)
                    MetricRow(icon: "heart.fill", color: .red, value: entry.heartRate)
                    MetricRow(icon: "shoeprints.fill", color: .blue, value: entry.totalSteps)
                }

                Spacer()

                // Row 3: Week count
                HStack {
                    Label(
                        entry.isToday ? "Today's Workout" : "Last Workout",
                        systemImage: entry.isToday ? "checkmark.circle.fill" : "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(entry.isToday ? .green : .secondary)

                    Spacer()

                    Text("\(entry.weekCount) this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.isToday ? "Today's" : "Last") workout: \(entry.sportTypeName), \(entry.heartRate) heart rate, \(entry.caloriesBurned) calories, \(entry.weekCount) workouts this week")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No workouts yet")
                    .font(.headline)
                Text("Start one on your Apple Watch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No workouts yet. Start one on your Apple Watch.")
        }
    }
}

private struct MetricRow: View {
    let icon: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
    }
}
