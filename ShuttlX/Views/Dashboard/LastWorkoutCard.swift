import SwiftUI
import ShuttlXShared

struct LastWorkoutCard: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: ShuttlXSpacing.md) {
            // Header
            HStack {
                Text("Last Workout")
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                Text(FormattingUtils.formatShortDate(session.startDate))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }

            // Hero duration — the primary takeaway from the card
            Text(FormattingUtils.formatTimer(session.duration))
                .font(ShuttlXFont.timerDisplay)
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.textPrimary)

            // Activity type pills
            HStack(spacing: ShuttlXSpacing.sm) {
                if session.totalRunningDuration > 0 {
                    ActivityBadge(activity: .running, duration: session.totalRunningDuration)
                }
                if session.totalWalkingDuration > 0 {
                    ActivityBadge(activity: .walking, duration: session.totalWalkingDuration)
                }
                Spacer()
            }

            // Borderless metric strip — colour carries identity, no boxes needed
            let hasMetrics = (session.distance ?? 0) > 0 || session.averageHeartRate != nil || session.caloriesBurned != nil
            if hasMetrics {
                Rectangle()
                    .fill(ShuttlXColor.surfaceBorder.opacity(0.4))
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    if let distance = session.distance, distance > 0 {
                        metricColumn(value: FormattingUtils.formatDistance(distance), label: "km", color: ShuttlXColor.running)
                    }
                    if let hr = session.averageHeartRate {
                        if (session.distance ?? 0) > 0 { metricDivider() }
                        metricColumn(value: "\(Int(hr))", label: "avg hr", color: ShuttlXColor.heartRate)
                    }
                    if let cal = session.caloriesBurned {
                        if session.averageHeartRate != nil || (session.distance ?? 0) > 0 { metricDivider() }
                        metricColumn(value: "\(Int(cal))", label: "kcal", color: ShuttlXColor.calories)
                    }
                }
            }
        }
        .padding(ShuttlXSpacing.xl)
        .themedCard(
            accent: ShuttlXColor.running,
            statusLine: (mode: "HIST", file: "last_session.json", position: "1:1"),
            headerLabel: "LAST WORKOUT"
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last workout, \(FormattingUtils.formatShortDate(session.startDate)), \(FormattingUtils.formatDuration(session.duration))")
    }

    private func metricColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ShuttlXFont.metricMedium)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func metricDivider() -> some View {
        Rectangle()
            .fill(ShuttlXColor.surfaceBorder.opacity(0.4))
            .frame(width: 0.5, height: 30)
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
