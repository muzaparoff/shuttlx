import SwiftUI
import HealthKit
import ShuttlXShared

struct OnboardingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isFirstLaunch: Bool
    @State private var currentPage = 0
    @State private var heart = HeartSafetySettings.load()
    @State private var limitText = ""
    @State private var betaChoice: BetaChoice?
    @State private var limitChoice = LimitChoice.doctor
    @State private var medicineText = ""
    @State private var doseText = ""
    @FocusState private var limitFocused: Bool

    init(isFirstLaunch: Binding<Bool>) {
        _isFirstLaunch = isFirstLaunch
        let h = HeartSafetySettings.load()
        _heart = State(initialValue: h)
        _betaChoice = State(initialValue: h.onBetaBlocker.map { $0 ? .yes : .no })
        _medicineText = State(initialValue: h.medicineName ?? "")
        _doseText = State(initialValue: h.dailyDose ?? "")
        _limitText = State(initialValue: h.upperLimit.map(String.init) ?? "")
        _limitChoice = State(initialValue: h.effortOnly ? .effortOnly : .doctor)
        #if DEBUG
        // Screenshot seam: SHUTTLX_ONBOARDING_STEP=2|3 opens that step directly.
        if let raw = ProcessInfo.processInfo.environment["SHUTTLX_ONBOARDING_STEP"], let step = Int(raw) {
            _currentPage = State(initialValue: step <= 1 ? 0 : min(step, 3))
        }
        #endif
    }

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                healthPage.tag(1)
                medicationPage.tag(2)
                limitPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .timelineScreenBackground()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(ShuttlXFont.onboardingIcon)
                .foregroundStyle(ShuttlXColor.walking)
                .symbolEffect(.bounce, value: currentPage == 0)
                .accessibilityHidden(true)

            Text("Welcome to ShuttlX")
                .font(ShuttlXFont.metricLarge)
                .accessibilityAddTraits(.isHeader)

            Text("Move at your own pace,\nguided by your heart rate")
                .font(ShuttlXFont.sectionHeader)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
            }
            .buttonStyle(ShuttlXPrimaryCTAStyle())
            .accessibilityHint("Proceed to health integration setup")

            Spacer().frame(height: 40)
        }
        .padding()
    }

    // MARK: - Page 2: HealthKit

    private var healthPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(ShuttlXFont.onboardingIcon)
                .foregroundStyle(ShuttlXColor.heartRate)
                .symbolEffect(.bounce, value: currentPage == 1)
                .accessibilityHidden(true)

            Text("Health Integration")
                .font(ShuttlXFont.metricLarge)
                .accessibilityAddTraits(.isHeader)

            Text("Track heart rate, calories,\nand workout data")
                .font(ShuttlXFont.sectionHeader)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                OnboardingMetric(icon: "heart.circle", label: "Heart Rate", color: ShuttlXColor.heartRate)
                OnboardingMetric(icon: "flame.circle", label: "Calories", color: ShuttlXColor.calories)
                OnboardingMetric(icon: "location.circle", label: "Route", color: ShuttlXColor.running)
            }

            Spacer()

            Button {
                Task {
                    await dataManager.requestHealthKitPermissions()
                    withAnimation { currentPage = 2 }
                }
            } label: {
                Text("Grant Health Access")
            }
            .buttonStyle(ShuttlXPrimaryCTAStyle())
            .accessibilityHint("Requests HealthKit permissions")

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Skip for Now")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHint("Skip health access. Enable later in Settings.")

            Spacer().frame(height: 40)
        }
        .padding()
    }

    // MARK: - Step 2 of 3: Beta-blocker

    private var medicationPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Step 2 of 3").font(ShuttlXFont.cardSubtitle).foregroundStyle(.secondary)
                Spacer()
                Button("Skip") { withAnimation { currentPage = 3 } }
                    .font(ShuttlXFont.cardSubtitle)
                    .accessibilityHint("Skip. You can answer later in Settings.")
            }
            .padding(.horizontal, 20)

            Text("Do you take a beta-blocker?")
                .font(ShuttlXFont.metricMedium)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)

            Text("Medicines like metoprolol or bisoprolol keep your heart rate lower. We then set your limit differently.")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            List {
                // "Not sure" is stored as Yes (safe side).
                ForEach(BetaChoice.allCases, id: \.self) { choice in
                    Button {
                        betaChoice = choice
                    } label: {
                        HStack {
                            Text(choice.title)
                                .fontWeight(betaChoice == choice ? .semibold : .regular)
                                .foregroundStyle(ShuttlXColor.textPrimary)
                            Spacer()
                            if betaChoice == choice {
                                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(betaChoice == choice ? .isSelected : [])
                }

                Section {
                    HStack {
                        Text("Medicine")
                        Spacer()
                        TextField("Metoprolol", text: $medicineText).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Daily dose")
                        Spacer()
                        TextField("50 mg", text: $doseText).multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Optional · stays on this phone")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Text("Not medical advice. Your doctor knows your safe limit best.")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            Button {
                saveMedication()
                withAnimation { currentPage = 3 }
            } label: {
                Text("Continue")
            }
            .buttonStyle(ShuttlXPrimaryCTAStyle(maxWidth: .infinity))
            .padding(.horizontal, 16)

            Spacer().frame(height: 40)
        }
        .padding(.top, 8)
    }

    private func saveMedication() {
        switch betaChoice {
        case .no: heart.onBetaBlocker = false
        case .yes, .notSure: heart.onBetaBlocker = true
        case .none: break
        }
        heart.medicineName = medicineText.isEmpty ? nil : medicineText
        heart.dailyDose = doseText.isEmpty ? nil : doseText
        heart.save()
    }

    // MARK: - Step 3 of 3: Heart limit

    private var limitPage: some View {
        let age = DeviceManager.shared.userAge
        let estimate = heart.estimatedUpperLimit(age: age)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Step 3 of 3")
                .font(ShuttlXFont.cardSubtitle).foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            Text("Your heart limit")
                .font(ShuttlXFont.metricMedium)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)

            Text("The watch warns you when you reach it.")
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            List {
                limitRow(.doctor, title: "My doctor gave me a limit") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("125", text: $limitText)
                            .keyboardType(.numberPad)
                            .focused($limitFocused)
                            .font(ShuttlXFont.metricLarge.monospacedDigit())
                            .fixedSize()
                            .accessibilityLabel("Heart rate limit in beats per minute")
                        Text("bpm").font(ShuttlXFont.cardSubtitle).foregroundStyle(.secondary)
                    }
                }
                limitRow(.estimate, title: "Estimate it for me") {
                    if let estimate {
                        Text("≈ \(estimate) bpm max for age \(age ?? 0)\(heart.onBetaBlocker == true ? " on a beta-blocker" : ""). An estimate, not a prescription.")
                            .font(ShuttlXFont.cardSubtitle).foregroundStyle(.secondary)
                    }
                }
                limitRow(.effortOnly, title: "Use effort only") {
                    Text("0–10 scale, no heart-rate limit.")
                        .font(ShuttlXFont.cardSubtitle).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            Text("Effort 0–10 is always on with a beta-blocker. Heart rate and effort are used together.")
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            Button {
                heart.effortOnly = limitChoice == .effortOnly
                heart.upperLimit = limitChoice == .doctor ? Int(limitText) : nil
                heart.save()
                PhoneSyncCoordinator.shared.sendHeartSafetyToWatch(heart, age: age)
                isFirstLaunch = false
            } label: {
                Text("Done")
            }
            .buttonStyle(ShuttlXPrimaryCTAStyle(maxWidth: .infinity))
            .padding(.horizontal, 16)
            .accessibilityHint("Completes onboarding and opens the app")

            Spacer().frame(height: 40)
        }
        .padding(.top, 8)
        .onChange(of: limitFocused) { _, focused in if focused { limitChoice = .doctor } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { limitFocused = false }
            }
        }
    }

    private func limitRow<Detail: View>(_ choice: LimitChoice, title: String,
                                        @ViewBuilder detail: () -> Detail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).fontWeight(.semibold)
                Spacer()
                if limitChoice == choice {
                    Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            detail()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { limitChoice = choice }
        .accessibilityElement(children: choice == .doctor ? .contain : .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(limitChoice == choice ? .isSelected : [])
    }
}

private enum BetaChoice: CaseIterable {
    case no, yes, notSure
    var title: String { self == .no ? "No" : self == .yes ? "Yes" : "Not sure" }
}

private enum LimitChoice { case doctor, estimate, effortOnly }

// MARK: - Sub-components

private struct OnboardingMetric: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(label)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) tracking")
    }
}

#Preview {
    OnboardingView(isFirstLaunch: .constant(true))
        .environmentObject(DataManager())
}
