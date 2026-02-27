import SwiftUI

struct WeekStripView: View {
    @Binding var selectedDate: Date
    let sessions: [TrainingSession]

    private var weekDays: [StripDay] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        let weekStart = weekInterval.start

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let count = sessions.filter { $0.startDate >= day && $0.startDate < dayEnd }.count
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(day)

            return StripDay(date: day, sessionCount: count, isSelected: isSelected, isToday: isToday)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(weekDays) { day in
                    Button {
                        selectedDate = day.date
                    } label: {
                        VStack(spacing: 6) {
                            Text(dayName(day.date))
                                .font(.caption2)
                                .foregroundStyle(day.isSelected ? .white : .secondary)

                            Text(dayNumber(day.date))
                                .font(.subheadline.weight(day.isToday ? .bold : .medium))
                                .foregroundStyle(day.isSelected ? .white : .primary)

                            // Session dots
                            HStack(spacing: 2) {
                                ForEach(0..<min(day.sessionCount, 3), id: \.self) { _ in
                                    Circle()
                                        .fill(day.isSelected ? .white : ShuttlXColor.running)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(width: 44, height: 72)
                        .background(
                            day.isSelected
                                ? AnyShapeStyle(ShuttlXColor.running)
                                : (day.isToday ? AnyShapeStyle(Color(.tertiarySystemFill)) : AnyShapeStyle(.clear)),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dayFullName(day.date)), \(day.sessionCount) sessions\(day.isToday ? ", today" : "")")
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(2))
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func dayFullName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: date)
    }
}

private struct StripDay: Identifiable {
    let id = UUID()
    let date: Date
    let sessionCount: Int
    let isSelected: Bool
    let isToday: Bool
}

#Preview {
    WeekStripView(selectedDate: .constant(Date()), sessions: [])
}
