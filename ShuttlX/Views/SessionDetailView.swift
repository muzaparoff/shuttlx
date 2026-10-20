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
                    ActivityRibbon(segments: segments)
                    VStack(spacing: 10) {
                        ForEach(segments) { seg in
                            Button { fixing = seg } label: { SessionPartRow(segment: seg) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens Fix a part")
                        }
                    }
                    .themedCard()

                    // Per-activity totals and calories (timeline bar + detail rows)
                    ActivitySegmentsView(segments: segments, totalDuration: session.duration)
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
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .themedScreenBackground()
    }

    // MARK: - Title Block

    private var timeRange: String {
        let start = FormattingUtils.formatSessionDate(session.startDate)
        return "\(start) – \((session.endDate ?? session.startDate.addingTimeInterval(session.duration)).formatted(date: .omitted, time: .shortened))"
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.displayName)
                .font(ShuttlXFont.cardTitle)
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
            if let distance = session.distance, distance > 0 {
                MetricCard(
                    icon: "location.fill",
                    value: FormattingUtils.formatDistance(distance),
                    label: "Distance",
                    color: ShuttlXColor.running
                )
            }

            if let hr = session.averageHeartRate {
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(hr)) BPM",
                    label: "Avg Heart Rate",
                    color: ShuttlXColor.heartRate
                )
            }

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

// MARK: - Unified Activity Segments View

struct ActivitySegmentsView: View {
    let segments: [ActivitySegment]
    let totalDuration: TimeInterval
    @State private var showAllSegments = false

    // MARK: - Per-phase calorie aggregation (Phase 4, 2026-08 run+walk plan)
    //
    // `activeEnergyCalories` (Apple's segment-summed activeEnergyBurned) is the
    // primary display value — see the rationale comment on `ActivitySegment`.
    // `estimatedCalories` (ShuttlX's phase-honest MET estimate) is surfaced as a
    // secondary caption only when present and materially different, so older
    // sessions or sessions with unknown body mass just show the one number they
    // have — never a fabricated "0 cal".
    private struct ActivityAggregate {
        let activity: DetectedActivity
        let duration: TimeInterval
        let activeEnergyCalories: Double?
        let estimatedCalories: Double?
    }

    /// Aggregated totals per activity type, sorted by duration descending
    private var aggregated: [ActivityAggregate] {
        let grouped = Dictionary(grouping: segments, by: \.activityType)
        return grouped.map { activity, segs in
            let duration = segs.reduce(0) { $0 + $1.duration }
            let activeValues = segs.compactMap(\.activeEnergyCalories)
            let estimatedValues = segs.compactMap(\.estimatedCalories)
            return ActivityAggregate(
                activity: activity,
                duration: duration,
                activeEnergyCalories: activeValues.isEmpty ? nil : activeValues.reduce(0, +),
                estimatedCalories: estimatedValues.isEmpty ? nil : estimatedValues.reduce(0, +)
            )
        }.sorted { $0.duration > $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(ShuttlXFont.sectionHeader)

            // Timeline bar
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        let fraction = totalDuration > 0 ? segment.duration / totalDuration : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(segment.activityType.themeColor)
                            .frame(width: max(4, geometry.size.width * fraction))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Aggregated summary rows — duration + per-phase calories
            VStack(alignment: .leading, spacing: 6) {
                ForEach(aggregated, id: \.activity) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.activity.themeColor)
                                .frame(width: 8, height: 8)
                            Text(item.activity.displayName)
                                .font(ShuttlXFont.cardCaption)
                            Text(FormattingUtils.formatDuration(item.duration))
                                .font(ShuttlXFont.cardCaption.monospacedDigit())
                                .foregroundStyle(ShuttlXColor.textSecondary)

                            if let cal = item.activeEnergyCalories {
                                Text("\u{2022}")
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.7))
                                Text("\(Int(cal.rounded())) cal")
                                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                                    .foregroundStyle(ShuttlXColor.calories)
                            }
                        }

                        // ShuttlX's own phase-honest MET estimate, shown only when it
                        // exists and materially differs from Apple's primary number —
                        // this is the differentiator: Apple costs the whole session
                        // under one activity type, ShuttlX costs each phase on its own.
                        if let estimate = item.estimatedCalories, shouldShowEstimate(estimate, primary: item.activeEnergyCalories) {
                            Text("ShuttlX phase estimate: \(Int(estimate.rounded())) cal")
                                .font(ShuttlXFont.microLabel)
                                .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.8))
                                .padding(.leading, 12)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: item))
                }
            }

            // Expandable per-segment details
            if segments.count > 3 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllSegments.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllSegments ? "Hide segments" : "Show all \(segments.count) segments")
                            .font(ShuttlXFont.cardCaption)
                        Image(systemName: showAllSegments ? "chevron.up" : "chevron.down")
                            .font(ShuttlXFont.cardCaption)
                    }
                    .foregroundStyle(.secondary)
                }
                .accessibilityHint(showAllSegments ? "Hides detailed segment breakdown" : "Shows all \(segments.count) activity segments")

                if showAllSegments {
                    segmentDetailRows
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var segmentDetailRows: some View {
        ForEach(segments) { segment in
            HStack(spacing: 8) {
                Circle()
                    .fill(segment.activityType.themeColor)
                    .frame(width: 8, height: 8)

                Image(systemName: segment.activityType.systemImage)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(segment.activityType.themeColor)
                    .frame(width: 20)

                Text(segment.activityType.displayName)
                    .font(ShuttlXFont.cardSubtitle)

                Spacer()

                Text(FormattingUtils.formatDuration(segment.duration))
                    .font(ShuttlXFont.cardSubtitle.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)

                // Primary calorie number only, when known — no fabricated "0 cal"
                // for older segments recorded before Phase 2's per-phase calories.
                if let cal = segment.activeEnergyCalories {
                    Text("\(Int(cal.rounded())) cal")
                        .font(ShuttlXFont.cardCaption.monospacedDigit())
                        .foregroundStyle(ShuttlXColor.calories)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(segment.activeEnergyCalories.map {
                "\(segment.activityType.displayName), \(FormattingUtils.formatDuration(segment.duration)), \(Int($0.rounded())) calories"
            } ?? "\(segment.activityType.displayName), \(FormattingUtils.formatDuration(segment.duration))")
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for item: ActivityAggregate) -> String {
        var label = "\(item.activity.displayName), \(FormattingUtils.formatDuration(item.duration))"
        if let cal = item.activeEnergyCalories {
            label += ", \(Int(cal.rounded())) calories"
        }
        if let estimate = item.estimatedCalories, shouldShowEstimate(estimate, primary: item.activeEnergyCalories) {
            label += ", ShuttlX phase estimate \(Int(estimate.rounded())) calories"
        }
        return label
    }

    /// Show ShuttlX's MET estimate only when it's the sole number available, or
    /// when it differs meaningfully (>=5 kcal) from Apple's primary estimate —
    /// keeps the common case (the two roughly agree) to a single glanceable number.
    private func shouldShowEstimate(_ estimate: Double, primary: Double?) -> Bool {
        guard let primary else { return true }
        return abs(estimate - primary) >= 5
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
private struct FixPartSheet: View {
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
