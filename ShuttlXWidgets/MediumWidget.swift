import WidgetKit
import SwiftUI

struct MediumWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumWidgetEntry {
        MediumWidgetEntry(
            date: Date(),
            hasSession: true,
            isToday: true,
            workoutDate: "Today, 8:30 AM",
            heartRate: "142 bpm",
            distance: "3.2 km",
            duration: "28:15",
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
                heartRate: "--",
                distance: "--",
                duration: "--",
                weekCount: weekCount
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let hr: String
        if let avg = session.averageHeartRate, avg > 0 {
            hr = "\(Int(avg)) bpm"
        } else {
            hr = "--"
        }

        let dist: String
        if let d = session.distance, d > 0 {
            dist = String(format: "%.1f km", d / 1000)
        } else {
            dist = "--"
        }

        let minutes = Int(session.duration) / 60
        let seconds = Int(session.duration) % 60
        let dur = String(format: "%d:%02d", minutes, seconds)

        return MediumWidgetEntry(
            date: Date(),
            hasSession: true,
            isToday: isToday,
            workoutDate: dateFormatter.string(from: session.startDate),
            heartRate: hr,
            distance: dist,
            duration: dur,
            weekCount: weekCount
        )
    }
}

struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let hasSession: Bool
    let isToday: Bool
    let workoutDate: String
    let heartRate: String
    let distance: String
    let duration: String
    let weekCount: Int
}

struct MediumWidget: Widget {
    let kind = "MediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Workout")
        .description("Shows details from your most recent workout.")
        .supportedFamilies([.systemMedium])
    }
}

struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    var body: some View {
        if entry.hasSession {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        entry.isToday ? "Today's Workout" : "Last Workout",
                        systemImage: entry.isToday ? "checkmark.circle.fill" : "figure.run"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(entry.isToday ? .green : .secondary)

                    Text(entry.workoutDate)
                        .font(.subheadline.bold())

                    Spacer()

                    Text("\(entry.weekCount) this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(icon: "heart.fill", color: .red, value: entry.heartRate)
                    MetricRow(icon: "arrow.forward", color: .blue, value: entry.distance)
                    MetricRow(icon: "timer", color: .orange, value: entry.duration)
                }
            }
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
                .font(.subheadline)
        }
    }
}
