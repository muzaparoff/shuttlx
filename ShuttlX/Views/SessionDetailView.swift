import SwiftUI

struct SessionDetailView: View {
    let session: TrainingSession

    var body: some View {
        List {
            // Summary section
            Section("Summary") {
                LabeledRow(label: "Date", value: formatDate(session.startDate))
                LabeledRow(label: "Duration", value: formatDuration(session.duration))

                if session.totalRunningDuration > 0 {
                    HStack {
                        Label("Running", systemImage: "figure.run")
                            .foregroundColor(.green)
                        Spacer()
                        Text(formatDuration(session.totalRunningDuration))
                            .foregroundColor(.secondary)
                    }
                }

                if session.totalWalkingDuration > 0 {
                    HStack {
                        Label("Walking", systemImage: "figure.walk")
                            .foregroundColor(.orange)
                        Spacer()
                        Text(formatDuration(session.totalWalkingDuration))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Metrics section
            Section("Metrics") {
                if let steps = session.totalSteps {
                    LabeledRow(label: "Steps", value: "\(steps)", icon: "shoeprints.fill", color: .blue)
                }

                if let distance = session.distance, distance > 0 {
                    LabeledRow(label: "Distance", value: String(format: "%.2f km", distance), icon: "location.fill", color: .green)
                }

                if let hr = session.averageHeartRate {
                    LabeledRow(label: "Avg Heart Rate", value: "\(Int(hr)) BPM", icon: "heart.fill", color: .red)
                }

                if let maxHR = session.maxHeartRate {
                    LabeledRow(label: "Max Heart Rate", value: "\(Int(maxHR)) BPM", icon: "heart.fill", color: .red)
                }

                if let cal = session.caloriesBurned {
                    LabeledRow(label: "Calories", value: "\(Int(cal)) cal", icon: "flame.fill", color: .orange)
                }
            }

            // Segments section
            if !session.segments.isEmpty {
                Section("Activity Segments") {
                    ForEach(session.segments) { segment in
                        HStack {
                            Image(systemName: segment.activityType.systemImage)
                                .foregroundColor(segment.activityType.color)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.activityType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(formatTimeRange(start: segment.startDate, end: segment.endDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatDuration(segment.duration))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(segment.activityType.displayName), \(formatDuration(segment.duration))")
                    }
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Formatting

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds / 3600)
        let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        } else if m > 0 {
            return String(format: "%dm %02ds", m, s)
        } else {
            return "\(s)s"
        }
    }

    private func formatTimeRange(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startStr = formatter.string(from: start)
        if let end = end {
            return "\(startStr) - \(formatter.string(from: end))"
        }
        return startStr
    }
}

// MARK: - Helper Views

private struct LabeledRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var color: Color = .primary

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
            }
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    NavigationView {
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
            ]
        ))
    }
}
