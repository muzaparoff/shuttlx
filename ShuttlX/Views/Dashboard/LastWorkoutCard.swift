import SwiftUI

struct LastWorkoutCard: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: ShuttlXSpacing.lg) {
            // Header
            HStack {
                Text("Last Workout")
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                Text(FormattingUtils.formatShortDate(session.startDate))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }

            // Activity badges
            HStack(spacing: ShuttlXSpacing.md) {
                if session.totalRunningDuration > 0 {
                    ActivityBadge(activity: .running, duration: session.totalRunningDuration)
                }
                if session.totalWalkingDuration > 0 {
                    ActivityBadge(activity: .walking, duration: session.totalWalkingDuration)
                }
                Spacer()
                Text(FormattingUtils.formatDuration(session.duration))
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }

            // Metrics grid
            HStack(spacing: ShuttlXSpacing.md) {
                if let distance = session.distance, distance > 0 {
                    MetricCard(
                        icon: "location.fill",
                        value: FormattingUtils.formatDistance(distance),
                        label: "Distance",
                        color: ShuttlXColor.running,
                        compact: true
                    )
                }

                if let hr = session.averageHeartRate {
                    MetricCard(
                        icon: "heart.fill",
                        value: "\(Int(hr))",
                        label: "Avg HR",
                        color: ShuttlXColor.heartRate,
                        compact: true
                    )
                }

                if let cal = session.caloriesBurned {
                    MetricCard(
                        icon: "flame.fill",
                        value: "\(Int(cal))",
                        label: "Cal",
                        color: ShuttlXColor.calories,
                        compact: true
                    )
                }
            }
        }
        .padding(ShuttlXSpacing.xl)
        .themedCard(
            accent: ShuttlXColor.running,
            statusLine: (mode: "HIST", file: "last_session.json", position: "1:1")
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last workout, \(FormattingUtils.formatShortDate(session.startDate)), \(FormattingUtils.formatDuration(session.duration))")
    }
}

#Preview {
    LastWorkoutCard(session: TrainingSession(
        startDate: Date().addingTimeInterval(-86400),
        endDate: Date().addingTimeInterval(-84600),
        duration: 1800,
        averageHeartRate: 145,
        caloriesBurned: 280,
        distance: 3.2,
        segments: [
            ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(-900)),
            ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-900), endDate: Date())
        ]
    ))
    .padding()
}
