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

                Text("ShuttlX finds running and walking by itself.\nJust press Start on your Watch.")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 32) {
                    VStack {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(ShuttlXColor.accentText)
                        Text("Running")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Finds running by itself")

                    VStack {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(ShuttlXColor.walking)
                        Text("Walking")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Finds walking by itself")
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
