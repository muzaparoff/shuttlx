import SwiftUI
import HealthKit
import WatchConnectivity
import WidgetKit
import TelemetryDeck
import ShuttlXShared

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var sharedDataManager: PhoneSyncCoordinator
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingHealthPermissionsInfo = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var showDebug = false
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var weightText: String = ""
    @State private var age: Int?
    @State private var ageHint: String?
    @State private var weightHint: String?
    @FocusState private var weightFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var heart = HeartSafetySettings.load()
    #if DEBUG
    @State private var seamHeartAlerts = false   // SHUTTLX_SHOW_HEART=1 screenshot seam
    #endif

    private static var seamSkipTop: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SHUTTLX_SCROLL_BOTTOM"] == "1"
        #else
        false
        #endif
    }

    var body: some View {
        List {
            if let notice = dataManager.storageNotice {
                Section {
                    Text(notice)
                        .font(.footnote)
                        .accessibilityLabel("Storage warning: \(notice)")
                    if dataManager.savesBlockedByCorruption {
                        Button("Start a new history and resume saving") { dataManager.resumeSavingAfterCorruption() }
                            .accessibilityHint("Keeps the unreadable file as a backup and saves new workouts to a new file")
                    } else {
                        Button("Dismiss") { dataManager.dismissStorageNotice() }
                    }
                }
            }
            if !Self.seamSkipTop {   // SHUTTLX_SCROLL_BOTTOM=1 screenshot seam (false in release)
            // Health & Watch
            Section("Health & Watch") {
                HStack {
                    Text("Watch Status")
                    Spacer()
                    statusDot(watchPaired)
                    Text(watchStatusText).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Watch Status")
                .accessibilityValue(watchStatusText)

                HStack {
                    Text("HealthKit Status")
                    Spacer()
                    statusDot(dataManager.healthKitAuthorized)
                    Text(dataManager.healthKitAuthorized ? "Allowed" : "Not allowed")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("HealthKit Status")
                .accessibilityValue(dataManager.healthKitAuthorized ? "Allowed" : "Not allowed")

                if dataManager.healthAccessDenied {
                    // iOS shows the Health sheet only once; after "Don't allow" only Settings can turn it back on.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Health access is off for ShuttlX. In Settings, open Apps, then Health, then turn on the data ShuttlX may use.")
                            .font(ShuttlXFont.cardCaption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .accessibilityHint("Opens the iPhone Settings for ShuttlX")
                    }
                } else if !dataManager.healthKitAuthorized || dataManager.healthReadAccessNeeded {
                    Button(dataManager.healthKitAuthorized ? "Allow reading past workouts" : "Request HealthKit Access") {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                        }
                    }
                    .accessibilityHint(dataManager.healthKitAuthorized
                        ? "Opens the Health permission dialog once, so workouts that did not sync from the watch can be read back"
                        : "Opens the HealthKit permission dialog")
                }

                Button("Why We Need Access") {
                    showingHealthPermissionsInfo = true
                }
                .accessibilityHint("Shows information about how health data is used")
            }

            // Heart
            Section("Heart") {
                if heart.hasNoLimit(age: age) {
                    NavigationLink {
                        HeartAlertsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No heart limit set").fontWeight(.semibold)
                                Text("The watch cannot warn you about a high heart rate. Tap to set one.")
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ShuttlXColor.ctaWarning)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens Heart and alerts")
                }
                NavigationLink {
                    HeartAlertsView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Heart limit")
                            Text("You or your doctor set it")
                                .font(ShuttlXFont.cardCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(heartLimitSummary)
                            .font(ShuttlXFont.cardSubtitle.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Heart limit and alerts")
                .accessibilityValue(heartLimitSummary)

                Toggle("Show effort 0–10 on watch", isOn: Binding(
                    get: { heart.showEffortOnWatch || heart.effortAlwaysOn },
                    set: { heart.showEffortOnWatch = $0; pushHeart() }))
                    .disabled(heart.effortAlwaysOn)
                    .accessibilityHint(heart.effortAlwaysOn ? "Always on with a beta-blocker or effort-only mode" : "Asks how hard the workout was when it ends")

                Toggle("Auto-switch Run / Walk", isOn: Binding(
                    get: { heart.autoSwitchActivity },
                    set: { heart.autoSwitchActivity = $0; pushHeart() }))
                    .accessibilityHint("The watch changes between run, walk and cycling on its own")
            }

            // Body Metrics Section (for calorie estimation)
            Section("Body Metrics") {
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("70", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($weightFocused)
                        .onSubmit(commitWeight)
                        .onChange(of: weightFocused) { _, focused in if !focused { commitWeight() } }
                        .onDisappear { if weightFocused { commitWeight() } }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Weight in kilograms")
                FieldHint(text: weightHint)

                HStack {
                    Text("Age")
                    Spacer()
                    CommitIntField(placeholder: "30", value: age, range: HeartLimits.ageRange, unit: "years", hint: $ageHint) { v in
                        deviceManager.userAge = v
                        age = v
                        pushHeart()
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Age in years")
                FieldHint(text: ageHint)
            }
            }

            // Account (App Store 5.1.1(v)): only for users who are signed in, with in-app deletion.
            if authManager.isSignedIn {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authManager.userName ?? "Signed in with Apple")
                            Text("iCloud sync is on")
                                .font(ShuttlXFont.cardCaption)
                                .foregroundStyle(ShuttlXColor.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Button("Sign Out") { showingSignOutConfirmation = true }
                        .accessibilityHint("Stops iCloud sync. Workouts on this iPhone are kept")

                    Button("Delete Account", role: .destructive) { showingDeleteAccountConfirmation = true }
                        .foregroundStyle(ShuttlXColor.ctaDestructive)
                        .disabled(isDeletingAccount)
                        .accessibilityHint("Permanently deletes your iCloud data and workouts on this iPhone")
                }
            }

            // Data Management Section
            Section("Data Management") {
                Button("Clear All Training Sessions", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .foregroundStyle(ShuttlXColor.ctaDestructive)
                .accessibilityHint("Permanently deletes all training session data")
            }

            #if DEBUG
            if showDebug {
            Section("Debug") {
                NavigationLink("Sync Debug") { SyncDebugView() }
            }
            }
            #endif

            // Help Section
            Section("Help") {
                NavigationLink {
                    HelpView()
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Help")
                    }
                }
                .accessibilityLabel("Help")
                .accessibilityHint("How-to guides for workouts, programs, themes, widgets, and privacy")

                Button {
                    if let url = feedbackMailURL {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text("Send Feedback")
                            .foregroundStyle(ShuttlXColor.textPrimary)
                    }
                }
                .accessibilityLabel("Send Feedback")
                .accessibilityHint("Opens an email to the developer with your app version and device details prefilled")
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 1) { showDebug = true }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("App Version")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Build Number")
                .accessibilityValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "101")
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingHealthPermissionsInfo) {
            HealthPermissionsInfoView()
        }
        .alert("Clear All Training Sessions", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                dataManager.wipeLocalUserData(.trainingData)
                successMessage = "All sessions cleared!"
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                }
            }
        } message: {
            Text("This deletes every workout on this iPhone, your edits to workout parts, and the Apple Health import history, and asks your Apple Watch to remove its copies. Your templates, plans and settings stay. Workouts in Apple Health and iCloud are not deleted, and they will not come back here. This cannot be undone.")
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { authManager.signOut() }
        } message: {
            Text("Your workouts on this iPhone are kept, but they will no longer sync to iCloud.")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account & Data", role: .destructive) {
                isDeletingAccount = true
                Task {
                    do {
                        try await authManager.deleteAccount(dataManager: dataManager, sharedDataManager: sharedDataManager)
                        successMessage = "Account deleted"
                    } catch {
                        successMessage = "Could not delete the account. Check your connection and try again."
                    }
                    showSuccessMessage = true
                    isDeletingAccount = false
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showSuccessMessage = false
                }
            }
        } message: {
            Text("This permanently deletes your workouts and templates in iCloud. It then erases from this iPhone: all workouts, your edits to workout parts, templates, training plans and progress, exercise devices, heart limits and your medication answer, weight and age, and the Apple Health import history. Your Apple Watch is asked to remove its copies. Workouts saved in Apple Health are not deleted. This cannot be undone.")
        }
        .overlay(alignment: .top) {
            if showSuccessMessage {
                ToastView(message: successMessage, systemImage: "checkmark.circle.fill")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .accessibilityLabel(successMessage)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSuccessMessage)
        .timelineScreenBackground()
        .scrollDismissesKeyboard(.interactively)
        #if DEBUG
        .navigationDestination(isPresented: $seamHeartAlerts) { HeartAlertsView() }
        #endif
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["SHUTTLX_SHOW_HEART"] == "1" { seamHeartAlerts = true }
            #endif
            if let weight = deviceManager.userWeightKg {
                weightText = String(format: "%.1f", weight)
            }
            age = deviceManager.userAge
            heart = HeartSafetySettings.load()
        }
        .task { await dataManager.refreshHealthAccessState() }
        .onChange(of: scenePhase) { _, phase in
            // Back from iPhone Settings: pick up a changed Health permission.
            if phase == .active { Task { await dataManager.refreshHealthAccessState() } }
        }
    }

    // MARK: - Feedback Mail

    /// `mailto:` URL with subject "ShuttlX <version> (<build>) feedback" and a
    /// body prefilled with app version, iOS version, and device model.
    /// URL-encoding is handled by `URLComponents`.
    private var feedbackMailURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let body = """
        App version: \(version) (\(build))
        iOS version: \(UIDevice.current.systemVersion)
        Device: \(deviceModelIdentifier)


        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "muzyukins@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "ShuttlX \(version) (\(build)) feedback"),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }

    /// Hardware model identifier (e.g. "iPhone16,1") — more useful in feedback
    /// mail than `UIDevice.model`, which only says "iPhone".
    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    // MARK: - Watch Helpers

    private var watchPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    private var watchStatusText: String {
        guard WCSession.isSupported() else { return "Not Supported" }
        return WCSession.default.isPaired ? "Connected" : "Not paired"
    }

    /// Weight commits when editing ends. "72,5" and "72.5" both work; out-of-range values are clamped.
    private func commitWeight() {
        let t = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            deviceManager.userWeightKg = nil
            weightHint = nil
            return
        }
        guard let v = HeartLimits.decimal(t) else {
            weightText = deviceManager.userWeightKg.map { String(format: "%.1f", $0) } ?? ""
            weightHint = "Not changed. Enter your weight in kg, for example 72.5."
            return
        }
        let r = HeartLimits.weightRange
        let c = min(max(v, r.lowerBound), r.upperBound)
        deviceManager.userWeightKg = c
        weightText = String(format: "%.1f", c)
        weightHint = c != v ? "Changed to \(Int(c)) kg. Allowed: \(Int(r.lowerBound)) to \(Int(r.upperBound)) kg." : nil
    }

    private func pushHeart() {
        heart.save()
        sharedDataManager.sendHeartSafetyToWatch(heart, age: age)
    }

    private var heartLimitSummary: String {
        if heart.effortOnly { return "Effort only" }
        return heart.effectiveUpperLimit(age: age).map { "\($0) bpm" } ?? "Not set"
    }

    private func statusDot(_ good: Bool) -> some View {
        Circle()
            .fill(good ? ShuttlXColor.positive : Color.secondary)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

// Toast message view
struct ToastView: View {
    var message: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ShuttlXColor.positive)
            Text(message)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// HealthPermissionsInfoView
struct HealthPermissionsInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why ShuttlX Needs HealthKit Access")
                        .font(.largeTitle.bold())
                        .padding(.bottom)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Read")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text("Heart Rate: To monitor your exertion during workouts")
                        Text("Steps & Distance: To track your activity accurately")
                        Text("Calories: To measure energy expenditure")
                    }
                    .padding(.bottom)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Store")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)

                        Text("Workout Sessions: To maintain your training history")
                        Text("Active Energy: To track calories burned during activities")
                        Text("Distance: To record your training progress")
                    }
                    .padding(.bottom)

                    Text("Your health data remains private and is only used within the app to enhance your training experience. We never share your health information with third parties.")
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .themedScreenBackground()
            .navigationTitle("Health Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(ThemeManager.shared)
            .environmentObject(DataManager())
            .environmentObject(PhoneSyncCoordinator.shared)
            .environmentObject(AuthenticationManager.shared)
    }
}
