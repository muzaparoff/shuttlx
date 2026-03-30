import SwiftUI

struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Sport icon + name + date
            HStack {
                Image(systemName: session.sportType?.systemImage ?? "figure.run")
                    .font(.title3)
                    .foregroundStyle(session.sportType?.themeColor ?? ShuttlXColor.running)
                    .frame(width: 28)

                Text(session.displayName)
                    .font(ShuttlXFont.cardTitle)
                    .foregroundStyle(.primary)

                Spacer()

                Text(formatDate(session.startDate))
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
            }

            // Row 2: Activity badges
            if session.totalRunningDuration > 0 || session.totalWalkingDuration > 0 {
                HStack(spacing: 8) {
                    if session.totalRunningDuration > 0 {
                        ActivityBadge(activity: .running, duration: session.totalRunningDuration)
                    }
                    if session.totalWalkingDuration > 0 {
                        ActivityBadge(activity: .walking, duration: session.totalWalkingDuration)
                    }
                    Spacer()
                }
            }

            // Row 3: Compact metrics
            HStack(spacing: 12) {
                if let calories = session.caloriesBurned {
                    Label("\(Int(calories)) cal", systemImage: "flame.fill")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.calories)
                }

                if let heartRate = session.averageHeartRate {
                    Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.heartRate)
                }

                if let steps = session.totalSteps {
                    Label("\(steps)", systemImage: "shoeprints.fill")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.steps)
                }
            }
        }
        .padding(16)
        .themedCard(
            accent: session.sportType?.themeColor,
            statusLine: (mode: session.sportType?.rawValue.uppercased().prefix(4).description ?? "RUN", file: "session.json", position: "\(session.segments.count):1")
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionAccessibilityLabel)
    }

    private var sessionAccessibilityLabel: String {
        var parts: [String] = [
            session.displayName,
            formatDate(session.startDate),
            "duration \(formatDuration(session.duration))"
        ]
        if session.totalRunningDuration > 0 {
            parts.append("running \(formatDuration(session.totalRunningDuration))")
        }
        if session.totalWalkingDuration > 0 {
            parts.append("walking \(formatDuration(session.totalWalkingDuration))")
        }
        if let calories = session.caloriesBurned {
            parts.append("\(Int(calories)) calories")
        }
        if let heartRate = session.averageHeartRate {
            parts.append("average heart rate \(Int(heartRate)) BPM")
        }
        return parts.joined(separator: ", ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    SessionRowView(session: TrainingSession(
        startDate: Date(),
        endDate: Date(),
        duration: 1800,
        averageHeartRate: 142,
        maxHeartRate: 165,
        caloriesBurned: 245,
        distance: 2.1,
        totalSteps: 3500,
        segments: [
            ActivitySegment(activityType: .running, startDate: Date().addingTimeInterval(-1200), endDate: Date().addingTimeInterval(-600)),
            ActivitySegment(activityType: .walking, startDate: Date().addingTimeInterval(-600), endDate: Date())
        ]
    ))
    .padding()
}
