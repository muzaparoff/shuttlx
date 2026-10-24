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

    // accessoryCorner exists on watchOS only; the script that builds this file for iOS fails on it otherwise.
    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider()) { _ in
            QuickStartComplicationView()
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "shuttlx://start-workout"))
        }
        .configurationDisplayName("Quick Start")
        .description("Tap to start a workout.")
        .supportedFamilies(Self.families)
    }
}

struct QuickStartComplicationView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Start Workout")
                .accessibilityLabel("Start workout")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .widgetAccentable()
                Text("Start Workout")
                    .font(.headline)
            }
            .accessibilityLabel("Start workout")
        #if os(watchOS)
        case .accessoryCorner:
            // Corner slot: run glyph in the corner, curved "RUN/WALK" label
            // hugging the bezel via .widgetLabel. System-tinted per watch face.
            Image(systemName: "figure.run")
                .font(.title2)
                .widgetAccentable()
                .widgetLabel("RUN/WALK")
                .accessibilityLabel("Start Run/Walk")
        #endif
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
