import WidgetKit
import SwiftUI
import AppIntents

// MARK: - W1: Start Training (configurable)
//
// AppIntentConfiguration widget — the user picks a saved WorkoutTemplate when
// adding/editing the widget. Tapping deep-links into the host app via
// `shuttlx://start-template/{id}` (or `shuttlx://start-freerun` when
// unconfigured / the chosen template was deleted). The widget process can't
// reach WatchConnectivity, so PhoneSyncCoordinator.startWatchWorkout(...) is
// invoked by ShuttlXApp's onOpenURL, not here.

struct StartTrainingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StartTrainingEntry {
        StartTrainingEntry(
            date: Date(),
            templateID: nil,
            name: "Free Run",
            summary: "Tap to start",
            sportIcon: "figure.run",
            themeID: WidgetTheme.currentThemeID()
        )
    }

    func snapshot(for configuration: StartTrainingConfigurationIntent, in context: Context) async -> StartTrainingEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: StartTrainingConfigurationIntent, in context: Context) async -> Timeline<StartTrainingEntry> {
        // Static content — the design calls for `.never` since this widget
        // only changes when the user reconfigures it. Deleted-template
        // fallback is still re-evaluated on every configuration edit.
        Timeline(entries: [makeEntry(configuration: configuration)], policy: .never)
    }

    private func makeEntry(configuration: StartTrainingConfigurationIntent) -> StartTrainingEntry {
        let themeID = WidgetTheme.currentThemeID()

        guard let configuredTemplate = configuration.template else {
            return freeRunEntry(themeID: themeID)
        }

        // Re-resolve from disk rather than trusting the configuration
        // snapshot — covers rename (fresh name) and delete (fallback) since
        // the widget was configured.
        guard let freshTemplate = WidgetTemplateProvider.template(withID: configuredTemplate.id) else {
            return freeRunEntry(themeID: themeID)
        }

        return StartTrainingEntry(
            date: Date(),
            templateID: freshTemplate.id,
            name: freshTemplate.name,
            summary: freshTemplate.summaryText,
            sportIcon: freshTemplate.sportType?.systemImage ?? "figure.run",
            themeID: themeID
        )
    }

    private func freeRunEntry(themeID: String) -> StartTrainingEntry {
        StartTrainingEntry(
            date: Date(),
            templateID: nil,
            name: "Free Run",
            summary: "Tap to start",
            sportIcon: "figure.run",
            themeID: themeID
        )
    }
}

struct StartTrainingEntry: TimelineEntry {
    let date: Date
    let templateID: UUID?
    let name: String
    let summary: String
    let sportIcon: String
    let themeID: String
}

struct StartTrainingWidget: Widget {
    let kind = "StartTrainingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: StartTrainingConfigurationIntent.self, provider: StartTrainingProvider()) { entry in
            let urlString = entry.templateID.map { "shuttlx://start-template/\($0.uuidString)" } ?? "shuttlx://start-freerun"
            StartTrainingWidgetView(entry: entry)
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
        .configurationDisplayName("Start Training")
        .description("One-tap start for a workout you choose.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StartTrainingWidgetView: View {
    let entry: StartTrainingEntry
    @Environment(\.widgetFamily) private var family

    private var theme: WidgetTheme { WidgetTheme.forID(entry.themeID) }
    private var ringSize: CGFloat { family == .systemSmall ? 52 : 60 }

    var body: some View {
        Group {
            if entry.themeID == "mixtape" {
                mixtapeBody
            } else {
                cleanBody
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start \(entry.name). \(entry.summary). Tap to start on your Apple Watch.")
    }

    // Clean: frosted card, glass ring around a centered sport glyph — the
    // ring is static (no fill animation), per the design system's "no idle
    // animations" anti-goal.
    private var cleanBody: some View {
        VStack(spacing: 8) {
            ZStack {
                GlassRingProgress(progress: 1.0, accentColor: theme.accent, lineWidth: 5)
                    .frame(width: ringSize, height: ringSize)
                Image(systemName: entry.sportIcon)
                    .font(.title2)
                    .foregroundStyle(theme.accent)
            }
            .widgetAccentable()

            VStack(spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.summary)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(family == .systemSmall ? 8 : 16)
    }

    // Mixtape: cassette label strip + spool play affordance.
    private var mixtapeBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.name.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.surface)
                )

            HStack(spacing: 8) {
                CassetteSpoolProgress(completed: 1, total: 1, accentColor: theme.accent, surfaceColor: theme.surface)
                    .frame(width: 32, height: 32)
                    .widgetAccentable()
                Text("▸ PLAY")
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
            }

            Text(entry.summary)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(family == .systemSmall ? 8 : 16)
    }
}
