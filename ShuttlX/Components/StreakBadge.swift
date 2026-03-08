import SwiftUI

struct StreakBadge: View {
    let streakDays: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(ShuttlXColor.ctaWarning)
            Text("\(streakDays) day streak")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ShuttlXColor.ctaWarning.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streakDays) day workout streak")
    }
}

#Preview {
    StreakBadge(streakDays: 5)
}
