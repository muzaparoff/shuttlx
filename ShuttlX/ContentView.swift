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

            TemplateListView()
                .tabItem {
                    Label("Programs", systemImage: "timer")
                }
                .accessibilityLabel("Programs tab")
                .accessibilityHint("Create and manage interval workout programs")

            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .accessibilityLabel("History tab")
                .accessibilityHint("View your past training sessions")

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .accessibilityLabel("Analytics tab")
                .accessibilityHint("View training analytics and trends")

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
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager())
}
