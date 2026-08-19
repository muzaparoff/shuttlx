import SwiftUI
import ShuttlXShared

// MARK: - CalendarHeatmapCard
//
// 14-week (98-day) training-volume heatmap navigator. Mirrors Concept 2 of the
// Aug 2026 analytics timeline mockup deck: every day is a cell colored by a
// discrete 5-step sequential ramp (rest -> heavy), tap a cell to drill into
// that day's distance. Self-contained — derives everything from the raw
// `[TrainingSession]` array so it can be wired into any screen without new
// AnalyticsEngine methods.
//
// Grid layout matches the mockup exactly: 14 columns, filled row-major
// oldest -> newest (so each row spans 2 calendar weeks), not the classic
// GitHub 7-rows-by-week layout — this reads better at iPhone card width.
//
// Accessibility: the grid uses `.accessibilityElement(children: .contain)` so
// VoiceOver can navigate cell-by-cell instead of announcing one unreadable
// blob; each cell carries its own "<weekday>, <month> <day>: <distance>" (or
// "Rest day") label. The legend is decorative (buckets are already described
// per-cell) and is hidden from VoiceOver.

struct CalendarHeatmapCard: View {
    let sessions: [TrainingSession]
    var weeksToShow: Int = 14
    var referenceDate: Date = Date()

    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedIndex: Int?

    private var isMixtape: Bool { themeManager.current.id == "mixtape" }

    private static let columns = 14

    // MARK: - Data

    private struct HeatmapDay: Identifiable {
        var id: Date { date }
        let date: Date
        let distanceKm: Double
    }

    /// Oldest-first array of `weeksToShow * 7` days, one entry per calendar day.
    private var days: [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let totalDays = weeksToShow * 7

        // Group sessions by day once (O(sessions)) instead of filtering the
        // full session array per day (O(days * sessions)).
        var distanceByDay: [Date: Double] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            distanceByDay[day, default: 0] += session.distance ?? 0
        }

        return (0..<totalDays).reversed().compactMap { offset -> HeatmapDay? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return HeatmapDay(date: day, distanceKm: distanceByDay[day] ?? 0)
        }
    }

    private var selectedDay: HeatmapDay? {
        guard let selectedIndex, days.indices.contains(selectedIndex) else { return nil }
        return days[selectedIndex]
    }

    /// Pure sequential-ramp bucket function: distance (km) -> bucket 0...4.
    /// Matches the mockup's discrete 5-step ramp (not a continuous gradient).
    static func bucketIndex(forDistanceKm distance: Double) -> Int {
        if distance <= 0 { return 0 }
        if distance < 2 { return 1 }
        if distance < 5 { return 2 }
        if distance < 8 { return 3 }
        return 4
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Training Calendar")
                    .font(ShuttlXFont.sectionHeader)
                Text("Last \(weeksToShow) weeks")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
            }

            heatGrid

            legend

            detailLine
        }
        .padding(16)
        .themedCard(headerLabel: "CALENDAR")
    }

    // MARK: - Grid

    private var heatGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: Self.columns),
            spacing: 3
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                cell(for: day, index: index)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func cell(for day: HeatmapDay, index: Int) -> some View {
        let bucket = Self.bucketIndex(forDistanceKm: day.distanceKm)
        let color = HeatmapRamp.swatches(isMixtape: isMixtape)[bucket]
        let isSelected = selectedIndex == index

        return Button {
            selectedIndex = index
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(ShuttlXColor.textPrimary, lineWidth: isSelected ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func accessibilityLabel(for day: HeatmapDay) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateStr = formatter.string(from: day.date)
        if day.distanceKm <= 0 {
            return "\(dateStr): Rest day"
        }
        return "\(dateStr): \(String(format: "%.1f", day.distanceKm)) kilometers"
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(.secondary)
            ForEach(0..<HeatmapRamp.stepCount, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(HeatmapRamp.swatches(isMixtape: isMixtape)[step])
                    .frame(width: 12, height: 12)
            }
            Text("More")
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true) // decorative — buckets are already described per-cell above
    }

    // MARK: - Detail Line

    private var detailLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedDay.map(fullDateLabel) ?? "Tap a day")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
            Text(detailValueText)
                .font(ShuttlXFont.metricMedium)
                .foregroundStyle(ShuttlXColor.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var detailValueText: String {
        guard let selectedDay else { return "—" }
        return selectedDay.distanceKm <= 0 ? "Rest day" : FormattingUtils.formatDistance(selectedDay.distanceKm)
    }

    private func fullDateLabel(_ day: HeatmapDay) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day.date)
    }
}

// MARK: - Sequential Heatmap Ramp
//
// One hue, light -> dark, monotonic lightness — sequential encoding (volume),
// not categorical (never confuse this with the run/walk identity colors).
// TODO: promote to a shared ThemeColors/ThemeChartStyle token if a second
// sequential heatmap surface is added elsewhere in the app.

private enum HeatmapRamp {
    static let stepCount = 5

    static func swatches(isMixtape: Bool) -> [Color] {
        isMixtape ? mixtapeRamp : cleanRamp
    }

    // Clean — blue ramp, light (rest) -> dark (heavy).
    private static let cleanRamp: [Color] = [
        Color(red: 0.933, green: 0.957, blue: 0.988), // #EEF4FC
        Color(red: 0.804, green: 0.886, blue: 0.984), // #CDE2FB
        Color(red: 0.525, green: 0.714, blue: 0.937), // #86B6EF
        Color(red: 0.224, green: 0.529, blue: 0.898), // #3987E5
        Color(red: 0.094, green: 0.310, blue: 0.584)  // #184F95
    ]

    // Mixtape — amber ramp, dark (rest, recedes into the LCD body) -> bright
    // (heavy), echoing the tape-hole motif already used for the watch reel badge.
    private static let mixtapeRamp: [Color] = [
        Color(red: 0.173, green: 0.125, blue: 0.075), // #2C2013
        Color(red: 0.353, green: 0.235, blue: 0.094), // #5A3C18
        Color(red: 0.541, green: 0.361, blue: 0.122), // #8A5C1F
        Color(red: 0.753, green: 0.498, blue: 0.133), // #C07F22
        Color(red: 0.949, green: 0.663, blue: 0.231)  // #F2A93B
    ]
}

// MARK: - Preview

#Preview("Clean") {
    ScrollView {
        CalendarHeatmapCard(sessions: .previewMock)
            .padding()
    }
    .environment(ThemeManager.shared)
}

#Preview("Mixtape") {
    ScrollView {
        CalendarHeatmapCard(sessions: .previewMock)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("mixtape") }
}

private extension Array where Element == TrainingSession {
    /// 98 days of synthetic sessions with varying distances and rest days, for previews only.
    static var previewMock: [TrainingSession] {
        let calendar = Calendar.current
        var sessions: [TrainingSession] = []
        for offset in 0..<98 {
            // ~30% rest days, otherwise a pseudo-random distance 0.5-11km
            let roll = Double((offset * 37) % 100) / 100.0
            guard roll > 0.3 else { continue }
            let distance = 0.5 + Double((offset * 53) % 105) / 10.0
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let duration = distance * 360 // ~6 min/km
            sessions.append(
                TrainingSession(
                    startDate: day,
                    duration: duration,
                    distance: distance
                )
            )
        }
        return sessions
    }
}
