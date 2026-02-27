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

                // Activity timeline bar
                if !session.segments.isEmpty {
                    ActivityTimelineView(segments: session.segments, totalDuration: session.duration)
                }

                // Route map
                if let route = session.route, !route.isEmpty {
                    RouteMapView(route: route, segments: session.segments)
                }

                // Metric cards grid
                metricGrid

                // Segments list
                if !session.segments.isEmpty {
                    segmentsList
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Duration Header

    private var durationHeader: some View {
        VStack(spacing: 4) {
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
        }
    }

    // MARK: - Segments List

    private var segmentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity Segments")
                .font(ShuttlXFont.sectionHeader)
                .padding(.top, 4)

            ForEach(session.segments) { segment in
                HStack {
                    Image(systemName: segment.activityType.systemImage)
                        .foregroundStyle(segment.activityType.themeColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.activityType.displayName)
                            .font(.subheadline.weight(.medium))

                        Text(formatTimeRange(start: segment.startDate, end: segment.endDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(FormattingUtils.formatDuration(segment.duration))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(segment.activityType.displayName), \(FormattingUtils.formatDuration(segment.duration))")
            }
        }
    }

    private func formatTimeRange(start: Date, end: Date?) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        let startStr = f.string(from: start)
        if let end = end {
            return "\(startStr) - \(f.string(from: end))"
        }
        return startStr
    }
}

// MARK: - Activity Timeline View

struct ActivityTimelineView: View {
    let segments: [ActivitySegment]
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Activity Timeline")
                .font(.caption)
                .foregroundStyle(.secondary)

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

            // Legend
            HStack(spacing: 12) {
                let activities = Set(segments.map(\.activityType))
                ForEach(Array(activities), id: \.self) { activity in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(activity.themeColor)
                            .frame(width: 6, height: 6)
                        Text(activity.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity timeline showing workout segments")
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
            ]
        ))
    }
}
