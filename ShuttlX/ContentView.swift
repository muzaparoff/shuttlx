import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var deepLinkRouter: DeepLinkRouter
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
        .task {
            // Cold-launch case: `onOpenURL` can set `deepLinkRouter` state
            // before this view mounts, so a plain `.onChange` below would
            // never fire for that value. Consume on mount too.
            consumePendingSessionDeepLink()
            selectPendingTab()
        }
        .onChange(of: deepLinkRouter.pendingSessionID) { _, _ in
            consumePendingSessionDeepLink()
        }
        .onChange(of: dataManager.sessions) { _, _ in
            // The session id may have arrived before sessions finished
            // loading from the App Group — retry here instead of dropping
            // it (see `consumePendingSessionDeepLink`).
            consumePendingSessionDeepLink()
        }
        .onChange(of: deepLinkRouter.pendingTab) { _, _ in
            selectPendingTab()
        }
    }

    /// Consumes `shuttlx://session/{uuid}` deep links. Only clears
    /// `pendingSessionID` once the matching session is actually found and
    /// presented — if `dataManager.sessions` hasn't loaded yet, the id is
    /// left in place so the `onChange(of: dataManager.sessions)` observer
    /// above can retry once it does, instead of the link being silently
    /// swallowed.
    private func consumePendingSessionDeepLink() {
        guard let id = deepLinkRouter.pendingSessionID else { return }
        guard let session = dataManager.sessions.first(where: { $0.id == id }) else {
            return
        }
        deepLinkRouter.pendingSessionID = nil
        showingDeepLinkSession = session
    }

    /// Consumes `shuttlx://dashboard` deep links (selects the Training tab).
    private func selectPendingTab() {
        guard let tab = deepLinkRouter.pendingTab else { return }
        selectedTab = tab
        deepLinkRouter.pendingTab = nil
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
        .environmentObject(DeepLinkRouter())
}
