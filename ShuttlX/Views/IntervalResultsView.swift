import SwiftUI

struct IntervalResultsView: View {
    let intervals: [CompletedInterval]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interval Results")
                .font(.headline)
                .padding(.top, 4)

            // Timeline bar
            intervalTimeline

            // Per-interval rows
            ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                intervalRow(interval, index: index + 1)
            }

            // Summary
            intervalSummary
        }
    }

    // MARK: - Timeline Bar

    private var intervalTimeline: some View {
        let totalDuration = intervals.reduce(0) { $0 + $1.actualDuration }

        return GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(intervals) { interval in
                    let fraction = totalDuration > 0 ? interval.actualDuration / totalDuration : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(intervalColor(interval.intervalType))
                        .frame(width: max(4, geometry.size.width * fraction))
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Interval Row

    private func intervalRow(_ interval: CompletedInterval, index: Int) -> some View {
        HStack(spacing: 8) {
            // Type indicator
            Circle()
                .fill(intervalColor(interval.intervalType))
                .frame(width: 8, height: 8)

            // Label / type
            VStack(alignment: .leading, spacing: 1) {
                Text(interval.label ?? interval.intervalType.displayName)
                    .font(.subheadline.weight(.medium))
                Text("#\(index)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 60, alignment: .leading)

            Spacer()

            // Duration (target vs actual)
            VStack(alignment: .trailing, spacing: 1) {
                Text(FormattingUtils.formatDuration(interval.actualDuration))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if interval.actualDuration != interval.targetDuration {
                    let diff = interval.actualDuration - interval.targetDuration
                    Text(diff >= 0 ? "+\(Int(diff))s" : "\(Int(diff))s")
                        .font(.caption2)
                        .foregroundStyle(diff > 3 ? .orange : .secondary)
                }
            }

            // HR
            if let hr = interval.averageHeartRate {
                Text("\(Int(hr))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.red)
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(interval.intervalType.displayName) \(index), \(FormattingUtils.formatDuration(interval.actualDuration))")
    }

    // MARK: - Summary

    private var intervalSummary: some View {
        let workIntervals = intervals.filter { $0.intervalType == .work }
        let restIntervals = intervals.filter { $0.intervalType == .rest }

        return VStack(spacing: 6) {
            Divider()

            HStack {
                if !workIntervals.isEmpty {
                    summaryItem(
                        label: "Avg Work HR",
                        value: avgHR(workIntervals),
                        color: .green
                    )
                }
                if !restIntervals.isEmpty {
                    summaryItem(
                        label: "Avg Rest HR",
                        value: avgHR(restIntervals),
                        color: .orange
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    private func summaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func avgHR(_ intervals: [CompletedInterval]) -> String {
        let hrs = intervals.compactMap(\.averageHeartRate)
        guard !hrs.isEmpty else { return "--" }
        return "\(Int(hrs.reduce(0, +) / Double(hrs.count))) BPM"
    }

    private func intervalColor(_ type: IntervalType) -> Color {
        switch type {
        case .work: return .green
        case .rest: return .orange
        case .warmup: return .blue
        case .cooldown: return .blue
        }
    }
}
