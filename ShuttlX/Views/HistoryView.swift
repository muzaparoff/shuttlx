import SwiftUI
import ShuttlXShared

enum HistoryMode: String, CaseIterable {
    case calendar = "Calendar"
    case list = "List"
    case map = "Map"
}

/// Segmented Calendar / List / Map switch (shared by all three modes; the map floats it over the map).
struct HistoryModePicker: View {
    @Binding var mode: HistoryMode
    var body: some View {
        Picker("History view", selection: $mode) {
            ForEach(HistoryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("History view mode")
    }
}

/// Day header text: "Tue 20 October · 2 sessions".
enum HistoryFormat {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEdMMMM")
        return f
    }()

    static func dayHeader(_ day: Date, count: Int) -> String {
        "\(dayFormatter.string(from: day).replacingOccurrences(of: ",", with: "")) \u{00B7} \(count) session\(count == 1 ? "" : "s")"
    }
}

/// History tab: calendar / list / map over one shared month.
struct HistoryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var mode: HistoryMode = .calendar
    @State private var month = Date()
    @State private var selectedDay = Date()
    @State private var shownDay = Calendar.current.startOfDay(for: Date())
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    #if DEBUG
    /// Screenshot seam (SHUTTLX_HISTORY_MODE=<calendar|list|map>).
    init() {
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_HISTORY_MODE"],
           let m = HistoryMode(rawValue: raw.capitalized) {
            _mode = State(initialValue: m)
        }
    }
    #endif

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, as in the mockup
        return c
    }

    private var monthSessions: [TrainingSession] {
        dataManager.effectiveSessions
            .filter { cal.isDate($0.startDate, equalTo: month, toGranularity: .month) }
            .sorted { $0.startDate > $1.startDate }
    }

    private var daySessions: [TrainingSession] {
        monthSessions.filter { cal.isDate($0.startDate, inSameDayAs: selectedDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            if mode == .map {
                HistoryMapView(sessions: monthSessions, mode: $mode, month: $month)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        HistoryModePicker(mode: $mode).padding(.horizontal, 16)
                        monthNavigator

                        switch mode {
                        case .calendar where !typeSize.isAccessibilitySize:   // 7-column grid cannot hold AX text: use the day list
                            calendarGrid
                            daySection(selectedDay, daySessions)
                        default:
                            listContent
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .navigationTitle("History")
                .timelineScreenBackground()
                .onChange(of: scenePhase) { _, phase in if phase == .active { rollOverDay() } }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in rollOverDay() }
            }
        }
    }

    // MARK: - Month navigator (shared by calendar and list)

    private var canGoForward: Bool {
        guard let next = cal.date(byAdding: .month, value: 1, to: month),
              let start = cal.dateInterval(of: .month, for: next)?.start else { return false }
        return start <= Date()
    }

    private var monthNavigator: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(ShuttlXFont.cardTitle)
                .foregroundStyle(ShuttlXColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(ShuttlXColor.accentText)
        .padding(.horizontal, 10)
    }

    /// After midnight, a selection that was "today" follows the new today (and its month).
    private func rollOverDay() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != shownDay else { return }
        if cal.isDate(selectedDay, inSameDayAs: shownDay) {
            selectedDay = Date()
            if cal.isDate(month, equalTo: shownDay, toGranularity: .month) { month = Date() }
        }
        shownDay = today
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
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(i + cal.firstWeekday - 1) % 7])
                        .font(ShuttlXFont.microLabel.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(cells.indices, id: \.self) { i in
                    if let day = cells[i] { dayCell(day) } else { Color.clear.frame(height: 48) }
                }
            }
        }
        .padding(.horizontal, 14)
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
        let future = day > Date() && !cal.isDateInToday(day)
        let isToday = cal.isDateInToday(day)
        return Button { selectedDay = day } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))")
                    .font(ShuttlXFont.cardSubtitle.monospacedDigit().weight(selected || isToday ? .bold : .regular))
                    .foregroundStyle(selected ? ShuttlXColor.iconOnCTA
                                     : future ? ShuttlXColor.textSecondary.opacity(0.45)
                                     : isToday ? ShuttlXColor.ctaPrimary : ShuttlXColor.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(selected ? ShuttlXColor.ctaPrimary : .clear))
                HStack(spacing: 2) {
                    ForEach(Array(dotActivities(sessions).enumerated()), id: \.offset) { _, a in
                        Circle().fill(a.themeColor).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide))
                            + (sessions.isEmpty ? "" : ", \(sessions.count) sessions: "
                               + dotActivities(sessions).map { TodayFormat.activityName($0) }.joined(separator: ", ")))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// One dot per distinct activity in the day's sessions (effective types, so
    /// "Fix a part" corrections show), in the order Run, Walk, Cycle.
    private func dotActivities(_ sessions: [TrainingSession]) -> [DetectedActivity] {
        let present = Set(sessions.flatMap { $0.displaySegments() }.map(\.activityType))
        return [DetectedActivity.running, .walking, .cycling].filter(present.contains)
    }

    // MARK: - Lists

    @ViewBuilder
    private var listContent: some View {
        if monthSessions.isEmpty {
            emptyText("No sessions this month")
        } else {
            let days = Dictionary(grouping: monthSessions) { cal.startOfDay(for: $0.startDate) }
                .sorted { $0.key > $1.key }
            LazyVStack(spacing: 14) {
                ForEach(days, id: \.key) { day, sessions in
                    daySection(day, sessions.sorted { $0.startDate < $1.startDate })
                }
            }
        }
    }

    @ViewBuilder
    private func daySection(_ day: Date, _ sessions: [TrainingSession]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HistoryFormat.dayHeader(day, count: sessions.count))
                .font(ShuttlXFont.cardCaption)
                .textCase(.uppercase)
                .foregroundStyle(ShuttlXColor.textSecondary)
                .padding(.horizontal, 32)
                .accessibilityAddTraits(.isHeader)
            if sessions.isEmpty {
                emptyText("No sessions on this day")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider().padding(.leading, 14) }
                        NavigationLink(destination: SessionDetailView(session: s)) {
                            HistoryDayRow(session: s)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .timelineCard()
                .padding(.horizontal, 16)
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(ShuttlXFont.cardCaption)
            .foregroundStyle(ShuttlXColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }
}

/// Compact day row: vertical mini-ribbon, name, "time · duration · Run + Walk", distance.
struct HistoryDayRow: View {
    let session: TrainingSession

    var body: some View {
        let segs = session.displaySegments()
        let total = max(1, segs.reduce(0) { $0 + max(0, $1.duration) })
        let sub = [TodayFormat.clock(session.startDate), TodayFormat.short(session.duration),
                   TodayFormat.activitySummary(segs)].joined(separator: " \u{00B7} ")
        let km = session.distance.flatMap { $0 > 0 ? String(format: "%.1f km", $0) : nil }
        HStack(spacing: 10) {
            GeometryReader { geo in
                VStack(spacing: 1) {
                    ForEach(segs) { s in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(s.activityType.themeColor)
                            .frame(height: max(3, (geo.size.height - CGFloat(segs.count - 1)) * max(0, s.duration) / total))
                    }
                }
            }
            .frame(width: 6, height: 32)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.timelineName)
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text(sub)
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            Spacer(minLength: 6)
            if let km {
                Text(km)
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textPrimary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.timelineName), \(sub)" + (km.map { ", \($0)" } ?? ""))
        .accessibilityHint("Opens session details")
    }
}
