import SwiftUI
import Charts
import ShuttlXShared

enum TrendsPeriod: String, CaseIterable {
    case week = "Week", month = "Month", year = "Year"
}

/// First screen of Trends (approved mockup, 2026-10): Week / Month / Year, one hero
/// distance, a stacked bar chart in activity colours and "Time by activity".
/// Activities are the EFFECTIVE types (SegmentOverrideStore corrections applied).
struct TrendsOverview: View {
    let sessions: [TrainingSession]
    @State private var period: TrendsPeriod = .month

    private struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let name: String
        let km: Double
    }

    private static let none = "None"
    private let shown: [DetectedActivity] = [.running, .walking, .cycling]

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday, as in the mockup
        return c
    }

    private var interval: DateInterval {
        let comp: Calendar.Component = period == .week ? .weekOfYear : period == .month ? .month : .year
        return cal.dateInterval(of: comp, for: Date()) ?? DateInterval(start: Date(), duration: 86400)
    }

    private var bucketUnit: Calendar.Component { period == .year ? .month : .day }

    private var inPeriod: [TrainingSession] {
        let i = interval
        return sessions.filter { $0.startDate >= i.start && $0.startDate < i.end }
    }

    /// Session distance split by activity: proportional to the parts' own distances,
    /// else everything goes to the longest part. Parts of type Rest never get distance.
    private func kmByActivity(_ s: TrainingSession) -> [DetectedActivity: Double] {
        guard let d = s.distance, d > 0 else { return [:] }
        let segs = s.displaySegments().filter { shown.contains($0.activityType) }
        var own: [DetectedActivity: Double] = [:]
        for g in segs { own[g.activityType, default: 0] += max(0, g.distance ?? 0) }
        let sum = own.values.reduce(0, +)
        if sum > 0 { return own.mapValues { d * $0 / sum } }
        var dur: [DetectedActivity: TimeInterval] = [:]
        for g in segs { dur[g.activityType, default: 0] += g.duration }
        guard let top = dur.max(by: { $0.value < $1.value })?.key else { return [:] }
        return [top: d]
    }

    private var entries: [Entry] {
        let i = interval
        var out: [Entry] = []
        var start = i.start
        while start < i.end, let next = cal.date(byAdding: bucketUnit, value: 1, to: start) {
            var km: [DetectedActivity: Double] = [:]
            for s in inPeriod where s.startDate >= start && s.startDate < next {
                for (a, v) in kmByActivity(s) { km[a, default: 0] += v }
            }
            let any = km.values.reduce(0, +) > 0
            if any {
                for a in shown { if let v = km[a], v > 0 { out.append(Entry(date: start, name: TodayFormat.activityName(a), km: v)) } }
            } else {
                out.append(Entry(date: start, name: Self.none, km: 0.0001))
            }
            start = next
        }
        return out
    }

    private var totalKm: Double { inPeriod.compactMap(\.distance).reduce(0, +) }

    private var timeByActivity: [(activity: DetectedActivity, seconds: TimeInterval)] {
        var t: [DetectedActivity: TimeInterval] = [:]
        for s in inPeriod { for g in s.displaySegments() where shown.contains(g.activityType) { t[g.activityType, default: 0] += max(0, g.duration) } }
        return shown.compactMap { a in t[a].map { (a, $0) } }.filter { $0.1 > 0 }
    }

    private var subtitle: String {
        let i = interval
        switch period {
        case .week:
            let end = cal.date(byAdding: .day, value: -1, to: i.end) ?? i.end
            return "\(i.start.formatted(.dateTime.day().month(.abbreviated))) \u{2013} \(end.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            let days = cal.dateComponents([.day], from: i.start, to: i.end).day ?? 30
            return "\(i.start.formatted(.dateTime.month(.wide))) \u{00B7} \(Int((Double(days) / 7).rounded())) weeks"
        case .year:
            return "\(i.start.formatted(.dateTime.year())) \u{00B7} 52 weeks"
        }
    }

    private var periodWord: String { period == .week ? "this week" : period == .month ? "this month" : "this year" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Period", selection: $period) {
                ForEach(TrendsPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Trends period")

            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(totalKm >= 100 ? String(format: "%.0f", totalKm) : String(format: "%.1f", totalKm))
                        .font(ShuttlXFont.metricLarge.monospacedDigit())
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    Text("km")
                        .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(subtitle), \(String(format: "%.1f", totalKm)) kilometres")

            chart

            activityCard
        }
    }

    private var chart: some View {
        let i = interval
        return Chart(entries) { e in
            BarMark(x: .value("Date", e.date, unit: bucketUnit), y: .value("Kilometres", e.km))
                .foregroundStyle(by: .value("Activity", e.name))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            "Run": ShuttlXColor.running, "Walk": ShuttlXColor.walking,
            "Cycle": ShuttlXColor.cycling, Self.none: Color(.tertiarySystemFill),
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: i.start...i.end)
        .chartYAxis(.hidden)
        .chartXAxis {
            if period == .year {
                AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.narrow)) }
            } else if period == .week {
                AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) }
            } else {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day()) }
            }
        }
        .frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Distance by \(bucketUnit == .day ? "day" : "month"), \(periodWord): \(String(format: "%.1f", totalKm)) kilometres")
    }

    @ViewBuilder
    private var activityCard: some View {
        let rows = timeByActivity
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Time by activity")
                    .font(ShuttlXFont.cardTitle.weight(.bold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Spacer()
                Text(periodWord)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            if rows.isEmpty {
                Text("No workouts \(periodWord)")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(ShuttlXColor.textSecondary)
            } else {
                let maxT = rows.map(\.seconds).max() ?? 1
                ForEach(rows, id: \.activity) { r in
                    HStack(spacing: 8) {
                        Text(TodayFormat.activityName(r.activity))
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(ShuttlXColor.textPrimary)
                            .frame(width: 52, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule().fill(r.activity.themeColor)
                                    .frame(width: max(8, geo.size.width * r.seconds / maxT))
                            }
                        }
                        .frame(height: 8)
                        Text(Self.hm(r.seconds))
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(ShuttlXColor.textSecondary)
                            .frame(width: 64, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(r.activity.displayName), \(Self.hm(r.seconds))")
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .timelineCard()
    }

    private static func hm(_ s: TimeInterval) -> String {
        let m = Int((s / 60).rounded())
        return m >= 60 ? String(format: "%dh %02dm", m / 60, m % 60) : "\(m)m"
    }
}
