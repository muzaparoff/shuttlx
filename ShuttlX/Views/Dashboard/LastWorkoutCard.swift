import SwiftUI

struct LastWorkoutCard: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Last Workout")
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                Text(FormattingUtils.formatShortDate(session.startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Activity badges
            HStack(spacing: 8) {
                if session.totalRunningDuration > 0 {
                    ActivityBadge(activity: .running, duration: session.totalRunningDuration)
                }
                if session.totalWalkingDuration > 0 {
                    ActivityBadge(activity: .walking, duration: session.totalWalkingDuration)
                }
                Spacer()
                Text(FormattingUtils.formatDuration(session.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Metrics grid
            HStack(spacing: 8) {
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
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
