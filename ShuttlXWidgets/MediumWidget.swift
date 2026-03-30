import WidgetKit
import SwiftUI

// MARK: - WidgetTheme
// Provides background, surface, and accent colors per theme ID.
// Widget extensions cannot access ShuttlXColor/ThemeManager — all colors are defined locally.

struct WidgetTheme {
    let background: Color
    let backgroundDark: Color  // slightly darker, used as gradient end
    let surface: Color
    let accent: Color

    static func forID(_ id: String) -> WidgetTheme {
        switch id {
        case "synthwave":
            return WidgetTheme(
                background:     Color(red: 0.04, green: 0.04, blue: 0.10),
                backgroundDark: Color(red: 0.02, green: 0.02, blue: 0.07),
                surface:        Color(red: 0.08, green: 0.08, blue: 0.16),
                accent:         Color(red: 0.20, green: 0.90, blue: 0.50)   // neon green
            )
        case "mixtape":
            return WidgetTheme(
                background:     Color(red: 0.05, green: 0.08, blue: 0.13),
                backgroundDark: Color(red: 0.03, green: 0.05, blue: 0.09),
                surface:        Color(red: 0.10, green: 0.19, blue: 0.38),
                accent:         Color(red: 0.20, green: 0.65, blue: 0.95)   // blue
            )
        case "arcade":
            return WidgetTheme(
                background:     Color(red: 0.06, green: 0.06, blue: 0.18),
                backgroundDark: Color(red: 0.03, green: 0.03, blue: 0.12),
                surface:        Color(red: 0.10, green: 0.10, blue: 0.24),
                accent:         Color(red: 0.30, green: 0.95, blue: 0.35)   // phosphor green
            )
        case "classicradio":
            return WidgetTheme(
                background:     Color(red: 0.11, green: 0.08, blue: 0.03),
                backgroundDark: Color(red: 0.07, green: 0.05, blue: 0.02),
                surface:        Color(red: 0.23, green: 0.18, blue: 0.12),
                accent:         Color(red: 0.95, green: 0.80, blue: 0.50)   // amber/cream
            )
        case "vumeter":
            return WidgetTheme(
                background:     Color(red: 0.10, green: 0.09, blue: 0.06),
                backgroundDark: Color(red: 0.06, green: 0.05, blue: 0.03),
                surface:        Color(red: 0.07, green: 0.05, blue: 0.03),
                accent:         Color(red: 0.95, green: 0.65, blue: 0.20)   // amber
            )
        case "neovim":
            return WidgetTheme(
                background:     Color(red: 0.114, green: 0.125, blue: 0.129), // #1D2021
                backgroundDark: Color(red: 0.094, green: 0.102, blue: 0.106), // slightly darker
                surface:        Color(red: 0.157, green: 0.157, blue: 0.157), // #282828
                accent:         Color(red: 0.722, green: 0.733, blue: 0.149)  // #B8BB26 green
            )
        default: // "clean"
            return WidgetTheme(
                background:     Color(red: 0.08, green: 0.08, blue: 0.12),
                backgroundDark: Color(red: 0.04, green: 0.04, blue: 0.08),
                surface:        Color(red: 0.14, green: 0.14, blue: 0.20),
                accent:         Color(red: 0.25, green: 0.80, blue: 0.45)   // system green
            )
        }
    }

    static func fromDefaults() -> WidgetTheme {
        let id = UserDefaults(suiteName: "group.com.shuttlx.shared")?.string(forKey: "selectedThemeID") ?? "clean"
        return forID(id)
    }
}

// MARK: - Semantic metric colors (fixed, independent of theme)

private enum MetricColor {
    static let duration  = Color(red: 0.30, green: 0.65, blue: 0.85)  // blue
    static let distance  = Color(red: 0.30, green: 0.75, blue: 0.55)  // teal-green
    static let heartRate = Color(red: 0.88, green: 0.32, blue: 0.35)  // rose
    static let calories  = Color(red: 0.95, green: 0.55, blue: 0.10)  // amber-orange
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
            heartRate: "142",
            caloriesBurned: "245",
            duration: "28 min",
            distance: "3.20 km",
            weekCount: 3,
            themeID: currentThemeID(),
            sessionID: nil
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

    private func currentThemeID() -> String {
        UserDefaults(suiteName: "group.com.shuttlx.shared")?.string(forKey: "selectedThemeID") ?? "clean"
    }

    private func makeEntry() -> MediumWidgetEntry {
        let weekCount = WidgetDataProvider.thisWeekSessionCount()
        let themeID = currentThemeID()

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
                distance: "",
                weekCount: weekCount,
                themeID: themeID,
                sessionID: nil
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
            hr = "\(Int(avg))"
        } else {
            hr = "--"
        }

        let cal: String
        if let c = session.caloriesBurned, c > 0 {
            cal = "\(Int(c))"
        } else {
            cal = "--"
        }

        // Distance is stored in km
        let dist: String
        if let d = session.distance, d > 0 {
            dist = String(format: "%.2f km", d)
        } else {
            dist = ""
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
            distance: dist,
            weekCount: weekCount,
            themeID: themeID,
            sessionID: session.id.uuidString
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
    let distance: String
    let weekCount: Int
    let themeID: String
    let sessionID: String?
}

// MARK: - Widget

struct MediumWidget: Widget {
    let kind = "MediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            let urlString: String = {
                if let id = entry.sessionID {
                    return "shuttlx://session/\(id)"
                }
                return "shuttlx://dashboard"
            }()
            MediumWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    let theme = WidgetTheme.forID(entry.themeID)
                    LinearGradient(
                        colors: [theme.background, theme.backgroundDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: urlString))
        }
        .configurationDisplayName("Today's Workout")
        .description("Shows your latest workout at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct MediumWidgetView: View {
    let entry: MediumWidgetEntry

    private var theme: WidgetTheme { WidgetTheme.forID(entry.themeID) }

    var body: some View {
        if entry.hasSession {
            VStack(alignment: .leading, spacing: 8) {
                // Row 1: Sport icon + name + date
                HStack(spacing: 6) {
                    Image(systemName: entry.sportTypeIcon)
                        .font(.headline)
                        .foregroundStyle(theme.accent)
                        .frame(width: 22)

                    Text(entry.sportTypeName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(entry.workoutDate)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                // Row 2: Metric boxes — Duration + Distance (if Run/Walk) + HR + Cal
                HStack(spacing: 6) {
                    MetricBox(
                        icon: "timer",
                        color: MetricColor.duration,
                        value: entry.duration,
                        label: "Duration",
                        surface: theme.surface
                    )
                    if !entry.distance.isEmpty {
                        MetricBox(
                            icon: "location.fill",
                            color: MetricColor.distance,
                            value: entry.distance,
                            label: "Distance",
                            surface: theme.surface
                        )
                    }
                    MetricBox(
                        icon: "heart.fill",
                        color: MetricColor.heartRate,
                        value: entry.heartRate,
                        label: "Avg HR",
                        surface: theme.surface
                    )
                    MetricBox(
                        icon: "flame.fill",
                        color: MetricColor.calories,
                        value: entry.caloriesBurned,
                        label: "Cal",
                        surface: theme.surface
                    )
                }
                .frame(maxHeight: .infinity)

                // Row 3: Status + week count
                HStack(spacing: 4) {
                    Image(systemName: entry.isToday ? "checkmark.circle.fill" : "clock")
                        .font(.caption2)
                        .foregroundStyle(entry.isToday ? theme.accent : .white.opacity(0.45))

                    Text(entry.isToday ? "Today's Workout" : "Last Workout")
                        .font(.caption2)
                        .foregroundStyle(entry.isToday ? theme.accent : .white.opacity(0.45))
                        .lineLimit(1)

                    Spacer()

                    Text("\(entry.weekCount) this week")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.isToday ? "Today's" : "Last") workout: \(entry.sportTypeName), \(entry.duration), \(entry.distance.isEmpty ? "" : "\(entry.distance), ")\(entry.heartRate) bpm heart rate, \(entry.caloriesBurned) calories, \(entry.weekCount) workouts this week")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundStyle(theme.accent.opacity(0.60))
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

// MARK: - MetricBox

private struct MetricBox: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    let surface: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(surface)
        )
    }
}
