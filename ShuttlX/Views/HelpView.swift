import SwiftUI
import ShuttlXShared

// MARK: - Help Content Model

/// One numbered "press this" instruction inside a help topic. The icon is the
/// actual on-screen control the user should look for.
struct HelpStep: Hashable {
    let icon: String
    let text: String
}

/// One help topic. Content lives here as data rather than inline in the view,
/// so copy changes review as diffs and a test can assert coverage.
struct HelpTopic: Identifiable {
    let id: String
    let icon: String
    let title: String
    let body: String
    var steps: [HelpStep] = []
}

enum HelpContent {
    /// The four built-in training programs, surfaced straight from
    /// `BuiltInPlans` so the help copy can never drift from the real data.
    private static var builtInProgramLines: String {
        BuiltInPlans.all
            .map { "• \($0.name) — \($0.planDescription)" }
            .joined(separator: "\n")
    }

    static let topics: [HelpTopic] = [
        HelpTopic(
            id: "watch-workout",
            icon: "applewatch",
            title: "Start an interval workout on Apple Watch",
            body: """
            The Watch runs the workout: it tracks heart rate, pace, distance, \
            and calories, taps your wrist when an interval changes, and sends \
            the finished session to your iPhone automatically.
            """,
            steps: [
                HelpStep(icon: "applewatch.watchface",
                         text: "Open ShuttlX on your Apple Watch. Your interval programs sync from the iPhone automatically."),
                HelpStep(icon: "hand.tap",
                         text: "Tap an interval program card to start it, or tap “Free Run” for an open-ended session."),
                HelpStep(icon: "chevron.left.chevron.right",
                         text: "During the workout, swipe between pages to see the timer, live metrics, and controls."),
                HelpStep(icon: "pause.circle.fill",
                         text: "Tap the green pause button to pause; tap the red stop button to finish."),
                HelpStep(icon: "iphone.and.arrow.right.inward",
                         text: "The completed session appears on your iPhone in the History tab within moments."),
            ]),
        HelpTopic(
            id: "custom-template",
            icon: "timer",
            title: "Build a custom program on iPhone",
            body: """
            A program is a sequence of work and rest intervals — warm-up, \
            repeating steps, and cool-down. Programs you build sync to the \
            Watch so you can start them from your wrist.
            """,
            steps: [
                HelpStep(icon: "calendar.badge.clock",
                         text: "Open the Programs tab and tap “Interval Workouts”."),
                HelpStep(icon: "plus",
                         text: "Tap the + button in the top-right corner to create a new program."),
                HelpStep(icon: "character.cursor.ibeam",
                         text: "Pick the sport, type a program name, and set the warm-up duration."),
                HelpStep(icon: "slider.horizontal.3",
                         text: "Add work and rest steps, set each duration, and use “Repeat” to loop the sequence."),
                HelpStep(icon: "checkmark",
                         text: "Tap “Save”. The program appears under Interval Programs and syncs to your Watch."),
                HelpStep(icon: "play.circle.fill",
                         text: "Start it any time by tapping its row in the Programs tab — on iPhone or Watch."),
            ]),
        HelpTopic(
            id: "built-in-programs",
            icon: "figure.run",
            title: "The four built-in programs",
            body: """
            ShuttlX ships with four ready-made training plans — no setup needed:

            \(builtInProgramLines)
            """,
            steps: [
                HelpStep(icon: "calendar.badge.clock",
                         text: "Open the Programs tab and tap “Training Plans”."),
                HelpStep(icon: "hand.tap",
                         text: "Tap a plan to see its week-by-week schedule."),
                HelpStep(icon: "play.fill",
                         text: "Tap “Start Plan” to begin tracking your progress through it."),
                HelpStep(icon: "circle",
                         text: "After each workout, tap the circle next to that day to mark it complete."),
            ]),
        HelpTopic(
            id: "history-analytics",
            icon: "chart.line.uptrend.xyaxis",
            title: "History & analytics",
            body: """
            Every finished session is stored with its intervals, heart rate, \
            route, and splits. Analytics turns that history into trends: \
            training load, weekly volume, estimated VO2max, pace zones, and \
            personal records.
            """,
            steps: [
                HelpStep(icon: "calendar",
                         text: "Open the History tab and use the Week / Month picker to browse past sessions."),
                HelpStep(icon: "hand.tap",
                         text: "Tap a session row for the full detail — intervals, heart rate chart, route map, and splits."),
                HelpStep(icon: "chart.line.uptrend.xyaxis",
                         text: "Open the Analytics tab for Recovery Status, Training Load Trend, Weekly Volume, and Personal Records."),
                HelpStep(icon: "arrow.triangle.2.circlepath",
                         text: "Missing a Watch workout? In Settings, tap “Sync from Watch” to pull it over."),
            ]),
        HelpTopic(
            id: "themes",
            icon: "paintbrush",
            title: "Themes: Clean & Mixtape",
            body: """
            ShuttlX has two looks. Clean is the calm, minimal default — glass \
            cards and system type. Mixtape turns your workout into a \
            Walkman-style cassette deck, spinning reels included. Your choice \
            syncs to the Watch automatically.
            """,
            steps: [
                HelpStep(icon: "gear",
                         text: "Open the Settings tab and scroll to the Appearance section."),
                HelpStep(icon: "hand.tap",
                         text: "Tap “Clean” or “Mixtape” — the whole app restyles instantly, and the swatch row previews the palette."),
                HelpStep(icon: "applewatch",
                         text: "The Watch picks up the new theme on its own; no steps needed there."),
            ]),
        HelpTopic(
            id: "widgets",
            icon: "square.grid.2x2",
            title: "Widgets & complications",
            body: """
            Start workouts without opening the app: Home Screen widgets and \
            Control Center controls on iPhone, complications on the Watch \
            face. The weekly goal ring keeps your progress in sight.
            """,
            steps: [
                HelpStep(icon: "hand.tap",
                         text: "On iPhone: long-press an empty spot on the Home Screen, tap Edit → “Add Widget”, and search for ShuttlX."),
                HelpStep(icon: "square.grid.2x2",
                         text: "Pick “Start Training” (choose which program it launches), or the Weekly Goal ring."),
                HelpStep(icon: "switch.2",
                         text: "In Control Center: tap +, then “Add a Control”, and add the ShuttlX Quick Start control."),
                HelpStep(icon: "applewatch.watchface",
                         text: "On the Watch: long-press the watch face, tap a complication slot, and pick ShuttlX — Quick Start, Last Workout, Today, or Weekly Progress."),
                HelpStep(icon: "play.circle.fill",
                         text: "Tapping a Start widget or complication launches the workout on your Watch right away."),
            ]),
        HelpTopic(
            id: "privacy",
            icon: "lock",
            title: "Privacy & your health data",
            body: """
            Your workouts are yours. Sessions are stored on your devices and, \
            only if you sign in, in your own iCloud. Heart rate, distance, and \
            calories are read from HealthKit solely to run and record your \
            workouts, and finished sessions are saved back to Apple Health. \
            Health data is never sent to third parties; the optional \
            analytics are anonymous and contain no health information.
            """,
            steps: [
                HelpStep(icon: "heart.fill",
                         text: "Manage access any time: Settings tab → Health Integration → “Why We Need Access”."),
                HelpStep(icon: "trash",
                         text: "Delete everything locally with “Clear All Training Sessions” in Settings → Data Management."),
            ]),
    ]
}

// MARK: - Help View

struct HelpView: View {
    @Environment(ThemeManager.self) var themeManager
    @State private var expanded: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(HelpContent.topics) { topic in
                    card(topic)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .themedScreenBackground()
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func card(_ topic: HelpTopic) -> some View {
        let isOpen = expanded == topic.id
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { expanded = isOpen ? nil : topic.id }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .foregroundStyle(ShuttlXColor.ctaPrimary)
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    Text(topic.title)
                        .font(ShuttlXFont.cardTitle)
                        .foregroundStyle(ShuttlXColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(ShuttlXFont.cardCaption)
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(topic.title)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint(isOpen ? "Collapses this help topic" : "Expands this help topic")

            if isOpen {
                Text(topic.body)
                    .font(ShuttlXFont.cardSubtitle)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, topic.steps.isEmpty ? 16 : 10)

                if !topic.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(topic.steps.enumerated()), id: \.element) { index, step in
                            stepRow(number: index + 1, step: step)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .themedCard()
    }

    /// A numbered instruction with the on-screen control the user should press.
    private func stepRow(number: Int, step: HelpStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(ShuttlXFont.cardCaption.weight(.bold))
                .monospacedDigit()
                .frame(width: 18, height: 18)
                .background(ShuttlXColor.ctaPrimary.opacity(0.14), in: Circle())
                .foregroundStyle(ShuttlXColor.ctaPrimary)
                .accessibilityHidden(true)
            Image(systemName: step.icon)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.ctaPrimary)
                .frame(width: 24, height: 18)
                .accessibilityHidden(true)
            Text(step.text)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(step.text)")
    }
}

#Preview {
    NavigationStack {
        HelpView()
            .environment(ThemeManager.shared)
    }
}
