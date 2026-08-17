import SwiftUI
import ShuttlXShared

struct SessionDetailView: View {
    let session: TrainingSession

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Duration header
                durationHeader

                // Activity badges
                if session.totalRunningDuration > 0 || session.totalWalkingDuration > 0 {
                    activityBadges
                }

                // Activity segments (timeline bar + detail rows)
                if !session.segments.isEmpty {
                    ActivitySegmentsView(segments: session.segments, totalDuration: session.duration)
                }

                // Route map
                if let route = session.route, !route.isEmpty {
                    RouteMapView(route: route, segments: session.segments, kmSplits: session.kmSplits)
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
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .themedScreenBackground()
    }

    // MARK: - Duration Header

    private var durationHeader: some View {
        VStack(spacing: 4) {
            if let name = session.programName {
                Text(name)
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.ctaPrimary)
            }

            if let sport = session.sportType {
                Label(sport.displayName, systemImage: sport.systemImage)
                    .font(ShuttlXFont.cardCaption.weight(.medium))
                    .foregroundStyle(sport.themeColor)
            }

            Text(FormattingUtils.formatDuration(session.duration))
                .font(ShuttlXFont.metricLarge)
                .contentTransition(.numericText())

            Text(FormattingUtils.formatSessionDate(session.startDate))
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Duration \(FormattingUtils.formatDuration(session.duration)), \(FormattingUtils.formatSessionDate(session.startDate))")
    }

    // MARK: - Activity Badges

    private var activityBadges: some View {
        HStack(spacing: 8) {
            if session.totalRunningDuration > 0 {
                ActivityBadge(activity: .running, duration: session.totalRunningDuration)
            }
            if session.totalWalkingDuration > 0 {
                ActivityBadge(activity: .walking, duration: session.totalWalkingDuration)
            }
        }
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
