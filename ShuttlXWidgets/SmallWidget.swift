import WidgetKit
import SwiftUI

struct SmallWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallWidgetEntry {
        SmallWidgetEntry(date: Date(), streak: 3, timeSince: "2h ago")
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmallWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> SmallWidgetEntry {
        let streak = WidgetDataProvider.currentStreak()
        let timeSince: String
        if let last = WidgetDataProvider.lastSession() {
            timeSince = formatTimeSince(last.startDate)
        } else {
            timeSince = "No workouts"
        }
        return SmallWidgetEntry(date: Date(), streak: streak, timeSince: timeSince)
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
}

struct SmallWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let timeSince: String
}

struct SmallWidget: Widget {
    let kind = "SmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmallWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Training Streak")
        .description("Shows your training streak and time since last workout.")
        .supportedFamilies([.systemSmall])
    }
}

struct SmallWidgetView: View {
    let entry: SmallWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Spacer()
                Image(systemName: "figure.run")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.streak > 0 {
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(entry.streak == 1 ? "day streak" : "day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.timeSince)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Last workout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
