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
        .supportedFamilies([.accessoryCircular])
    }
}

struct QuickStartComplicationView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "figure.run")
                .font(.title2)
                .widgetAccentable()
        }
    }
}
