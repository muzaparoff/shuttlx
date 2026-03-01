import WidgetKit
import SwiftUI

struct LastWorkoutComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastWorkoutEntry {
        LastWorkoutEntry(date: Date(), timeSince: "2h ago", distance: "3.2 km", duration: "28:15")
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
        guard let session = WatchWidgetDataProvider.lastSession() else {
            return LastWorkoutEntry(date: Date(), timeSince: "No workouts", distance: "--", duration: "--:--")
        }

        let timeSince = formatTimeSince(session.startDate)
        let distance = formatDistance(session.distance)
        let duration = formatDuration(session.duration)

        return LastWorkoutEntry(date: Date(), timeSince: timeSince, distance: distance, duration: duration)
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
        return String(format: "%.1f km", d / 1000)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LastWorkoutEntry: TimelineEntry {
    let date: Date
    let timeSince: String
    let distance: String
    let duration: String
}

struct LastWorkoutComplication: Widget {
    let kind = "LastWorkoutComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastWorkoutComplicationProvider()) { entry in
            LastWorkoutComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
            Text(entry.timeSince)
                .font(.headline)
                .widgetAccentable()
            HStack(spacing: 8) {
                Label(entry.distance, systemImage: "figure.run")
                Label(entry.duration, systemImage: "timer")
            }
            .font(.caption)
        }
    }
}
