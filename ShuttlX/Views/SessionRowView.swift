import SwiftUI

struct SessionRowView: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.programName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(formatDate(session.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                // Duration
                Label(formatDuration(session.duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Calories if available
                if let calories = session.caloriesBurned {
                    Label("\(Int(calories)) cal", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Heart rate if available
                if let heartRate = session.averageHeartRate {
                    Label("\(Int(heartRate)) bpm", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionAccessibilityLabel)
    }

    private var sessionAccessibilityLabel: String {
        var parts: [String] = [
            session.programName,
            formatDate(session.startDate),
            "duration \(formatDuration(session.duration))"
        ]
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
        programID: UUID(),
        programName: "Beginner Walk-Run",
        startDate: Date(),
        endDate: Date(),
        duration: 1800,
        averageHeartRate: 142,
        maxHeartRate: 165,
        caloriesBurned: 245,
        distance: 2.1,
        completedIntervals: []
    ))
}
