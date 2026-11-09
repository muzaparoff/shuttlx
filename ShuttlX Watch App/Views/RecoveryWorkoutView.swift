import SwiftUI
#if os(watchOS)
import WatchKit
import ShuttlXShared
#endif

/// Gym recovery main page. The state tag (READY / SET N / REST m:ss) sits on the
/// system-clock line like the free-run activity tag, BPM is the hero with the
/// EASY / STEADY / HARD word next to it, and one contextual button drives the flow:
///
///   - `.idle` / `.rest` -> "Start Set" (green ctaPrimary)
///   - `.work`           -> "End Set"   (red ctaDestructive)
///
/// The heart cues come from the `WorkoutPage` helpers so every mode uses one heart
/// reference (`resolvedHeartLimit`): the zone word, and the "Ease off" or no-HR banner.
/// At 90 % of the limit `WorkoutMainPage` shows `HeartLimitPage` instead, with `GymSetButton`
/// at the bottom. Sizes are mockup px via `WatchScale`, solved, never scaled.
struct RecoveryWorkoutView: View, WorkoutPage {
    @Environment(WatchWorkoutManager.self) var workoutManager
    let hrCalculator: HeartRateZoneCalculator
    /// Same pinning as the free-run pages: the page ends at the screen bottom.
    let pageHeight: CGFloat?

    var body: some View {
        let hr = workoutManager.heartRate
        // EASY / STEADY / HARD and its colour; nil without HR or without a limit.
        let zone = heartZoneWord.map { (word: $0, color: zoneWordColor($0)) }
        // A banner is showing: the rest badges step aside to pay for it on 40mm.
        let bannerShown = isHighIntensityWarning || workoutManager.noHeartRateDetected
        let zoneSize = WatchScale.pt(16)
        // Side column is as wide as its longest word ("STEADY", heavy ~0.7em).
        let sideWidth = zoneSize * 0.7 * 6
        let gap = WatchScale.pt(6)
        // Three tabular digits (0.62em upper bound) must fit next to the side column.
        let hrSize = min(WatchScale.pt(52), (WatchScale.width - 16 - sideWidth - gap) / (3 * 0.62))
        #if DEBUG
        let _ = BodyCounter.hit("RecoveryWorkoutView")
        let _ = BodyCounter.enabled ? Self._printChanges() : ()
        #endif

        return VStack(alignment: .leading, spacing: 0) {
            GymStateTag()

            WorkoutClockReader(clock: workoutManager.clock) { elapsed in
                Text(FormattingUtils.formatTimer(elapsed))
                    .font(.system(size: WatchScale.pt(16), weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .fixedSize()
                    .accessibilityLabel("Elapsed time \(FormattingUtils.formatTimer(elapsed))")
            }
            .padding(.top, WatchScale.pt(2))

            // HR hero; the colour is the HR colour, the word carries the zone.
            HStack(alignment: .center, spacing: gap) {
                Text(hr > 0 ? "\(hr)" : "\u{2014}")
                    .font(.system(size: hrSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(hr > 0 ? ShuttlXColor.heartRate : ShuttlXColor.textSecondary)
                    .contentTransition(.numericText())
                    .fixedSize()
                VStack(alignment: .leading, spacing: 0) {
                    Text("BPM")
                        .font(.system(size: WatchScale.text(11), weight: .bold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .fixedSize()
                    if let zone {
                        Text(zone.word)
                            .font(.system(size: zoneSize, weight: .heavy))
                            .foregroundStyle(zone.color)
                            .fixedSize()
                    }
                }
            }
            .padding(.top, WatchScale.pt(2))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(hr > 0
                                ? "Heart rate \(hr) beats per minute" + (zone.map { ", effort \($0.word.lowercased())" } ?? "")
                                : "Heart rate no data")
            .accessibilityAddTraits(.updatesFrequently)

            if workoutManager.recoveryState == .rest && !bannerShown {
                WorkoutClockReader(clock: workoutManager.clock) { _ in
                    let rest = restElapsed
                    HStack(spacing: 6) {
                        milestoneBadge(label: "1:00", reached: rest >= 60, value: workoutManager.latestHRR1)
                        milestoneBadge(label: "2:00", reached: rest >= 120, value: workoutManager.latestHRR2)
                    }
                }
                .padding(.top, WatchScale.pt(4))
            }

            Spacer(minLength: 0)

            gymSafetyBanner
                .padding(.bottom, bannerShown ? 4 : 0)

            GymSetButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        // Keep the button clear of the TabView page dots.
        .padding(.bottom, max(10, WatchScale.height * 0.055))
        .frame(height: pageHeight)
    }

    /// Wall-clock rest time, read inside a 1 Hz `WorkoutClockReader` so only these
    /// subtrees re-render each second (the manager publishes `restStartTime` once per rest).
    private var restElapsed: TimeInterval {
        workoutManager.restStartTime.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func milestoneBadge(label: String, reached: Bool, value: Int?) -> some View {
        let size = WatchScale.text(10)
        return HStack(spacing: 2) {
            Text(label)
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
            if reached, let v = value {
                Text("-\(v)")
                    .font(.system(size: size, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(ShuttlXColor.ctaPrimary)
            }
        }
        .fixedSize()
        .foregroundColor(reached ? ShuttlXColor.textPrimary : ShuttlXColor.textSecondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4)
            .fill(reached ? ShuttlXColor.positive.opacity(0.25) : ShuttlXColor.surface))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(reached ? ShuttlXColor.positive.opacity(0.6) : ShuttlXColor.surfaceBorder, lineWidth: 1))
        .accessibilityLabel(reached
                            ? (value.map { "\(label) mark: \($0) BPM drop" } ?? "\(label) reached")
                            : "\(label) mark not yet reached")
    }
}

/// `● READY` / `● SET 2` / `● REST 00:48`, or `⏸︎ PAUSED`, in the free-run tag style.
/// Short enough to share the top line with the system clock on 40mm.
struct GymStateTag: View {
    @Environment(WatchWorkoutManager.self) var workoutManager

    var body: some View {
        if workoutManager.isPaused {
            tag("\u{23F8}\u{FE0E} PAUSED", ShuttlXColor.ctaWarning, a11y: "Paused")
        } else {
            switch workoutManager.recoveryState {
            case .idle:
                tag("\u{25CF} READY", ShuttlXColor.textSecondary, a11y: "Ready")
            case .work:
                tag("\u{25CF} SET \(workoutManager.recoverySetNumber)", ShuttlXColor.ctaPrimary,
                    a11y: "Set \(workoutManager.recoverySetNumber)")
            case .rest:
                // The rest clock feeds the 1:00 / 2:00 marks; only this tag re-renders per second.
                WorkoutClockReader(clock: workoutManager.clock) { _ in
                    let rest = workoutManager.restStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    tag("\u{25CF} REST \(FormattingUtils.formatTimer(rest))", ShuttlXColor.ctaWarning,
                        a11y: "Rest \(FormattingUtils.formatTimer(rest))")
                }
            }
        }
    }

    private func tag(_ text: String, _ color: Color, a11y: String) -> some View {
        let size = WatchScale.text(11)
        return Text(text)
            .font(.system(size: size, weight: .bold))
            .tracking(size * 0.08)
            .monospacedDigit()
            .foregroundStyle(color)
            .fixedSize()
            .accessibilityLabel(a11y)
    }
}

/// The one gym control: green "Start Set" (ready / rest), red "End Set" (set).
/// No haptic here: the set event in `WatchWorkoutManager.processRecoveryEvents`
/// plays it (`.click` on start, `.stop` on end), so a tap buzzes once.
struct GymSetButton: View {
    @Environment(WatchWorkoutManager.self) var workoutManager

    var body: some View {
        let working = workoutManager.recoveryState == .work
        let set = workoutManager.recoverySetNumber
        Button {
            if working {
                workoutManager.manualEndStation()
            } else {
                workoutManager.manualStartStation()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: working ? "stop.fill" : "play.fill")
                Text(working ? "End Set" : "Start Set")
                    .fixedSize()
            }
            .font(.system(size: WatchScale.pt(17), weight: .heavy))
            .foregroundStyle(ShuttlXColor.iconOnCTA)
            .frame(maxWidth: .infinity)
            .frame(height: max(44, WatchScale.pt(50)))
            .background(Capsule().fill(working ? ShuttlXColor.ctaDestructive : ShuttlXColor.ctaPrimary))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(working ? "End Set" : "Start Set")
        .accessibilityHint(working
                           ? "Ends set \(set) and starts a rest period"
                           : workoutManager.recoveryState == .rest
                               ? "Begins the next set and records this rest period"
                               : "Begins set 1 of your heart recovery workout")
    }
}
