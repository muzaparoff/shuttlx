import SwiftUI
import ShuttlXShared

/// Settings -> Heart -> Heart & alerts (timeline mockup, screen 5).
/// Every change is saved and pushed to the watch; medication notes never leave the phone.
struct HeartAlertsView: View {
    @EnvironmentObject var sharedDataManager: PhoneSyncCoordinator
    @State private var heart = HeartSafetySettings.load()
    #if DEBUG
    private static let seamBottom = ProcessInfo.processInfo.environment["SHUTTLX_SCROLL_BOTTOM"] == "1"
    #endif
    private let age = DeviceManager.shared.userAge

    var body: some View {
        List {
            #if DEBUG
            if !Self.seamBottom { limitSection; sourceSection }   // SHUTTLX_SCROLL_BOTTOM=1 screenshot seam
            #else
            limitSection
            sourceSection
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
        .onAppear { heart = HeartSafetySettings.load() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }

    private func update(_ change: (inout HeartSafetySettings) -> Void) {
        change(&heart)
        heart.save()
        sharedDataManager.sendHeartSafetyToWatch(heart, age: age)
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<HeartSafetySettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { heart[keyPath: keyPath] },
                                    set: { v in update { $0[keyPath: keyPath] = v } }))
    }

    // MARK: Heart limit (not in the mockup: the Settings row pushes here, so the limit is edited here)

    private var limitSection: some View {
        Section {
            Toggle("I take a beta-blocker", isOn: Binding(
                get: { heart.onBetaBlocker ?? false },
                set: { v in update { $0.onBetaBlocker = v } }))
                .accessibilityHint("Heart rate runs lower on beta-blockers, so the estimated limit is lowered")

            HStack {
                Text("Heart limit")
                Spacer()
                TextField(heart.estimatedUpperLimit(age: age).map { "\($0) estimate" } ?? "Off",
                          text: Binding(get: { heart.upperLimit.map(String.init) ?? "" },
                                        set: { v in update { $0.upperLimit = Int(v) } }))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .disabled(heart.effortOnly)
                Text("bpm").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart limit in beats per minute")

            toggle("Use effort only", \.effortOnly)
                .accessibilityHint("Effort 0 to 10 scale, no heart rate limit")

            HStack {
                Text("Medicine")
                Spacer()
                TextField("Metoprolol", text: Binding(
                    get: { heart.medicineName ?? "" },
                    set: { v in update { $0.medicineName = v.isEmpty ? nil : v } }))
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Daily dose")
                Spacer()
                TextField("50 mg", text: Binding(
                    get: { heart.dailyDose ?? "" },
                    set: { v in update { $0.dailyDose = v.isEmpty ? nil : v } }))
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Your limit")
        } footer: {
            Text("Your own limit always wins over the estimate. Medication notes stay on this phone.")
        }
    }

    // MARK: Heart rate from

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
            toggle("Pause when no heart rate", \.alertNoMotion)
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
            toggle("Above my limit", \.alertAboveLimit)
            toggle("Below low limit", \.alertBelowLow)
            HStack {
                Text("Low limit")
                Spacer()
                TextField("Off", text: Binding(get: { heart.lowLimit.map(String.init) ?? "" },
                                               set: { v in update { $0.lowLimit = Int(v) } }))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                Text("bpm").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Low heart rate limit in beats per minute")
            toggle("Sudden jump (+40 bpm in 10 s)", \.alertSuddenJump)
            toggle("Signal lost", \.alertSignalLost)
            HStack {
                Text("On watch (haptic) + iPhone")
                Spacer()
                Text("Both").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
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
