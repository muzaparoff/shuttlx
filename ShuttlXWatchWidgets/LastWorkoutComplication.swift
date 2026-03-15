import WidgetKit
import SwiftUI

struct LastWorkoutComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastWorkoutEntry {
        LastWorkoutEntry(date: Date(), isToday: true, timeSince: "2h ago", distance: "3.2 km", duration: "28:15")
    }

    func getSnapshot(in context: Context, completion: @escaping (LastWorkoutEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastWorkoutEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> LastWorkoutEntry {
        // Prefer today's session, fall back to last session
        let todaySession = WatchWidgetDataProvider.todaySession()
        let session: TrainingSession
        let isToday: Bool

        if let today = todaySession {
            session = today
            isToday = true
        } else if let last = WatchWidgetDataProvider.lastSession() {
            session = last
            isToday = false
        } else {
            return LastWorkoutEntry(date: Date(), isToday: false, timeSince: "No workouts", distance: "--", duration: "--:--")
        }

        let timeSince = isToday ? "Today" : formatTimeSince(session.startDate)
        let distance = formatDistance(session.distance)
        let duration = formatDuration(session.duration)

        return LastWorkoutEntry(date: Date(), isToday: isToday, timeSince: timeSince, distance: distance, duration: duration)
    }

    private func formatTimeSince(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval) / 3600
        let days = hours / 24
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        let minutes = Int(interval) / 60
        return "\(max(1, minutes))m ago"
    }

    private func formatDistance(_ distance: Double?) -> String {
        guard let d = distance, d > 0 else { return "--" }
        return String(format: "%.1f km", d)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LastWorkoutEntry: TimelineEntry {
    let date: Date
    let isToday: Bool
    let timeSince: String
    let distance: String
    let duration: String
}

struct LastWorkoutComplication: Widget {
    let kind = "LastWorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastWorkoutComplicationProvider()) { entry in
            LastWorkoutComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "shuttlx://last-workout"))
        }
        .configurationDisplayName("Last Workout")
        .description("Shows your most recent workout details.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LastWorkoutComplicationView: View {
    let entry: LastWorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if entry.isToday {
                    Image(systemName: "checkmark.circle.fill")
                        .widgetAccentable()
                }
                Text(entry.isToday ? "Today's Workout" : entry.timeSince)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            HStack(spacing: 8) {
                Label(entry.distance, systemImage: "figure.run")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Label(entry.duration, systemImage: "timer")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.weight(.medium))
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.isToday ? "Today's workout" : "Last workout \(entry.timeSince)"), \(entry.distance), \(entry.duration)")
    }
}
