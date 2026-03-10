import SwiftUI

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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.ctaPrimary)
            }

            if let sport = session.sportType {
                Label(sport.displayName, systemImage: sport.systemImage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(sport.themeColor)
            }

            Text(FormattingUtils.formatDuration(session.duration))
                .font(ShuttlXFont.metricLarge)
                .contentTransition(.numericText())

            Text(FormattingUtils.formatSessionDate(session.startDate))
                .font(.subheadline)
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

    /// Aggregated totals per activity type, sorted by duration descending
    private var aggregated: [(activity: DetectedActivity, duration: TimeInterval)] {
        var dict: [DetectedActivity: TimeInterval] = [:]
        for segment in segments {
            dict[segment.activityType, default: 0] += segment.duration
        }
        return dict.sorted { $0.value > $1.value }.map { (activity: $0.key, duration: $0.value) }
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

            // Aggregated summary row
            HStack(spacing: 12) {
                ForEach(aggregated, id: \.activity) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.activity.themeColor)
                            .frame(width: 8, height: 8)
                        Text(item.activity.displayName)
                            .font(ShuttlXFont.cardCaption)
                        Text(FormattingUtils.formatDuration(item.duration))
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.activity.displayName), \(FormattingUtils.formatDuration(item.duration))")
                }
            }

            // Expandable per-segment details
            if segments.count > 3 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllSegments.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllSegments ? "Hide segments" : "Show all \(segments.count) segments")
                            .font(.caption)
                        Image(systemName: showAllSegments ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

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
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(segment.activityType.displayName), \(FormattingUtils.formatDuration(segment.duration))")
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
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(-1500)),
                ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1500), endDate: Date().addingTimeInterval(-900)),
                ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-900), endDate: Date())
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
