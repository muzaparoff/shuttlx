import SwiftUI

struct StreakBadge: View {
    let streakDays: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streakDays) day streak")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streakDays) day workout streak")
    }
}

#Preview {
    StreakBadge(streakDays: 5)
}
