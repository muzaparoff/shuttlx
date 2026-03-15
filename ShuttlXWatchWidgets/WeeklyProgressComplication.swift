import WidgetKit
import SwiftUI

struct WeeklyProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyProgressEntry {
        WeeklyProgressEntry(date: Date(), count: 3, goal: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyProgressEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyProgressEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> WeeklyProgressEntry {
        let count = WatchWidgetDataProvider.thisWeekSessionCount()
        let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared")
        let goal = defaults?.integer(forKey: "weeklyWorkoutGoal")
        return WeeklyProgressEntry(date: Date(), count: count, goal: goal ?? 5)
    }
}

struct WeeklyProgressEntry: TimelineEntry {
    let date: Date
    let count: Int
    let goal: Int
}

struct WeeklyProgressComplication: Widget {
    let kind = "WeeklyProgressComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyProgressProvider()) { entry in
            WeeklyProgressComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Progress")
        .description("Shows workouts completed this week.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct WeeklyProgressComplicationView: View {
    let entry: WeeklyProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Progress")
                    .font(.headline)
                    .widgetAccentable()
                HStack(spacing: 4) {
                    ProgressView(value: Double(min(entry.count, entry.goal)), total: Double(entry.goal))
                        .tint(.green)
                    Text("\(entry.count)/\(entry.goal)")
                        .font(.caption)
                        .monospacedDigit()
                }
                Text("\(entry.count) workout\(entry.count == 1 ? "" : "s") this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            Gauge(value: Double(min(entry.count, entry.goal)), in: 0...Double(entry.goal)) {
                Image(systemName: "figure.run")
            } currentValueLabel: {
                Text("\(entry.count)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
            .accessibilityLabel("\(entry.count) of \(entry.goal) workouts this week")
        }
    }
}
