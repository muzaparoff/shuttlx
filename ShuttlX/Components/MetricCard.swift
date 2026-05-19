import SwiftUI

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            Image(systemName: icon)
                .font(compact ? .body : .title2)
                .foregroundStyle(color)
                // Fixed frame prevents SF Symbols with different intrinsic heights
                // (shoeprints.fill, figure.run.motion vs heart.fill) from making
                // cards in different grid rows render at different heights.
                .frame(width: compact ? 20 : 28, height: compact ? 20 : 28)

            Text(value)
                .font(compact ? ShuttlXFont.metricSmall : ShuttlXFont.metricMedium)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 0 : 88)
        .padding(compact ? 8 : 12)
        .themedCard(accent: color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    HStack {
        MetricCard(icon: "heart.fill", value: "142", label: "Avg HR", color: ShuttlXColor.heartRate)
        MetricCard(icon: "flame.fill", value: "280", label: "Calories", color: ShuttlXColor.calories)
    }
    .padding()
}
