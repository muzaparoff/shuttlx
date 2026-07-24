import SwiftUI
import WatchConnectivity

struct StartOnWatchCard: View {
    private var isReachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    private var isPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    var body: some View {
        HStack(spacing: ShuttlXSpacing.md) {
            // Watch silhouette
            RoundedRectangle(cornerRadius: 7)
                .fill(ShuttlXColor.surface)
                .frame(width: 30, height: 36)
                .overlay(
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(ShuttlXColor.surfaceBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Watch")
                    .font(ShuttlXFont.cardTitle)
                    .foregroundStyle(ShuttlXColor.textPrimary)

                Text(statusText)
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(isReachable ? ShuttlXColor.ctaPrimary : ShuttlXColor.textSecondary)
            }

            Spacer()

            // Signal strength bars
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < signalBars ? ShuttlXColor.ctaPrimary : ShuttlXColor.surfaceBorder)
                        .frame(width: 4, height: CGFloat(6 + i * 4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .themedCard(accent: ShuttlXColor.steps, headerLabel: "WATCH STATUS")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start training on Apple Watch. Watch is \(isPaired ? "paired" : "not paired") and \(isReachable ? "reachable" : "not reachable")")
    }

    private var statusColor: Color {
        guard isPaired else { return ShuttlXColor.ctaDestructive }
        return isReachable ? ShuttlXColor.ctaPrimary : ShuttlXColor.ctaWarning
    }

    private var statusText: String {
        guard isPaired else { return "Not paired" }
        return isReachable ? "Connected · Ready" : "Not reachable"
    }

    private var signalBars: Int {
        guard isPaired else { return 0 }
        return isReachable ? 4 : 1
    }
}

#Preview {
    StartOnWatchCard()
        .padding()
}
