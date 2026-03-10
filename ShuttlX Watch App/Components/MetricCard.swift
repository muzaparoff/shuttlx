import SwiftUI

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: ShuttlXSpacing.xs) {
            Image(systemName: icon)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(color)

            Text(value)
                .font(ShuttlXFont.metricSmall)
                .monospacedDigit()

            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ShuttlXSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
