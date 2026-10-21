import SwiftUI
import UserNotifications
import ShuttlXShared

/// Settings -> Heart -> Heart & alerts (timeline mockup, screen 5).
/// Every change is saved and pushed to the watch; medication notes never leave the phone.
/// Typed numbers (limits, age, max heart rate) are committed when editing ends, never per keystroke.
struct HeartAlertsView: View {
    @EnvironmentObject var sharedDataManager: PhoneSyncCoordinator
    @Environment(\.openURL) private var openURL
    @State private var heart = HeartSafetySettings.loadForEditing()
    @State private var age = DeviceManager.shared.userAge
    @State private var manualMaxHR = HeartRateZoneCalculator.loadSavedMaxHR().map { Int($0.rounded()) }
    @State private var maxHRMode: MaxHRMode = HeartRateZoneCalculator.loadSavedMaxHR() == nil ? .auto : .manual
    @State private var upperHint: String?
    @State private var lowHint: String?
    @State private var ageHint: String?
    @State private var maxHRHint: String?
    @State private var notificationsDenied = false
    #if DEBUG
    private static let seamBottom = ProcessInfo.processInfo.environment["SHUTTLX_SCROLL_BOTTOM"] == "1"
    #endif

    private enum MaxHRMode: String, CaseIterable { case auto = "Auto", manual = "Manual" }

    var body: some View {
        List {
            #if DEBUG
            if !Self.seamBottom { topSections }   // SHUTTLX_SCROLL_BOTTOM=1 screenshot seam
            #else
            topSections
            #endif
            pauseSection
            tellMeSection
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .listStyle(.insetGrouped)
        .navigationTitle("Heart & alerts")
        .navigationBarTitleDisplayMode(.large)
        .timelineScreenBackground()
        .onAppear {
            heart = HeartSafetySettings.loadForEditing()
            age = DeviceManager.shared.userAge
            // The age (typed, or from Health) may have lowered the estimated upper limit since the low limit was set.
            if let note = heart.reconcileLowLimit(age: age) {
                lowHint = note
                heart.saveForEditing()
                sharedDataManager.sendHeartSafetyToWatch(heart, age: age)
            }
        }
        .task { await refreshNotificationState() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    @ViewBuilder private var topSections: some View {
        if heart.hasNoLimit(age: age) { noLimitSection }
        limitSection
        maxHeartRateSection
        // "Heart rate from" (Best available / Apple Watch / AirPods Pro 3) is hidden: there is no runtime
        // path behind it yet. The stored fields stay; show `sourceSection` again when one exists.
    }

    /// Saves, keeps the low limit valid, and pushes to the watch. Called only after a toggle or a committed value.
    private func update(_ change: (inout HeartSafetySettings) -> Void) {
        change(&heart)
        if let low = heart.lowLimit {
            let range = HeartLimits.lowRange(upper: heart.effectiveUpperLimit(age: age))
            let fixed = min(max(low, range.lowerBound), range.upperBound)
            if fixed != low {
                heart.lowLimit = fixed
                lowHint = "Low limit changed to \(fixed) bpm to stay \(HeartLimits.lowGap) below the upper limit."
            }
        }
        heart.saveForEditing()
        sharedDataManager.sendHeartSafetyToWatch(heart, age: age)
    }

    /// Medication notes never leave the phone: save without a watch push.
    private func updateLocal(_ change: (inout HeartSafetySettings) -> Void) {
        change(&heart)
        heart.saveForEditing()
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<HeartSafetySettings, Bool>, asksNotifications: Bool = false) -> some View {
        Toggle(title, isOn: Binding(get: { heart[keyPath: keyPath] },
                                    set: { v in
            update { $0[keyPath: keyPath] = v }
            if v && asksNotifications {
                Task {
                    await PhoneSyncCoordinator.requestNotificationAuthorization()
                    await refreshNotificationState()
                }
            }
        }))
    }

    private func refreshNotificationState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = status == .denied
    }

    // MARK: No limit warning

    private var noLimitSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No heart limit set").fontWeight(.semibold)
                    Text("Type a limit, add your age for an estimate, or choose effort only. Until then the watch cannot warn you about a high heart rate.")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ShuttlXColor.ctaWarning)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Heart limit (not in the mockup: the Settings row pushes here, so the limit is edited here)

    private var limitSection: some View {
        Section {
            Toggle("I take a beta-blocker", isOn: Binding(
                get: { heart.onBetaBlocker ?? false },
                set: { v in update { $0.onBetaBlocker = v } }))
                .accessibilityHint("Heart rate runs lower on beta-blockers, so the estimated limit is lowered")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Heart limit")
                    Spacer()
                    CommitIntField(placeholder: heart.estimatedUpperLimit(age: age).map { "\($0) estimate" } ?? "Not set",
                                   value: heart.upperLimit, range: HeartLimits.upperRange, unit: "bpm", hint: $upperHint) { v in
                        update { $0.upperLimit = v }
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .disabled(heart.effortOnly)
                    Text("bpm").foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Heart limit in beats per minute")
                FieldHint(text: upperHint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Age")
                    Spacer()
                    CommitIntField(placeholder: "For the estimate", value: age, range: HeartLimits.ageRange, unit: "years", hint: $ageHint) { v in
                        DeviceManager.shared.userAge = v
                        age = v
                        update { _ in }
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 180)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Age in years")
                FieldHint(text: ageHint)
            }

            toggle("Use effort only", \.effortOnly)
                .accessibilityHint("Effort 0 to 10 scale, no heart rate limit")

            HStack {
                Text("Medicine")
                Spacer()
                TextField("Metoprolol", text: Binding(
                    get: { heart.medicineName ?? "" },
                    set: { v in updateLocal { $0.medicineName = v.isEmpty ? nil : v } }))
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Daily dose")
                Spacer()
                TextField("50 mg", text: Binding(
                    get: { heart.dailyDose ?? "" },
                    set: { v in updateLocal { $0.dailyDose = v.isEmpty ? nil : v } }))
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Your limit")
        } footer: {
            Text("Your own limit always wins over the estimate. The estimate is 85% of the age-predicted maximum (220 minus age), lowered further on a beta-blocker. It is not a prescription. Medication notes stay on this phone.")
        }
    }

    // MARK: Max heart rate (zones, colours, gym recovery)

    private var maxHeartRateSection: some View {
        Section {
            Picker("Max heart rate", selection: Binding(
                get: { maxHRMode },
                set: { mode in
                    maxHRMode = mode
                    if mode == .auto { resetMaxHR() }
                })) {
                ForEach(MaxHRMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Automatic uses your age. Manual uses a number you type, for example from a stress test.")

            if maxHRMode == .manual {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Your max")
                        Spacer()
                        CommitIntField(placeholder: "\(Int(autoMaxHR.rounded())) auto", value: manualMaxHR,
                                       range: HeartLimits.maxHRRange, unit: "bpm", hint: $maxHRHint) { v in
                            if let v {
                                HeartRateZoneCalculator.saveMaxHR(Double(v))
                                PhoneSyncCoordinator.shared.sendMaxHRToWatch(Double(v))
                                manualMaxHR = v
                            } else {
                                resetMaxHR()
                            }
                        }
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        Text("bpm").foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Your maximum heart rate in beats per minute")
                    FieldHint(text: maxHRHint)
                }
                if manualMaxHR != nil {
                    Button("Reset to automatic") { resetMaxHR(); maxHRMode = .auto }
                        .accessibilityHint("Removes your number on the phone and on the watch")
                }
            } else {
                HStack {
                    Text("Automatic")
                    Spacer()
                    Text("\(Int(autoMaxHR.rounded())) bpm").foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Max heart rate")
        } footer: {
            Text("Used for heart-rate colours and Gym Recovery. Your heart limit above is separate.")
        }
    }

    private var autoMaxHR: Double { HeartRateZoneCalculator(age: age, manualMaxHR: nil).estimatedMaxHR }

    private func resetMaxHR() {
        HeartRateZoneCalculator.saveMaxHR(0)
        PhoneSyncCoordinator.shared.sendMaxHRToWatch(0)
        manualMaxHR = nil
        maxHRHint = nil
    }

    // MARK: Heart rate from (hidden until a runtime path exists)

    private var sourceSection: some View {
        Section("Heart rate from") {
            sourceRow("Best available", sub: "Recommended", .best)
            sourceRow("Apple Watch", sub: nil, .watch)
            if #available(iOS 26, *) {
                // unverified: needs device test. No public AirPods heart-rate API in the SDK
                // headers, so this stores intent only and has no runtime path yet.
                sourceRow("AirPods Pro 3", sub: "Needs iOS 26. Works without a watch.", .airPods)
            }
        }
    }

    private func sourceRow(_ title: String, sub: String?, _ source: HeartRateSource) -> some View {
        Button {
            update { $0.heartRateSource = source; $0.useAirPodsHeartRate = source == .airPods }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(ShuttlXColor.textPrimary)
                    if let sub {
                        Text(sub).font(ShuttlXFont.cardCaption).foregroundStyle(Color.secondary)
                    }
                }
                Spacer()
                if heart.heartRateSource == source {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(heart.heartRateSource == source ? .isSelected : [])
    }

    // MARK: Pause for me

    private var pauseSection: some View {
        Section("Pause for me") {
            toggle("Pause when no heart rate", \.alertNoMotion, asksNotifications: true)
            Picker("After", selection: Binding(
                get: { heart.noMotionSeconds },
                set: { v in update { $0.noMotionSeconds = v } })) {
                ForEach([30, 60, 120], id: \.self) { Text("\($0) s").tag($0) }
            }
            .disabled(!heart.alertNoMotion)
            .accessibilityHint("How long without heart rate and movement before the workout pauses")
        }
    }

    // MARK: Tell me when

    private var tellMeSection: some View {
        Section {
            toggle("Above my limit", \.alertAboveLimit, asksNotifications: true)
            toggle("Below low limit", \.alertBelowLow, asksNotifications: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Low limit")
                    Spacer()
                    CommitIntField(placeholder: "Off", value: heart.lowLimit,
                                   range: HeartLimits.lowRange(upper: heart.effectiveUpperLimit(age: age)),
                                   unit: "bpm", hint: $lowHint) { v in
                        update { $0.lowLimit = v }
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    Text("bpm").foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Low heart rate limit in beats per minute")
                FieldHint(text: lowHint)
            }
            toggle("Sudden rise (+40 bpm in 10 s) - may false alarm", \.alertSuddenJump, asksNotifications: true)
            toggle("Signal lost", \.alertSignalLost, asksNotifications: true)
            HStack {
                Text("On watch (haptic) + iPhone")
                Spacer()
                Text("Both").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            if notificationsDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Notifications are off. The watch still buzzes, but this phone will not show alerts.",
                          systemImage: "bell.slash")
                        .font(ShuttlXFont.cardCaption)
                }
                .accessibilityHint("Opens Settings")
            }
        } header: {
            Text("Tell me when")
        } footer: {
            Text("ShuttlX is not a medical device. Alerts can be late or wrong. If you feel unwell, stop and call emergency services.")
        }
    }
}

#Preview {
    NavigationStack { HeartAlertsView().environmentObject(PhoneSyncCoordinator.shared) }
}
