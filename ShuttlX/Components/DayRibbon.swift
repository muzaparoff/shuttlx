import SwiftUI
import ShuttlXShared

/// Horizontal ribbon of capsules sized by segment duration. Display only.
struct ActivityRibbon: View {
    let segments: [ActivitySegment]
    var height: CGFloat = 14
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColorOnly

    private var total: TimeInterval { segments.reduce(0) { $0 + max(0, $1.duration) } }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    let fraction = total > 0 ? max(0, segment.duration) / total : 0
                    let width = max(6, geo.size.width * fraction)
                    Capsule()
                        .fill(segment.activityType.themeColor)
                        .frame(width: width)
                        .overlay {
                            // Differentiate Without Colour: a glyph so run vs walk is not told by colour alone.
                            if noColorOnly, width >= height {
                                Image(systemName: segment.activityType.systemImage)
                                    .font(.system(size: max(8, height * 0.6)))
                                    .foregroundStyle(ShuttlXColor.iconOnCTA)
                                    .accessibilityHidden(true)
                            }
                        }
                }
            }
        }
        .frame(height: height)
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
        "\(TodayFormat.clock(segment.startDate)) · \(TodayFormat.short(segment.duration))"
    }

    private var distanceText: String? {
        guard let km = segment.distance, km > 0 else { return nil }
        return FormattingUtils.formatDistance(km, unit: .current)
    }

    private var paceText: String? {
        guard let km = segment.distance, km > 0.05, segment.duration > 0 else { return nil }
        return FormattingUtils.formatPaceWithUnit(segment.duration / km, unit: .current)
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(segment.activityType.themeColor)
                .frame(width: 10, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TodayFormat.activityName(segment.activityType))
                    .font(ShuttlXFont.cardSubtitle.weight(.semibold))
                    .foregroundStyle(ShuttlXColor.textPrimary)
                Text(timeText)
                    .font(ShuttlXFont.cardCaption.monospacedDigit())
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            Spacer()
            if let distanceText {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(distanceText)
                        .font(ShuttlXFont.cardSubtitle.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ShuttlXColor.textPrimary)
                    if let paceText {
                        Text(paceText)
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(ShuttlXColor.textSecondary)
                    }
                }
            }
            Image(systemName: "chevron.right")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.activityType.displayName), \(timeText)" + (distanceText.map { ", \($0)" } ?? "") + (paceText.map { ", \($0)" } ?? ""))
    }
}
