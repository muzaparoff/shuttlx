import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var deepLinkSessionID: UUID?
    @State private var selectedTab = 0
    @State private var showingDeepLinkSession: TrainingSession?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Training", systemImage: "figure.run")
                }
                .tag(0)
                .accessibilityLabel("Training tab")
                .accessibilityHint("Dashboard with workout status and quick start")

            ProgramsTabView()
                .tabItem {
                    Label("Programs", systemImage: "calendar.badge.clock")
                }
                .tag(1)
                .accessibilityLabel("Programs tab")
                .accessibilityHint("Training plans and interval workout programs")

            TrainingHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(2)
                .accessibilityLabel("History tab")
                .accessibilityHint("View your past training sessions")

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
                .accessibilityLabel("Analytics tab")
                .accessibilityHint("View training analytics and trends")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
            .accessibilityLabel("Settings tab")
            .accessibilityHint("Adjust app preferences")
        }
        .modifier(TabBarMinimizeModifier())
        .sheet(item: $showingDeepLinkSession) { session in
            NavigationStack {
                SessionDetailView(session: session)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingDeepLinkSession = nil }
                        }
                    }
            }
        }
        .onChange(of: deepLinkSessionID) { _, newID in
            guard let id = newID,
                  let session = dataManager.sessions.first(where: { $0.id == id }) else { return }
            deepLinkSessionID = nil
            showingDeepLinkSession = session
        }
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
    ContentView(deepLinkSessionID: .constant(nil))
        .environmentObject(DataManager())
}
