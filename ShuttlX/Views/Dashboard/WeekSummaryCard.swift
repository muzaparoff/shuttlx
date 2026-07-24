import SwiftUI
import ShuttlXShared

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

    private var maxDayDuration: TimeInterval {
        weekDays.map(\.totalDuration).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ShuttlXSpacing.md) {
            HStack {
                Text("This Week")
                    .font(ShuttlXFont.cardTitle)
                Spacer()
                if weekSessionCount > 0 {
                    Text("\(weekSessionCount) session\(weekSessionCount == 1 ? "" : "s")")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
            }

            // Total duration hero — most meaningful single number on the card
            if weekTotalDuration > 0 {
                Text(FormattingUtils.formatDuration(weekTotalDuration))
                    .font(ShuttlXFont.metricLarge)
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textPrimary)
            } else {
                Text("No activity yet")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }

            // Activity bar chart — height encodes duration per day
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(weekDays) { day in
                    VStack(spacing: 3) {
                        Spacer(minLength: 0)

                        let proportion = maxDayDuration > 0 ? day.totalDuration / maxDayDuration : 0
                        let barHeight = day.totalDuration > 0 ? max(5, 44 * proportion) : 3

                        RoundedRectangle(cornerRadius: 2)
                            .fill(barFill(for: day))
                            .frame(height: barHeight)
                            .overlay(
                                day.isToday
                                    ? RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(ShuttlXColor.ctaPrimary, lineWidth: 1)
                                    : nil
                            )

                        Text(day.shortName)
                            .font(ShuttlXFont.microLabel)
                            .foregroundStyle(day.isToday ? ShuttlXColor.textPrimary : ShuttlXColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 58)
        }
        .padding(ShuttlXSpacing.xl)
        .themedCard(
            accent: ShuttlXColor.ctaPrimary,
            statusLine: (mode: "WEEK", file: "stats.json", position: "\(weekSessionCount):1"),
            headerLabel: "THIS WEEK"
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week, \(weekSessionCount) sessions, total \(FormattingUtils.formatDuration(weekTotalDuration))")
    }

    private func barFill(for day: WeekDay) -> Color {
        if day.sessionCount == 0 { return ShuttlXColor.surface }
        return day.isToday ? ShuttlXColor.ctaPrimary : ShuttlXColor.ctaPrimary.opacity(0.45)
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
