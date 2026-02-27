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
        .accessibilityElement(children: .contain)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.run")
                .font(.system(size: 72))
                .foregroundStyle(ShuttlXColor.running)
                .symbolEffect(.bounce, value: currentPage == 0)
                .accessibilityHidden(true)

            Text("Welcome to ShuttlX")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Auto-detect running and walking\nwith your Apple Watch")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
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
                .font(.system(size: 72))
                .foregroundStyle(ShuttlXColor.heartRate)
                .symbolEffect(.bounce, value: currentPage == 1)
                .accessibilityHidden(true)

            Text("Health Integration")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Track heart rate, calories,\nand workout data")
                .font(.title3)
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
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityHint("Requests HealthKit permissions")

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Skip for Now")
                    .font(.subheadline)
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
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: currentPage == 2)
                .accessibilityHidden(true)

            Text("Pair Your Watch")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Start workouts on your Apple Watch.\nShuttlX syncs everything automatically.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Connectivity status
            HStack(spacing: 16) {
                WatchStatusRow(
                    icon: watchPaired ? "checkmark.circle.fill" : "xmark.circle",
                    label: watchPaired ? "Watch Paired" : "No Watch Paired",
                    isGood: watchPaired
                )
                WatchStatusRow(
                    icon: watchAppInstalled ? "checkmark.circle.fill" : "arrow.down.circle",
                    label: watchAppInstalled ? "App Installed" : "Install on Watch",
                    isGood: watchAppInstalled
                )
            }

            Spacer()

            Button {
                isFirstLaunch = false
            } label: {
                Text("Start Training")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 14))
            }
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
                .font(.caption)
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
                .foregroundStyle(isGood ? .green : .secondary)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isGood ? .primary : .secondary)
        }
    }
}

#Preview {
    OnboardingView(isFirstLaunch: .constant(true))
        .environmentObject(DataManager())
}
