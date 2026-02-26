import SwiftUI

struct WatchPromptView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "applewatch")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)

                Text("Start Training on your Apple Watch")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("ShuttlX auto-detects running and walking.\nJust press Start on your Watch.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                HStack(spacing: 32) {
                    VStack {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Running")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auto-detects running")

                    VStack {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Walking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auto-detects walking")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Training")
        }
    }
}

#Preview {
    WatchPromptView()
}
