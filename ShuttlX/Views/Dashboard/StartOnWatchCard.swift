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
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Start on Apple Watch")
                    .font(ShuttlXFont.cardTitle)

                Text(isPaired ? (isReachable ? "Ready" : "Not reachable") : "Not paired")
                    .font(ShuttlXFont.cardCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(isReachable ? ShuttlXColor.ctaPrimary : Color.secondary)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .themedCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start training on Apple Watch. Watch is \(isPaired ? "paired" : "not paired") and \(isReachable ? "reachable" : "not reachable")")
    }
}

#Preview {
    StartOnWatchCard()
        .padding()
}
