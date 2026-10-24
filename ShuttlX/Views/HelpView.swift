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
            id: "simple-mode",
            icon: "textformat.size",
            title: "Simple mode",
            body: """
            Simple mode shows fewer cards and bigger numbers. Today has one \
            big Start button and three tiles: time, distance and heart. It \
            only hides screens; nothing is deleted, and your heart limit and \
            alerts are always on. Turn it off to see everything again.
            """,
            steps: [
                HelpStep(icon: "switch.2",
                         text: "Open Settings and turn on “Simple mode” (the first row)."),
                HelpStep(icon: "play.fill",
                         text: "On Today, tap “Start on Apple Watch” and confirm. Tap “Other workouts” for programs and plans."),
                HelpStep(icon: "calendar",
                         text: "History keeps Calendar and List. The Map view and the “Fix a part” prompt on Today are hidden until you turn Simple mode off.")
            ]
        ),
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
                         text: "Tap an interval program card to start it, or tap “Run/Walk” for an open-ended session that finds Run and Walk itself."),
                HelpStep(icon: "chevron.left.chevron.right",
                         text: "During the workout, swipe between pages to see the timer, live metrics, and controls."),
                HelpStep(icon: "pause.circle.fill",
                         text: "Tap the green pause button to pause; tap the red stop button to finish."),
                HelpStep(icon: "iphone.and.arrow.right.inward",
                         text: "The completed session appears on your iPhone in the History tab within moments."),
                HelpStep(icon: "iphone",
                         text: "If you start a workout on the iPhone, the Watch starts too. Pause, resume and End & Save on the iPhone reach the Watch (Discard is in the … menu at the top of the timer), and the Watch recording is the one kept in History. If the Watch recording never arrives, the iPhone recording stays."),
                HelpStep(icon: "location",
                         text: "Outdoor workouts started on the iPhone keep tracking your route when the screen is off. The iPhone shows a blue location indicator while it does."),
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
                         text: "On the Today tab, tap “Programs & plans”, then “Interval Workouts”."),
                HelpStep(icon: "plus",
                         text: "Tap the + button in the top-right corner to create a new program."),
                HelpStep(icon: "character.cursor.ibeam",
                         text: "Pick the sport, type a program name, and set the warm-up duration."),
                HelpStep(icon: "slider.horizontal.3",
                         text: "Add work and rest steps, set each duration, and use “Repeat” to loop the sequence."),
                HelpStep(icon: "checkmark",
                         text: "Tap “Save”. The program appears under Interval Programs and syncs to your Watch."),
                HelpStep(icon: "play.circle.fill",
                         text: "Start it any time by tapping its row under Today → Programs & plans — on iPhone or Watch."),
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
                         text: "On the Today tab, tap “Programs & plans”, then “Training Plans”."),
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
            route, and splits. Trends turns that history into trends: \
            training load, weekly volume, cardio fitness (VO2max from Apple Health, \
            or an estimate from your runs when Health has none), pace zones, and \
            personal records.
            """,
            steps: [
                HelpStep(icon: "calendar",
                         text: "Open the History tab and switch between Calendar, List and Map to browse past sessions. Map shows the routes of the selected month and groups repeated routes."),
                HelpStep(icon: "hand.tap",
                         text: "Tap a session row for the full detail — intervals, route map and splits, and a heart rate chart with your limit as a dashed line. With a limit set it says how much of the time you stayed under it (an estimate from Apple Health readings)."),
                HelpStep(icon: "chart.line.uptrend.xyaxis",
                         text: "Open the Trends tab for your active minutes this week, month or year and how they compare with the period before. Recovery, fitness, fatigue and VO2max sit behind “Show athlete metrics” at the bottom (off by default, hidden in Simple mode)."),
                HelpStep(icon: "arrow.triangle.2.circlepath",
                         text: "Missing a Watch workout? Open ShuttlX on the Watch; unsent workouts sync to the iPhone automatically."),
            ]),
        HelpTopic(
            id: "heart-limits",
            icon: "heart.text.square",
            title: "Heart limits & alerts",
            body: """
            Set an upper limit (and optionally a low limit) for your heart \
            rate. Without one, ShuttlX can estimate it from your age: 85% of \
            the predicted maximum (220 minus your age), lowered further if you \
            take a beta-blocker. It is an estimate, not a prescription. Your \
            doctor's limit always wins. Your medication answer stays on this iPhone; only the \
            resulting limits are sent to your Watch. You can also choose \
            "Use effort only": a 0–10 effort scale and no heart-rate limit.
            """,
            steps: [
                HelpStep(icon: "gear",
                         text: "During setup, answer the beta-blocker question (you can skip it) and choose your heart limit: your doctor's number, an estimate from your age (the default), or effort only. Setup has four steps, one at a time, and the last button offers to start your first walk on the Apple Watch. Setup asks for your age if Health does not know it, and asks once to allow notifications."),
                HelpStep(icon: "heart.fill",
                         text: "Later: Settings → Heart → Heart limit opens Heart & alerts, where you change your limit, age, low limit and medication notes. Numbers are saved when you finish typing; one outside the allowed range is moved to the nearest allowed value and you are told. The low limit always stays at least 10 bpm below the upper limit, an estimated one included: if a new age lowers the estimate, the low limit is moved and you are told. Max heart rate is Auto unless you type your own; Reset returns to Auto."),
                HelpStep(icon: "exclamationmark.triangle",
                         text: "If no limit is set and effort only is off, Today and Settings show “No heart limit set”: the watch cannot warn you until you set one."),
                HelpStep(icon: "bell.badge",
                         text: "Choose which alerts you want: above limit, below low limit, signal lost, and the sudden rise alert (+40 bpm in 10 s, off by default because it can false alarm). Pause when no heart rate has its own switch and delay (30, 60 or 120 s)."),
                HelpStep(icon: "applewatch",
                         text: "Settings → Workout sets Distance units (Auto follows your region, Kilometres or Miles; the watch follows too) and Split alerts, the wrist tap at each kilometre or mile in Run/Walk."),
                HelpStep(icon: "heart.text.square",
                         text: "Settings → Heart also switches the 0–10 effort question and Run / Walk auto-switch on the watch. Effort stays on with a beta-blocker."),
            ]),
        HelpTopic(
            id: "fix-a-part",
            icon: "slider.horizontal.below.rectangle",
            title: "Fix a part of a workout",
            body: """
            ShuttlX cuts a workout into Run, Walk, Cycle and Rest parts by \
            itself. If it got one wrong, correct it. Your change is stored \
            beside the workout; the original and the Health workout are not \
            touched. A part you set to Rest burns no calories.
            """,
            steps: [
                HelpStep(icon: "hand.tap",
                         text: "Open a workout and tap a part, or tap “Fix a part” on Today (not shown in Simple mode, where parts are not tappable)."),
                HelpStep(icon: "circle.grid.2x2",
                         text: "Pick Run, Walk, Cycle or Rest, then Save."),
                HelpStep(icon: "scissors",
                         text: "To cut a part in two, drag the handle on the bar to where it changes and tap Split."),
                HelpStep(icon: "arrow.triangle.merge",
                         text: "Tap “Merge with next” to join a part with the one after it."),
                HelpStep(icon: "arrow.uturn.backward",
                         text: "Tap “Reset to detected” (and confirm) to remove all your corrections to that workout. It is off when the workout has none."),
                HelpStep(icon: "heart.fill",
                         text: "The heart-rate line under the bar comes from Apple Health. It is hidden when Health has no heart-rate data for the workout."),
            ]),
        HelpTopic(
            id: "widgets",
            icon: "square.grid.2x2",
            title: "Widgets & complications",
            body: """
            Start workouts in one tap: Home Screen widgets and \
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
                         text: "Tapping a Start widget on iPhone opens ShuttlX and asks you to confirm before the workout starts on your Watch. A Watch complication starts it right away."),
            ]),
        HelpTopic(
            id: "privacy",
            icon: "lock",
            title: "Privacy & your health data",
            body: """
            Your workouts are yours. Sessions are stored on your iPhone and \
            Apple Watch. iCloud backup is not available in this version. If you \
            signed in with Apple in an earlier version, your workouts are still \
            synced to your private iCloud and Settings → Account lets you sign \
            out or delete your account and iCloud data. Heart rate, distance, and \
            calories are read from HealthKit solely to run and record your \
            workouts, and finished sessions are saved back to Apple Health. \
            Health data is never sent to third parties; the optional \
            analytics are anonymous and contain no health information.
            """,
            steps: [
                HelpStep(icon: "heart.fill",
                         text: "Manage access any time: Settings tab → Health & Watch → “Why We Need Access”. If Health access was switched off, Settings shows how to turn it back on in iPhone Settings."),
                HelpStep(icon: "heart.text.square",
                         text: "If a Watch workout never synced to the iPhone, ShuttlX reads it back from Apple Health when you open the app. It shows a “From Health” badge in History."),
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
                withAnimation(.ifAllowed(.snappy)) { expanded = isOpen ? nil : topic.id }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .foregroundStyle(ShuttlXColor.accentText)
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
                .foregroundStyle(ShuttlXColor.accentText)
                .accessibilityHidden(true)
            Image(systemName: step.icon)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.accentText)
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
