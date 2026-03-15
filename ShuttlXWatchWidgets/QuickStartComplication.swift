import WidgetKit
import SwiftUI

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        completion(QuickStartEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let entry = QuickStartEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickStartEntry: TimelineEntry {
    let date: Date
}

struct QuickStartComplication: Widget {
    let kind = "QuickStartComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider()) { entry in
            QuickStartComplicationView()
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "shuttlx://start-workout"))
        }
        .configurationDisplayName("Quick Start")
        .description("Tap to start a workout.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct QuickStartComplicationView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Workout")
                        .font(.headline)
                    Text("Tap to begin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "figure.run")
                    .font(.title2)
                    .widgetAccentable()
            }
            .accessibilityLabel("Start workout")
        }
    }
}
