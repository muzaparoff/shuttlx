import SwiftUI

struct WatchPromptView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "applewatch")
                    .font(ShuttlXFont.heroIcon)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Start Training on your Apple Watch")
                    .font(ShuttlXFont.cardTitle)
                    .multilineTextAlignment(.center)

                Text("ShuttlX auto-detects running and walking.\nJust press Start on your Watch.")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 32) {
                    VStack {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(ShuttlXColor.running)
                        Text("Running")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auto-detects running")

                    VStack {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(ShuttlXColor.walking)
                        Text("Walking")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auto-detects walking")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Training")
            .themedScreenBackground()
        }
    }
}

#Preview {
    WatchPromptView()
}
