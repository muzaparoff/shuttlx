import SwiftUI
import ShuttlXShared

// MARK: - WeeklyCarouselCard
//
// Swipeable per-week recap cards. Mirrors Concept 5 of the Aug 2026 analytics
// timeline mockup deck: one full-bleed card per week (most recent first),
// each with 3 stat tiles and a small pace/distance "training focus" scatter,
// plus a custom dot strip below that also acts as a jump-picker. Self-
// contained — derives everything from the raw `[TrainingSession]` array.
//
// Uses `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` +
// `.scrollPosition(id:)` (iOS 17+) rather than `TabView(.page)` — this is
// what gives the dot strip below clean programmatic scroll-to-jump control,
// per the mockup's `dotstrip` (a separate jump-picker, not TabView's built-in
// dots).

struct WeeklyCarouselCard: View {
    let sessions: [TrainingSession]
    var weekCount: Int = 8
    var referenceDate: Date = Date()

    @Environment(ThemeManager.self) private var themeManager
    @State private var scrolledWeekID: Date?

    private var isMixtape: Bool { themeManager.current.id == "mixtape" }

    // MARK: - Data

    private struct ScatterPoint: Identifiable {
        let id = UUID()
        let paceSecPerKm: Double
        let distanceKm: Double
    }

    private struct WeekBucket: Identifiable {
        let id: Date // week start date
        let label: String
        let totalDistanceKm: Double
        let totalDuration: TimeInterval
        let sessionCount: Int
        let scatterPoints: [ScatterPoint]
    }

    /// Most-recent-first array of rolling 7-day windows, matching the
    /// AnalyticsEngine.weeklyTrend convention (windows end at `referenceDate`,
    /// not calendar Mon-Sun weeks).
    private var weeks: [WeekBucket] {
        let calendar = Calendar.current
        return (0..<weekCount).compactMap { weeksAgo -> WeekBucket? in
            guard let weekEnd = calendar.date(byAdding: .day, value: -(weeksAgo * 7), to: referenceDate),
                  let weekStart = calendar.date(byAdding: .day, value: -7, to: weekEnd) else {
                return nil
            }

            let weekSessions = sessions.filter { $0.startDate >= weekStart && $0.startDate < weekEnd }
            let totalDistance = weekSessions.compactMap(\.distance).reduce(0, +)
            let totalDuration = weekSessions.reduce(0.0) { $0 + $1.duration }

            let scatterPoints: [ScatterPoint] = weekSessions.compactMap { session in
                guard let distance = session.distance, distance > 0.1, session.duration > 0 else { return nil }
                return ScatterPoint(paceSecPerKm: session.duration / distance, distanceKm: distance)
            }

            return WeekBucket(
                id: weekStart,
                label: Self.weekLabel(weeksAgo: weeksAgo),
                totalDistanceKm: totalDistance,
                totalDuration: totalDuration,
                sessionCount: weekSessions.count,
                scatterPoints: scatterPoints
            )
        }
    }

    private static func weekLabel(weeksAgo: Int) -> String {
        switch weeksAgo {
        case 0: return "This Week"
        case 1: return "Last Week"
        default: return "\(weeksAgo) Weeks Ago"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Recap")
                .font(ShuttlXFont.sectionHeader)

            if weeks.isEmpty {
                emptyState
            } else {
                carousel
                dotStrip
            }
        }
        .padding(16)
        .themedCard(headerLabel: "WEEKLY RECAP")
        .onAppear {
            if scrolledWeekID == nil { scrolledWeekID = weeks.first?.id }
        }
    }

    private var emptyState: some View {
        Text("Complete a workout to see your weekly recap.")
            .font(ShuttlXFont.cardSubtitle)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(weeks) { week in
                    weekCard(week)
                        .id(week.id)
                        .containerRelativeFrame(.horizontal, alignment: .leading) { length, _ in length * 0.88 }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledWeekID)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func weekCard(_ week: WeekBucket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(week.label.uppercased())
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                statTile(value: FormattingUtils.formatDistance(week.totalDistanceKm), label: "DISTANCE")
                statTile(value: FormattingUtils.formatDuration(week.totalDuration), label: "DURATION")
                statTile(value: "\(week.sessionCount)", label: "SESSIONS")
            }

            scatterChart(week.scatterPoints)
                .frame(height: 90)

            Text("EASY ← pace → HARD   ·   short ↑ distance ↓ long")
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lcdPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(week.label): \(FormattingUtils.formatDistance(week.totalDistanceKm)), " +
            "\(FormattingUtils.formatDuration(week.totalDuration)), \(week.sessionCount) sessions"
        )
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ShuttlXFont.metricSmall)
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(ShuttlXFont.microLabel)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mini Scatter ("training focus")

    private func scatterChart(_ points: [ScatterPoint]) -> some View {
        Canvas { context, size in
            let axisColor = ShuttlXColor.surfaceBorder
            var xAxis = Path()
            xAxis.move(to: CGPoint(x: 6, y: size.height - 6))
            xAxis.addLine(to: CGPoint(x: size.width - 6, y: size.height - 6))
            context.stroke(xAxis, with: .color(axisColor), lineWidth: 1)

            var yAxis = Path()
            yAxis.move(to: CGPoint(x: 6, y: 4))
            yAxis.addLine(to: CGPoint(x: 6, y: size.height - 6))
            context.stroke(yAxis, with: .color(axisColor), lineWidth: 1)

            guard !points.isEmpty else { return }

            let paces = points.map(\.paceSecPerKm)
            let distances = points.map(\.distanceKm)
            let minPace = paces.min() ?? 0
            let maxPace = paces.max() ?? 1
            let minDist = distances.min() ?? 0
            let maxDist = distances.max() ?? 1
            let paceRange = max(maxPace - minPace, 1)
            let distRange = max(maxDist - minDist, 0.1)

            let plotMinX: CGFloat = 12
            let plotMaxX = size.width - 10
            let plotMinY: CGFloat = 8
            let plotMaxY = size.height - 10

            let dotColor = ShuttlXColor.running

            for point in points {
                // x: faster pace (lower seconds/km) -> further right (HARD)
                let xRatio = points.count == 1 ? 0.5 : (maxPace - point.paceSecPerKm) / paceRange
                // y: longer distance -> further down (canvas y grows downward, matches "long" at bottom)
                let yRatio = points.count == 1 ? 0.5 : (point.distanceKm - minDist) / distRange
                let x = plotMinX + xRatio * (plotMaxX - plotMinX)
                let y = plotMinY + yRatio * (plotMaxY - plotMinY)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                    with: .color(dotColor.opacity(0.85))
                )
            }
        }
        .accessibilityLabel(
            points.isEmpty
                ? "No sessions this week"
                : "Training focus scatter: \(points.count) session\(points.count == 1 ? "" : "s") plotted by pace and distance"
        )
    }

    // MARK: - Dot Strip

    private var dotStrip: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            ForEach(weeks) { week in
                let isActive = week.id == (scrolledWeekID ?? weeks.first?.id)
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrolledWeekID = week.id
                    }
                } label: {
                    Capsule()
                        .fill(isActive ? ShuttlXColor.running : ShuttlXColor.surfaceBorder)
                        .frame(width: isActive ? 16 : 6, height: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to \(week.label)")
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Clean") {
    ScrollView {
        WeeklyCarouselCard(sessions: .previewMock)
            .padding()
    }
    .environment(ThemeManager.shared)
}

#Preview("Mixtape") {
    ScrollView {
        WeeklyCarouselCard(sessions: .previewMock)
            .padding()
    }
    .environment(ThemeManager.shared)
    .onAppear { ThemeManager.shared.selectTheme("mixtape") }
}

private extension Array where Element == TrainingSession {
    /// ~8 weeks of synthetic sessions with varying pace/distance, for previews only.
    static var previewMock: [TrainingSession] {
        let calendar = Calendar.current
        var sessions: [TrainingSession] = []
        for week in 0..<8 {
            let sessionsThisWeek = 2 + (week % 4)
            for s in 0..<sessionsThisWeek {
                let dayOffset = week * 7 + s * 2
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                let distance = 3.0 + Double((week * 3 + s * 5) % 90) / 10.0
                let paceSecPerKm = 300.0 + Double((week * 7 + s * 11) % 180) // 5'00" - 8'00"/km
                sessions.append(
                    TrainingSession(
                        startDate: day,
                        duration: distance * paceSecPerKm,
                        distance: distance
                    )
                )
            }
        }
        return sessions
    }
}
