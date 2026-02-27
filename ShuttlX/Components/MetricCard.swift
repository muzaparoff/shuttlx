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

            Text(value)
                .font(compact ? ShuttlXFont.metricSmall : ShuttlXFont.metricMedium)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 8 : 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
