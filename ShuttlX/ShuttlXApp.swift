import SwiftUI
import RevenueCat
import TelemetryDeck

@main
struct ShuttlXApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager.shared
    @StateObject private var dataManager = DataManager()
    @StateObject private var sharedDataManager = SharedDataManager.shared
    @StateObject private var templateManager = TemplateManager()
    @StateObject private var planManager = PlanManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var cloudKitSync = CloudKitSyncManager.shared
    @StateObject private var workoutController = iPhoneWorkoutController()
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    @State private var deepLinkSessionID: UUID?

    private let subscriptionManager = SubscriptionManager.shared

    init() {
        subscriptionManager.configure()

        let telemetryConfig = TelemetryDeck.Config(appID: "2323535F-7F18-45F3-ACA2-215164CD22BC")
        TelemetryDeck.initialize(config: telemetryConfig)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isFirstLaunch {
                    OnboardingView(isFirstLaunch: $isFirstLaunch)
                } else {
                    ContentView(deepLinkSessionID: $deepLinkSessionID)
                }
            }
            .environment(themeManager)
            .environmentObject(dataManager)
            .environmentObject(sharedDataManager)
            .environmentObject(templateManager)
            .environmentObject(planManager)
            .environmentObject(authManager)
            .environmentObject(cloudKitSync)
            .environmentObject(workoutController)
            // Present the iPhone workout timer over whatever's on screen when
            // any entry-point view calls `controller.presentFreeRun()` /
            // `presentInterval(template:)` / `presentGymRecovery()`. The
            // controller's tearDown() flips this back to false on Finish /
            // Cancel, dismissing the cover.
            .fullScreenCover(isPresented: $workoutController.isPresentingTimer) {
                iPhoneWorkoutTimerView(controller: workoutController)
                    .environment(themeManager)
                    .environmentObject(dataManager)
            }
            .task {
                // Wire the controller's DataManager dependency once at startup.
                // The controller saves finished sessions via
                // DataManager.handleReceivedSessions(_:) — same store the
                // watch writes to.
                workoutController.dataManager = dataManager
            }
            .onOpenURL { url in
                guard url.scheme == "shuttlx" else { return }
                if url.host == "session",
                   let idString = url.pathComponents.last,
                   let uuid = UUID(uuidString: idString) {
                    deepLinkSessionID = uuid
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dataManager.loadSessionsFromAppGroup()
                sharedDataManager.reconcileWithDataManager()
                sharedDataManager.reconcileSessionIDs()
                if authManager.isSignedIn {
                    cloudKitSync.performFullSync(dataManager: dataManager)
                }
                Task {
                    await subscriptionManager.refreshEntitlementStatus()
                }
            }
        }
    }
}
