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
        VStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Start Training on Apple Watch")
                .font(ShuttlXFont.cardTitle)
                .multilineTextAlignment(.center)

            Text("ShuttlX auto-detects running and walking.\nJust press Start on your Watch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Connectivity status
            HStack(spacing: 12) {
                StatusPill(
                    icon: isPaired ? "checkmark.circle.fill" : "xmark.circle.fill",
                    text: isPaired ? "Paired" : "Not Paired",
                    isGood: isPaired
                )

                StatusPill(
                    icon: isReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash",
                    text: isReachable ? "Reachable" : "Not Reachable",
                    isGood: isReachable
                )
            }

            // Activity icons
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundStyle(ShuttlXColor.running)
                    Text("Running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.title3)
                        .foregroundStyle(ShuttlXColor.walking)
                    Text("Walking")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start training on Apple Watch. Watch is \(isPaired ? "paired" : "not paired") and \(isReachable ? "reachable" : "not reachable")")
    }
}

private struct StatusPill: View {
    let icon: String
    let text: String
    let isGood: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(isGood ? .green : .secondary)
    }
}

#Preview {
    StartOnWatchCard()
        .padding()
}
