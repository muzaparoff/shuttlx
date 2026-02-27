import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Training", systemImage: "figure.run")
                }
                .accessibilityLabel("Training tab")
                .accessibilityHint("Dashboard with workout status and quick start")

            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .accessibilityLabel("History tab")
                .accessibilityHint("View your past training sessions")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .accessibilityLabel("Settings tab")
            .accessibilityHint("Adjust app preferences")
        }
        .modifier(TabBarMinimizeModifier())
    }
}

private struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
