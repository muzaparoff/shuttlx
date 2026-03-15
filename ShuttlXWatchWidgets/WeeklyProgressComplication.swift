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
        // integer(forKey:) returns 0 when key is missing — guard against 0 to prevent
        // Gauge(value:in:0...0) which crashes. Fall back to 5, then clamp to minimum 1.
        let rawGoal = defaults?.integer(forKey: "weeklyWorkoutGoal") ?? 0
        let goal = max(1, rawGoal == 0 ? 5 : rawGoal)
        return WeeklyProgressEntry(date: Date(), count: count, goal: goal)
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
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Weekly Progress")
        .description("Shows workouts completed this week.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct WeeklyProgressComplicationView: View {
    let entry: WeeklyProgressEntry
    @Environment(\.widgetFamily) var family

    private var remaining: Int { max(0, entry.goal - entry.count) }
    private var goalStatusText: String {
        remaining == 0 ? "Goal reached" : "\(remaining) more to go"
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Progress")
                    .font(.headline)
                    .widgetAccentable()
                HStack(spacing: 4) {
                    ProgressView(value: Double(min(entry.count, entry.goal)), total: Double(entry.goal))
                        .widgetAccentable()
                    Text("\(entry.count)/\(entry.goal)")
                        .font(.caption)
                        .monospacedDigit()
                }
                Text(goalStatusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.count) of \(entry.goal) workouts this week. \(goalStatusText).")
        default:
            Gauge(value: Double(min(entry.count, entry.goal)), in: 0...Double(entry.goal)) {
                Image(systemName: "figure.run")
            } currentValueLabel: {
                Text("\(entry.count)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
            .accessibilityLabel("\(entry.count) of \(entry.goal) workouts this week")
        }
    }
}
