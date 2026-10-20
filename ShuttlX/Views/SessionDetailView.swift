import SwiftUI
import ShuttlXShared

struct SessionDetailView: View {
    let session: TrainingSession
    @ObservedObject private var overrides = SegmentOverrideStore.shared
    @State private var fixing: ActivitySegment?

    var body: some View {
        let segments = overrides.applying(to: session.segments)
        ScrollView {
            VStack(spacing: 20) {
                if let route = session.route, !route.isEmpty {
                    RouteMapView(route: route, segments: session.segments, kmSplits: session.kmSplits,
                                 showsHeader: false, height: 320)
                }

                titleBlock
                statTrio

                if !session.segments.isEmpty {
                    ActivityRibbon(segments: segments, height: 16)
                    VStack(spacing: 0) {
                        ForEach(segments) { seg in
                            Button { fixing = seg } label: { SessionPartRow(segment: seg) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens Fix a part")
                        }
                    }
                    .padding(.vertical, 6)
                    .timelineCard()
                }

                // Interval results (if interval workout)
                if let results = session.completedIntervalResults, !results.isEmpty {
                    IntervalResultsView(intervals: results)
                }

                // Metric cards grid
                metricGrid

            }
            .padding()
        }
        .sheet(item: $fixing) { seg in
            FixPartSheet(segment: seg) { overrides.set($0, for: seg) }
                .presentationDetents([.medium])
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .timelineScreenBackground()
    }

    // MARK: - Title Block

    private var timeRange: String {
        let day = session.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let end = session.endDate ?? session.startDate.addingTimeInterval(session.duration)
        return "\(day) \u{00B7} \(TodayFormat.clock(session.startDate))\u{2013}\(TodayFormat.clock(end))"
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.timelineName)
                .font(ShuttlXFont.metricMedium)
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text(timeRange)
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(ShuttlXColor.textSecondary)
            if session.importedFromHealth == true {
                Label("From Health", systemImage: "heart.text.square")
                    .font(ShuttlXFont.cardCaption.weight(.medium))
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Big numbers

    private var statTrio: some View {
        HStack(alignment: .top) {
            stat(session.distance.flatMap { $0 > 0 ? FormattingUtils.formatDistance($0) : nil } ?? "–", "Distance")
            stat(FormattingUtils.formatDuration(session.duration), "Time")
            stat(session.averageHeartRate.map { "\(Int($0))" } ?? "–", "Avg BPM")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ShuttlXFont.metricMedium.monospacedDigit())
                .foregroundStyle(ShuttlXColor.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Metric Grid

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let maxHR = session.maxHeartRate {
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(maxHR)) BPM",
                    label: "Max Heart Rate",
                    color: ShuttlXColor.heartRate
                )
            }

            if let cal = session.caloriesBurned {
                MetricCard(
                    icon: "flame.fill",
                    value: "\(Int(cal))",
                    label: "Calories",
                    color: ShuttlXColor.calories
                )
            }

            if let steps = session.totalSteps {
                MetricCard(
                    icon: "shoeprints.fill",
                    value: "\(steps)",
                    label: "Steps",
                    color: ShuttlXColor.steps
                )
            }

            if let cad = session.averageCadence, cad > 0 {
                MetricCard(
                    icon: "figure.run.motion",
                    value: "\(Int(cad.rounded())) spm",
                    label: "Avg Cadence",
                    color: ShuttlXColor.steps
                )
                // Show max only when it materially differs from average — keeps the grid clean.
                if let maxCad = session.maxCadence, maxCad > 0, abs(Double(maxCad) - cad) >= 2 {
                    MetricCard(
                        icon: "figure.run.motion",
                        value: "\(maxCad) spm",
                        label: "Max Cadence",
                        color: ShuttlXColor.steps
                    )
                }
            } else if let maxCad = session.maxCadence, maxCad > 0 {
                // Edge case: very short session with a max but no average.
                MetricCard(
                    icon: "figure.run.motion",
                    value: "\(maxCad) spm",
                    label: "Max Cadence",
                    color: ShuttlXColor.steps
                )
            }

            if let distance = session.distance, distance > 0 {
                MetricCard(
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    value: FormattingUtils.formatPace(session.duration / distance),
                    label: "Avg Pace",
                    color: ShuttlXColor.pace
                )
            }

            if let effort = session.effortRPE {
                MetricCard(
                    icon: "gauge.with.needle",
                    value: "Effort \(effort)/10",
                    label: "How hard",
                    color: ShuttlXColor.ctaPrimary
                )
            }
        }
    }

}

#Preview {
    NavigationStack {
        SessionDetailView(session: TrainingSession(
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            duration: 1800,
            averageHeartRate: 145,
            maxHeartRate: 172,
            caloriesBurned: 280,
            distance: 3.2,
            totalSteps: 4200,
            segments: [
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(-1500), averageHeartRate: 118, estimatedCalories: 38, activeEnergyCalories: 42),
                ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1500), endDate: Date().addingTimeInterval(-900), averageHeartRate: 158, estimatedCalories: 165, activeEnergyCalories: 172),
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-900), endDate: Date(), averageHeartRate: 121, estimatedCalories: 55, activeEnergyCalories: 68)
            ],
            route: [
                RoutePoint(latitude: 55.7558, longitude: 37.6173, timestamp: Date().addingTimeInterval(-1800)),
                RoutePoint(latitude: 55.7562, longitude: 37.6183, timestamp: Date().addingTimeInterval(-1600)),
                RoutePoint(latitude: 55.7570, longitude: 37.6200, timestamp: Date().addingTimeInterval(-1400)),
                RoutePoint(latitude: 55.7575, longitude: 37.6195, timestamp: Date().addingTimeInterval(-1100)),
                RoutePoint(latitude: 55.7580, longitude: 37.6185, timestamp: Date().addingTimeInterval(-800)),
                RoutePoint(latitude: 55.7585, longitude: 37.6170, timestamp: Date().addingTimeInterval(-500)),
            ],
            kmSplits: nil
        ))
    }
}


/// "Fix a part": pick Running / Walking / Cycling for one part. The correction is stored
/// beside the session (SegmentOverrideStore), never in sessions.json.
struct FixPartSheet: View {
    let segment: ActivitySegment   // already shows the effective type
    let onSave: (DetectedActivity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice: DetectedActivity

    init(segment: ActivitySegment, onSave: @escaping (DetectedActivity) -> Void) {
        self.segment = segment
        self.onSave = onSave
        _choice = State(initialValue: segment.activityType)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach([DetectedActivity.running, .walking, .cycling], id: \.self) { a in
                    Button {
                        choice = a
                    } label: {
                        HStack {
                            Image(systemName: a.systemImage).foregroundStyle(a.themeColor).frame(width: 28)
                            Text(a.displayName).font(ShuttlXFont.cardSubtitle).foregroundStyle(ShuttlXColor.textPrimary)
                            Spacer()
                            if choice == a { Image(systemName: "checkmark").foregroundStyle(ShuttlXColor.ctaPrimary) }
                        }
                    }
                    .accessibilityLabel(a.displayName + (choice == a ? ", selected" : ""))
                }
            }
            .scrollContentBackground(.hidden)
            .themedScreenBackground()
            .navigationTitle("Fix a part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(choice); dismiss() }
                }
            }
        }
    }
}
