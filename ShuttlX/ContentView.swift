import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        TabView {
            WatchPromptView()
                .tabItem {
                    Label("Training", systemImage: "figure.run")
                }
                .accessibilityLabel("Training tab")
                .accessibilityHint("Start training on your Apple Watch")

            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .accessibilityLabel("History tab")
                .accessibilityHint("View your past training sessions")

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .accessibilityLabel("Settings tab")
            .accessibilityHint("Adjust app preferences")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
