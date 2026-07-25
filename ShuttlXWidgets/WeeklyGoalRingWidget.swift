import WidgetKit
import SwiftUI

// MARK: - W3: Weekly Goal Ring
//
// Home-screen small (themed: Clean glass ring / Mixtape cassette spool) +
// lock-screen accessoryCircular/accessoryRectangular (system-tinted only —
// no custom theme colors on the lock screen, matching the watch
// complications' `WeeklyProgressComplication` pattern).

struct WeeklyGoalRingProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyGoalRingEntry {
        WeeklyGoalRingEntry(date: Date(), count: 3, goal: 5, themeID: "clean")
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyGoalRingEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyGoalRingEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> WeeklyGoalRingEntry {
        let count = WidgetDataProvider.thisWeekSessionCount()
        let defaults = UserDefaults(suiteName: "group.com.shuttlx.shared")
        // integer(forKey:) returns 0 when the key is missing (nothing writes
        // it yet — known follow-up). Guard against Gauge(value:in: 0...0).
        let rawGoal = defaults?.integer(forKey: "weeklyWorkoutGoal") ?? 0
        let goal = max(1, rawGoal == 0 ? 5 : rawGoal)
        return WeeklyGoalRingEntry(date: Date(), count: count, goal: goal, themeID: WidgetTheme.currentThemeID())
    }
}

struct WeeklyGoalRingEntry: TimelineEntry {
    let date: Date
    let count: Int
    let goal: Int
    let themeID: String
}

struct WeeklyGoalRingWidget: Widget {
    let kind = "WeeklyGoalRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyGoalRingProvider()) { entry in
            WeeklyGoalRingView(entry: entry)
                .containerBackground(for: .widget) {
                    let theme = WidgetTheme.forID(entry.themeID)
                    LinearGradient(
                        colors: [theme.background, theme.backgroundDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "shuttlx://dashboard"))
        }
        .configurationDisplayName("Weekly Goal")
        .description("How many of your weekly workouts are done.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct WeeklyGoalRingView: View {
    let entry: WeeklyGoalRingEntry
    @Environment(\.widgetFamily) private var family

    private var theme: WidgetTheme { WidgetTheme.forID(entry.themeID) }
    private var remaining: Int { max(0, entry.goal - entry.count) }
    private var goalReached: Bool { entry.count >= entry.goal }
    private var progress: Double { entry.goal > 0 ? Double(entry.count) / Double(entry.goal) : 0 }
    private var statusText: String {
        if entry.count == 0 { return "Start your week" }
        return goalReached ? "Goal reached" : "\(remaining) to go"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularBody
        case .accessoryRectangular:
            accessoryRectangularBody
        default:
            themedSmallBody
        }
    }

    // MARK: Home-screen small — themed signature shape

    private var themedSmallBody: some View {
        Group {
            if entry.themeID == "mixtape" {
                mixtapeSpoolBody
            } else {
                cleanRingBody
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.count) of \(entry.goal) workouts this week. \(statusText).")
    }

    private var cleanRingBody: some View {
        VStack(spacing: 6) {
            ZStack {
                GlassRingProgress(progress: progress, accentColor: theme.accent, lineWidth: 8)
                    .frame(width: 76, height: 76)
                VStack(spacing: 0) {
                    Text("\(entry.count)")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                    Text("of \(entry.goal)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                if goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                        .offset(x: 26, y: -26)
                }
            }
            .widgetAccentable()
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    private var mixtapeSpoolBody: some View {
        VStack(spacing: 6) {
            ZStack {
                CassetteSpoolProgress(completed: entry.count, total: entry.goal, accentColor: theme.accent, surfaceColor: theme.surface)
                    .frame(width: 76, height: 76)
                VStack(spacing: 0) {
                    Text("\(entry.count)/\(entry.goal)")
                        .font(.system(.callout, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                }
            }
            .widgetAccentable()
            Text("THIS WEEK")
                .font(.caption2.bold())
                .foregroundStyle(theme.accent)
                .lineLimit(1)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    // MARK: Lock screen — system-tinted only, no custom theme colors

    private var accessoryCircularBody: some View {
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

    private var accessoryRectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Weekly Goal")
                .font(.headline)
                .widgetAccentable()
            HStack(spacing: 4) {
                ProgressView(value: Double(min(entry.count, entry.goal)), total: Double(entry.goal))
                    .widgetAccentable()
                Text("\(entry.count)/\(entry.goal)")
                    .font(.caption)
                    .monospacedDigit()
            }
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.count) of \(entry.goal) workouts this week. \(statusText).")
    }
}
