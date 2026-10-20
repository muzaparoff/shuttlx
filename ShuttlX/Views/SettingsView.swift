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
    @State private var showingHealthPermissionsInfo = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var isSyncing = false
    @State private var showDebug = false
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var weightText: String = ""
    @State private var ageText: String = ""
    @State private var maxHRText: String = ""
    @State private var heart = HeartSafetySettings.load()
    @State private var upperLimitText = ""
    @State private var lowLimitText = ""

    var body: some View {
        List {
            // Watch Connection Section
            Section("Apple Watch") {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Watch Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(watchPaired ? ShuttlXColor.positive : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(watchStatusText)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Watch Status")
                .accessibilityValue(watchStatusText)

                if watchPaired {
                    Button {
                        isSyncing = true
                        sharedDataManager.requestSessionsFromWatch { count in
                            sharedDataManager.reconcileSessionIDs()
                            isSyncing = false
                            if count > 0 {
                                dataManager.loadSessionsFromAppGroup()
                                successMessage = "Synced \(count) session\(count == 1 ? "" : "s") from Watch"
                            } else {
                                successMessage = "No new sessions on Watch"
                            }
                            showSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                showSuccessMessage = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync from Watch")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                    .accessibilityHint("Pulls training sessions directly from your Apple Watch")

                    HStack {
                        Label("Last Sync", systemImage: "clock")
                        Spacer()
                        Text(sharedDataManager.lastSyncTime.map { FormattingUtils.formatShortDate($0) } ?? "Never")
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Connection", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text("\(Int(sharedDataManager.connectivityHealth * 100))%")
                            .font(ShuttlXFont.cardCaption.monospacedDigit())
                            .foregroundStyle(sharedDataManager.connectivityHealth > 0.5 ? ShuttlXColor.positive : ShuttlXColor.ctaWarning)
                    }
                }
            }

            // Health Integration Section
            Section("Health Integration") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(ShuttlXColor.heartRate)
                        .accessibilityHidden(true)
                    Text("HealthKit Status")
                    Spacer()
                    Text(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")
                        .foregroundStyle(dataManager.healthKitAuthorized ? ShuttlXColor.positive : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("HealthKit Status")
                .accessibilityValue(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")

                if !dataManager.healthKitAuthorized {
                    Button("Request HealthKit Access") {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                        }
                    }
                    .accessibilityHint("Opens the HealthKit permission dialog")
                }

                Button("Why We Need Access") {
                    showingHealthPermissionsInfo = true
                }
                .accessibilityHint("Shows information about how health data is used")
            }

            // Body Metrics Section (for calorie estimation)
            Section("Body Metrics") {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Weight (kg)")
                    Spacer()
                    TextField("70", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: weightText) { _, newValue in
                            deviceManager.userWeightKg = Double(newValue)
                        }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Weight in kilograms")

                HStack {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Age")
                    Spacer()
                    TextField("30", text: $ageText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: ageText) { _, newValue in
                            deviceManager.userAge = Int(newValue)
                            pushHeart()
                        }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Age in years")

                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(ShuttlXColor.heartRate)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Heart Rate (BPM)")
                        Text("Override auto-calculated value")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField(maxHRPlaceholder, text: $maxHRText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: maxHRText) { _, newValue in
                            if let bpm = Double(newValue), bpm > 0 {
                                HeartRateZoneCalculator.saveMaxHR(bpm)
                                sharedDataManager.sendMaxHRToWatch(bpm)
                            } else if newValue.isEmpty {
                                HeartRateZoneCalculator.saveMaxHR(0)   // 0 means "clear"
                                sharedDataManager.sendMaxHRToWatch(0)
                            }
                        }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Maximum heart rate in beats per minute")
                .accessibilityHint("Leave blank to use the Tanaka formula based on your age")

                Text("Used for personalised heart rate zones. Auto-detected from HealthKit age when blank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Heart & alerts Section
            Section {
                Toggle("I take a beta-blocker", isOn: Binding(
                    get: { heart.onBetaBlocker ?? false },
                    set: { heart.onBetaBlocker = $0; pushHeart() }))
                    .accessibilityHint("Heart rate runs lower on beta-blockers, so the estimated limit is lowered")

                HStack {
                    Text("Upper limit (BPM)")
                    Spacer()
                    TextField(heart.estimatedUpperLimit(age: deviceManager.userAge).map { "\($0) estimate" } ?? "Off",
                              text: $upperLimitText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .onChange(of: upperLimitText) { _, v in heart.upperLimit = Int(v); pushHeart() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Upper heart rate limit in beats per minute")

                HStack {
                    Text("Low limit (BPM)")
                    Spacer()
                    TextField("Off", text: $lowLimitText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .onChange(of: lowLimitText) { _, v in heart.lowLimit = Int(v); pushHeart() }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Low heart rate limit in beats per minute")

                Toggle("Heart rate above limit", isOn: Binding(
                    get: { heart.alertAboveLimit }, set: { heart.alertAboveLimit = $0; pushHeart() }))
                Toggle("Heart rate below low limit", isOn: Binding(
                    get: { heart.alertBelowLow && heart.lowLimit != nil },
                    set: { heart.alertBelowLow = $0; pushHeart() }))
                    .disabled(heart.lowLimit == nil)
                Toggle("Heart signal lost", isOn: Binding(
                    get: { heart.alertSignalLost }, set: { heart.alertSignalLost = $0; pushHeart() }))
                Toggle("No motion", isOn: Binding(
                    get: { heart.alertNoMotion }, set: { heart.alertNoMotion = $0; pushHeart() }))

                if #available(iOS 26, *) {
                    // unverified: needs device test. No public AirPods heart-rate API in the SDK
                    // headers, so this stores intent only and has no runtime path yet.
                    Toggle("Use AirPods heart rate", isOn: Binding(
                        get: { heart.useAirPodsHeartRate }, set: { heart.useAirPodsHeartRate = $0; pushHeart() }))
                }
            } header: {
                Text("Heart & alerts")
            } footer: {
                Text("Your own limit always wins over the estimate. Your medication answer stays on this device. Alerts are a reminder, not medical advice.")
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
                PhoneSyncCoordinator.shared.purgeAllSessionsFromStorage()
                dataManager.sessions = []
                dataManager.saveSessionsToAppGroup()
                successMessage = "All sessions cleared!"
                showSuccessMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccessMessage = false
                }
            }
        } message: {
            Text("This will delete all your training history. This action cannot be undone.")
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
        .themedScreenBackground()
        .onAppear {
            if let weight = deviceManager.userWeightKg {
                weightText = String(format: "%.1f", weight)
            }
            if let age = deviceManager.userAge {
                ageText = "\(age)"
            }
            heart = HeartSafetySettings.load()
            upperLimitText = heart.upperLimit.map(String.init) ?? ""
            lowLimitText = heart.lowLimit.map(String.init) ?? ""
            // Load manually saved max HR (empty string when using auto-calculation)
            if let savedMaxHR = HeartRateZoneCalculator.loadSavedMaxHR(), savedMaxHR > 0 {
                maxHRText = "\(Int(savedMaxHR.rounded()))"
            }
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
        return WCSession.default.isPaired ? "Paired" : "Not Paired"
    }

    private func pushHeart() {
        heart.save()
        sharedDataManager.sendHeartSafetyToWatch(heart, age: deviceManager.userAge)
    }

    /// Shows the Tanaka-formula estimate as the placeholder when no manual override is stored.
    private var maxHRPlaceholder: String {
        let calculator = HeartRateZoneCalculator(
            age: deviceManager.userAge,
            manualMaxHR: nil
        )
        let estimated = Int(calculator.estimatedMaxHR.rounded())
        return "\(estimated)"
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
