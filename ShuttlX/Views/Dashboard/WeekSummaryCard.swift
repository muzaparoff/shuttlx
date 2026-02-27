import SwiftUI

struct WeekSummaryCard: View {
    let sessions: [TrainingSession]

    private var weekDays: [WeekDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? today
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? today
            let daySessions = sessions.filter { $0.startDate >= day && $0.startDate < dayEnd }
            let shortName = dayShortName(for: day)
            let isToday = calendar.isDateInToday(day)
            return WeekDay(date: day, shortName: shortName, isToday: isToday, sessionCount: daySessions.count, totalDuration: daySessions.reduce(0) { $0 + $1.duration })
        }
    }

    private var weekTotalDuration: TimeInterval {
        weekDays.reduce(0) { $0 + $1.totalDuration }
    }

    private var weekSessionCount: Int {
        weekDays.reduce(0) { $0 + $1.sessionCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                if weekSessionCount > 0 {
                    Text("\(weekSessionCount) session\(weekSessionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Day dots
            HStack(spacing: 0) {
                ForEach(weekDays) { day in
                    VStack(spacing: 6) {
                        Text(day.shortName)
                            .font(.caption2)
                            .foregroundStyle(day.isToday ? .primary : .secondary)

                        Circle()
                            .fill(day.sessionCount > 0 ? ShuttlXColor.running : Color(.tertiarySystemFill))
                            .frame(width: day.isToday ? 10 : 8, height: day.isToday ? 10 : 8)

                        if day.sessionCount > 0 {
                            Text(FormattingUtils.formatDuration(day.totalDuration))
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            Text(" ")
                                .font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if weekTotalDuration > 0 {
                HStack {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(FormattingUtils.formatDuration(weekTotalDuration))
                        .font(.caption.monospacedDigit().bold())
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week, \(weekSessionCount) sessions, total \(FormattingUtils.formatDuration(weekTotalDuration))")
    }

    private func dayShortName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(2))
    }
}

private struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    let shortName: String
    let isToday: Bool
    let sessionCount: Int
    let totalDuration: TimeInterval
}

#Preview {
    WeekSummaryCard(sessions: [
        TrainingSession(startDate: Date().addingTimeInterval(-3600), duration: 1800, segments: []),
        TrainingSession(startDate: Date().addingTimeInterval(-86400), duration: 2400, segments: [])
    ])
    .padding()
}
