import WidgetKit
import SwiftUI

struct SmallWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallWidgetEntry {
        SmallWidgetEntry(date: Date(), streak: 3, timeSince: "2h ago", trainedToday: true)
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
        let trainedToday = WidgetDataProvider.todaySession() != nil
        let timeSince: String
        if let last = WidgetDataProvider.lastSession() {
            timeSince = formatTimeSince(last.startDate)
        } else {
            timeSince = "No workouts"
        }
        return SmallWidgetEntry(date: Date(), streak: streak, timeSince: timeSince, trainedToday: trainedToday)
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
    let trainedToday: Bool
}

struct SmallWidget: Widget {
    let kind = "SmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmallWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    // Warm gradient when streak is active, subtle blue-grey otherwise
                    if entry.streak > 0 {
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.25, blue: 0.05),
                                     Color(red: 0.60, green: 0.14, blue: 0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.26, blue: 0.32),
                                     Color(red: 0.14, green: 0.17, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .widgetURL(URL(string: "shuttlx://dashboard"))
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
            // Header row: flame icon + today indicator
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.title3)
                Spacer()
                if entry.trainedToday {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.9))
                            .font(.caption2)
                        Text("Today")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Metric content — bottom-aligned in both branches
            if entry.streak > 0 {
                Text("\(entry.streak)")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("day streak")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            } else {
                Text(entry.timeSince)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Last workout")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.streak > 0
            ? "\(entry.streak) day training streak\(entry.trainedToday ? ", trained today" : "")"
            : "Last workout \(entry.timeSince)")
    }
}
