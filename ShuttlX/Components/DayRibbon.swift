import SwiftUI
import ShuttlXShared

/// Horizontal ribbon of capsules sized by segment duration. Display only.
struct ActivityRibbon: View {
    let segments: [ActivitySegment]

    private var total: TimeInterval { segments.reduce(0) { $0 + max(0, $1.duration) } }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let fraction = total > 0 ? max(0, segment.duration) / total : 0
                    Capsule()
                        .fill(segment.activityType.themeColor)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
        }
        .frame(height: 14)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let parts = segments.map { "\($0.activityType.displayName) \(FormattingUtils.formatDuration($0.duration))" }
        return "Session parts: " + parts.joined(separator: ", ")
    }
}

/// One row of the parts list: colour bar, activity, start time + duration, distance when known.
struct SessionPartRow: View {
    let segment: ActivitySegment

    private var timeText: String {
        "\(segment.startDate.formatted(date: .omitted, time: .shortened)) · \(FormattingUtils.formatDuration(segment.duration))"
    }

    private var distanceText: String? {
        guard let km = segment.distance, km > 0 else { return nil }
        return FormattingUtils.formatDistance(km)
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(segment.activityType.themeColor)
                .frame(width: 5, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.activityType.displayName)
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text(timeText)
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            Spacer()
            if let distanceText {
                Text(distanceText)
                    .font(ShuttlXFont.cardSubtitle.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.activityType.displayName), \(timeText)" + (distanceText.map { ", \($0)" } ?? ""))
    }
}
