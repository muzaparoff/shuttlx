import SwiftUI

struct ActivityBadge: View {
    let activity: DetectedActivity
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: activity.systemImage)
                .font(.caption2)
            Text(FormattingUtils.formatDuration(duration))
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(activity.themeColor)
        .background(activity.themeColor.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.displayName) \(FormattingUtils.formatDuration(duration))")
    }
}

#Preview {
    HStack {
        ActivityBadge(activity: .running, duration: 900)
        ActivityBadge(activity: .walking, duration: 600)
    }
}
