import SwiftUI

struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(formatDate(session.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(formatDuration(session.duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Running duration
                if session.totalRunningDuration > 0 {
                    Label(formatDuration(session.totalRunningDuration), systemImage: "figure.run")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Walking duration
                if session.totalWalkingDuration > 0 {
                    Label(formatDuration(session.totalWalkingDuration), systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                if let calories = session.caloriesBurned {
                    Label("\(Int(calories)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if let heartRate = session.averageHeartRate {
                    Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if let steps = session.totalSteps {
                    Label("\(steps)", systemImage: "shoeprints.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
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
}
