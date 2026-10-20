import SwiftUI
import ShuttlXShared

enum HistoryMode: String, CaseIterable {
    case calendar = "Calendar"
    case list = "List"
    case map = "Map"
}

/// History tab: calendar / list / map over one shared month.
struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var mode: HistoryMode = .calendar
    @State private var month = Date()
    @State private var selectedDay = Date()

    #if DEBUG
    /// Screenshot seam (SHUTTLX_HISTORY_MODE=<calendar|list|map>).
    init() {
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_HISTORY_MODE"],
           let m = HistoryMode(rawValue: raw.capitalized) {
            _mode = State(initialValue: m)
        }
    }
    #endif

    private let cal = Calendar.current

    private var monthSessions: [TrainingSession] {
        dataManager.sessions
            .filter { cal.isDate($0.startDate, equalTo: month, toGranularity: .month) }
            .sorted { $0.startDate > $1.startDate }
    }

    private var daySessions: [TrainingSession] {
        monthSessions.filter { cal.isDate($0.startDate, inSameDayAs: selectedDay) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("History view", selection: $mode) {
                        ForEach(HistoryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .accessibilityLabel("History view mode")

                    monthNavigator

                    switch mode {
                    case .calendar:
                        calendarGrid
                        sessionList(daySessions, empty: "No sessions on this day")
                    case .list:
                        sessionList(monthSessions, empty: "No sessions this month")
                    case .map:
                        HistoryMapView(sessions: monthSessions)
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("History")
            .themedScreenBackground()
        }
    }

    // MARK: - Month navigator (shared by all modes)

    private var monthNavigator: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(ShuttlXFont.cardTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal)
    }

    private func shiftMonth(_ delta: Int) {
        guard let m = cal.date(byAdding: .month, value: delta, to: month) else { return }
        month = m
        // Keep the selected day inside the visible month.
        selectedDay = cal.isDate(Date(), equalTo: m, toGranularity: .month)
            ? Date() : (cal.dateInterval(of: .month, for: m)?.start ?? m)
    }

    // MARK: - Calendar

    private var calendarGrid: some View {
        let cells = dayCells()
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(cal.veryShortWeekdaySymbols.indices, id: \.self) { i in
                    let s = cal.veryShortWeekdaySymbols[(i + cal.firstWeekday - 1) % 7]
                    Text(s).font(ShuttlXFont.microLabel).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(cells.indices, id: \.self) { i in
                    if let day = cells[i] { dayCell(day) } else { Color.clear.frame(height: 44) }
                }
            }
        }
        .padding(12)
        .themedCard()
        .padding(.horizontal)
    }

    private func dayCells() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: interval.start) - cal.firstWeekday + 7) % 7
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        return Array(repeating: nil, count: lead) + (0..<days).compactMap {
            cal.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let sessions = monthSessions.filter { cal.isDate($0.startDate, inSameDayAs: day) }
        let selected = cal.isDate(day, inSameDayAs: selectedDay)
        return Button { selectedDay = day } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(selected ? ShuttlXColor.ctaPrimary : Color.primary)
                HStack(spacing: 2) {
                    ForEach(Array(dotColors(sessions).enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? ShuttlXColor.ctaPrimary.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide))
                            + (sessions.isEmpty ? "" : ", \(sessions.count) sessions"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// One dot per distinct activity in the day's sessions (max 3). Sessions
    /// without running/walking segments (e.g. imported from Health) fall back
    /// to a single dot in the sport colour.
    private func dotColors(_ sessions: [TrainingSession]) -> [Color] {
        var colors: [Color] = []
        for activity in [DetectedActivity.running, .walking]
        where sessions.contains(where: { $0.segments.contains { $0.activityType == activity } }) {
            colors.append(activity.themeColor)
        }
        if colors.isEmpty, let s = sessions.first {
            colors.append(s.sportType?.themeColor ?? ShuttlXColor.running)
        }
        return colors
    }

    // MARK: - Session list

    @ViewBuilder
    private func sessionList(_ sessions: [TrainingSession], empty: String) -> some View {
        if sessions.isEmpty {
            Text(empty)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}
