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
        return WeeklyProgressEntry(date: Date(), count: count, goal: 5)
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
        .supportedFamilies([.accessoryCircular])
    }
}

struct WeeklyProgressComplicationView: View {
    let entry: WeeklyProgressEntry

    var body: some View {
        Gauge(value: Double(min(entry.count, entry.goal)), in: 0...Double(entry.goal)) {
            Image(systemName: "figure.run")
        } currentValueLabel: {
            Text("\(entry.count)")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}
