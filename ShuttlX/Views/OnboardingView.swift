import SwiftUI
import HealthKit
import WatchConnectivity

struct OnboardingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isFirstLaunch: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                healthPage.tag(1)
                watchPage.tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .themedScreenBackground()
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

    // MARK: - Page 3: Watch Pairing

    private var watchPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "applewatch")
                .font(ShuttlXFont.onboardingIcon)
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: currentPage == 2)
                .accessibilityHidden(true)

            Text("Apple Watch")
                .font(ShuttlXFont.metricLarge)
                .accessibilityAddTraits(.isHeader)

            if watchPaired && watchAppInstalled {
                Text("Your watch is paired and ready.\nWorkouts start on your wrist and sync automatically.")
                    .font(ShuttlXFont.sectionHeader)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    WatchStatusRow(icon: "checkmark.circle.fill", label: "Watch Paired", isGood: true)
                    WatchStatusRow(icon: "checkmark.circle.fill", label: "App Installed", isGood: true)
                }
            } else {
                Text("No Apple Watch paired — that's fine.\nYou can review your sessions and settings on iPhone.")
                    .font(ShuttlXFont.sectionHeader)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("To start workouts, open ShuttlX on your Apple Watch.")
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                isFirstLaunch = false
            } label: {
                Text("Begin")
            }
            .buttonStyle(ShuttlXPrimaryCTAStyle())
            .accessibilityHint("Completes onboarding and opens the app")

            Spacer().frame(height: 40)
        }
        .padding()
    }

    // MARK: - Watch Status

    private var watchPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    private var watchAppInstalled: Bool {
        WCSession.isSupported() && WCSession.default.isWatchAppInstalled
    }
}

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

private struct WatchStatusRow: View {
    let icon: String
    let label: String
    let isGood: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(isGood ? ShuttlXColor.positive : .secondary)
            Text(label)
                .font(ShuttlXFont.cardSubtitle)
                .foregroundStyle(isGood ? .primary : .secondary)
        }
    }
}

#Preview {
    OnboardingView(isFirstLaunch: .constant(true))
        .environmentObject(DataManager())
}
