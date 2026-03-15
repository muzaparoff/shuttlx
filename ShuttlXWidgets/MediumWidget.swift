import WidgetKit
import SwiftUI

// MARK: - Semantic widget colors (no access to ShuttlXColor in widget extension)

private enum WidgetColor {
    /// Warm amber — calories
    static let calories = Color(red: 0.95, green: 0.55, blue: 0.10)
    /// Muted rose — heart rate
    static let heartRate = Color(red: 0.85, green: 0.30, blue: 0.35)
    /// Muted teal — duration
    static let duration  = Color(red: 0.30, green: 0.65, blue: 0.75)
    /// Brand gradient start
    static let gradientTop    = Color(red: 0.10, green: 0.14, blue: 0.22)
    /// Brand gradient end
    static let gradientBottom = Color(red: 0.06, green: 0.10, blue: 0.18)
    /// Active sport accent
    static let activeAccent   = Color(red: 0.25, green: 0.80, blue: 0.45)
    /// Inactive sport accent
    static let inactiveAccent = Color(red: 0.85, green: 0.50, blue: 0.15)
}

// MARK: - Timeline provider

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
            duration: "28 min",
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
                duration: "--",
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

        let dur = formatDuration(session.duration)

        return MediumWidgetEntry(
            date: Date(),
            hasSession: true,
            isToday: isToday,
            workoutDate: dateFormatter.string(from: session.startDate),
            sportTypeName: sportName,
            sportTypeIcon: sportIcon,
            heartRate: hr,
            caloriesBurned: cal,
            duration: dur,
            weekCount: weekCount
        )
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "--" }
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(1, minutes)) min"
    }
}

// MARK: - Entry

struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let hasSession: Bool
    let isToday: Bool
    let workoutDate: String
    let sportTypeName: String
    let sportTypeIcon: String
    let heartRate: String
    let caloriesBurned: String
    let duration: String
    let weekCount: Int
}

// MARK: - Widget

struct MediumWidget: Widget {
    let kind = "MediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [WidgetColor.gradientTop, WidgetColor.gradientBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "shuttlx://dashboard"))
        }
        .configurationDisplayName("Today's Workout")
        .description("Shows your latest workout at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    var body: some View {
        if entry.hasSession {
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Sport icon + name + date
                HStack {
                    Image(systemName: entry.sportTypeIcon)
                        .font(.title3)
                        .foregroundStyle(entry.isToday ? WidgetColor.activeAccent : WidgetColor.inactiveAccent)
                        .frame(width: 28)

                    Text(entry.sportTypeName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(entry.workoutDate)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                // Row 2: Metrics (calories, bpm, duration) — equal width columns
                HStack(spacing: 8) {
                    MetricRow(icon: "flame.fill",    color: WidgetColor.calories,  value: entry.caloriesBurned)
                    MetricRow(icon: "heart.fill",    color: WidgetColor.heartRate, value: entry.heartRate)
                    MetricRow(icon: "timer",         color: WidgetColor.duration,  value: entry.duration)
                }

                Spacer()

                // Row 3: Status label + week count
                HStack {
                    Image(systemName: entry.isToday ? "checkmark.circle.fill" : "clock")
                        .font(.caption)
                        .foregroundStyle(entry.isToday ? WidgetColor.activeAccent : .white.opacity(0.5))
                    Text(entry.isToday ? "Today's Workout" : "Last Workout")
                        .font(.caption)
                        .foregroundStyle(entry.isToday ? WidgetColor.activeAccent : .white.opacity(0.5))
                        .lineLimit(1)

                    Spacer()

                    Text("\(entry.weekCount) this week")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.isToday ? "Today's" : "Last") workout: \(entry.sportTypeName), \(entry.heartRate) heart rate, \(entry.caloriesBurned) calories, \(entry.duration), \(entry.weekCount) workouts this week")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
                Text("No workouts yet")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Start one on your Apple Watch")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No workouts yet. Start one on your Apple Watch.")
        }
    }
}

// MARK: - MetricRow

private struct MetricRow: View {
    let icon: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
