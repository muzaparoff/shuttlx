import SwiftUI
import WatchKit
import ShuttlXShared

/// Workout pages: `RunningPage` (free-run Workout page: time, part timer, distance,
/// BPM + zone word), `HeartLimitPage` (takes over the Workout page at 90 % of the
/// limit, free run and gym) and `MorePage` (every mode). Each page is its own
/// struct so it re-renders only on what it reads (`@Observable` manager).
/// Sizes are mockup px via `WatchScale.pt` — solved, never scale-to-fit.
struct RunningPage: View, WorkoutPage {
    @Environment(WatchWorkoutManager.self) var workoutManager
    let hrCalculator: HeartRateZoneCalculator
    let pageHeight: CGFloat?

    /// Workout page (watch plan decisions 2 and 3): tag, total time (hero), the part
    /// timer under it ("RUN 4:12"), distance, then BPM with the zone word at the
    /// bottom. The switch or split toast takes the part row for 4 s; "Ease off" takes
    /// the distance row; the two-line no-HR banner takes both.
    var body: some View {
        #if DEBUG
        let _ = BodyCounter.hit("RunningPage")
        #endif
        let activity = workoutManager.currentActivity
        let paused = workoutManager.isPaused
        let tagColor = paused ? ShuttlXColor.ctaWarning
            : activity == .unknown ? ShuttlXColor.textSecondary : activity.themeColor
        let hr = workoutManager.heartRate
        let word = heartZoneWord
        let noHR = workoutManager.noHeartRateDetected
        let labelSize = max(10, screenHeight * 0.08)

        return VStack(alignment: .leading, spacing: 0) {
            // Paused: the word, not just the amber clock (colour alone is not a state).
            Text(paused ? "\u{23F8}\u{FE0E} PAUSED" : "\u{25CF} \(activity.watchTag)")
                .font(.system(size: WatchScale.text(11), weight: .bold))
                .tracking(WatchScale.text(11) * 0.08)
                .foregroundStyle(tagColor)
                .accessibilityLabel(paused ? "Paused" : activity == .unknown ? workoutManager.workoutName : activity.displayName)

            ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                             clock: workoutManager.clock,
                             baseSize: WatchScale.pt(44),
                             availableWidth: screenWidth - 16,
                             weight: .semibold,
                             color: paused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                .modifier(PausePulse(active: paused, low: 0.35))
                .padding(.top, WatchScale.pt(4))

            // The switch toast wins; a split toast waits behind it (WatchWorkoutManager).
            if let sw = workoutManager.activitySwitch {
                activitySwitchToast(sw).padding(.top, WatchScale.pt(6))
            } else if let split = workoutManager.splitToast {
                splitToastView(split).padding(.top, WatchScale.pt(6))
            } else if !noHR {
                partRow(activity: activity, paused: paused)
                    .padding(.top, WatchScale.pt(8))
            }

            Group {
                if isHighIntensityWarning {
                    highIntensityWarningView(labelSize: labelSize)
                } else if noHR {
                    noHeartRateBanner(labelSize: labelSize)
                } else {
                    unitNumber(compactDistanceValue, compactDistanceUnit, ShuttlXColor.textPrimary,
                               WatchScale.pt(24), WatchScale.text(11)) { EmptyView() }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Distance \(accessibleDistance)")
                }
            }
            .padding(.top, WatchScale.pt(6))

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(hr > 0 ? "\(hr)" : "\u{2014}")
                        .font(.system(size: WatchScale.pt(30), weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ShuttlXColor.heartRate)
                        .fixedSize()
                    Text("BPM")
                        .font(.system(size: WatchScale.text(11), weight: .bold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .fixedSize()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hr > 0 ? "Heart rate \(hr) beats per minute" : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 4)
                if let word {
                    Text(word)
                        .font(.system(size: WatchScale.pt(15), weight: .heavy))
                        .foregroundStyle(zoneWordColor(word))
                        .fixedSize()
                        .accessibilityLabel("Effort \(word.lowercased())")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        // Keep the last line clear of the TabView page dots.
        .padding(.bottom, max(10, screenHeight * 0.055))
        // The page TabView proposes no height, so the maxHeight frame above collapses
        // to the content and a short stack floated to the centre. Pinned to
        // `pageHeight`, BPM stays at the bottom whatever is shown.
        .frame(height: pageHeight)
    }

    /// "RUN 4:12": time in the open part, restarted on every run/walk switch and on
    /// resume. While paused: "PAUSED 0:42", how long the pause has lasted. Both are
    /// `Text(timerInterval:)`, advanced by the render server: no per-second state.
    @ViewBuilder
    private func partRow(activity: DetectedActivity, paused: Bool) -> some View {
        let start = paused ? workoutManager.pauseStartDate : workoutManager.currentSegmentStartTime
        if let start {
            let color = paused ? ShuttlXColor.ctaWarning
                : activity == .unknown ? ShuttlXColor.textSecondary : activity.themeColor
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(paused ? "PAUSED" : activity.watchTag)
                    .font(.system(size: WatchScale.text(11), weight: .bold))
                    .tracking(WatchScale.text(11) * 0.08)
                    .foregroundStyle(color)
                    .fixedSize()
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.system(size: WatchScale.pt(24), weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(paused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                    .fixedSize()
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Audit W3 / 3A: the activity or PAUSED tag stays, BPM is white up to the limit
    /// and amber above it, the pill warns "Near your limit" from 90 % and says
    /// "Ease off" only above the limit (the alert's threshold), and a small timer +
    /// the limit sit at the bottom.
    /// `gym`: the gym state tag replaces the activity tag and the set button replaces
/// the timer + limit row (both do not fit with the button on 40mm), so End Set /
/// Start Set stays one tap away.
struct HeartLimitPage: View, WorkoutPage {
    @Environment(WatchWorkoutManager.self) var workoutManager
    let hrCalculator: HeartRateZoneCalculator
    let pageHeight: CGFloat?
    let limit: Int
    var gym = false

    var body: some View {
        #if DEBUG
        let _ = BodyCounter.hit("HeartLimitPage")
        #endif
        let hr = workoutManager.heartRate
        let over = hr > limit
        let paused = workoutManager.isPaused
        let activity = workoutManager.currentActivity
        let pill = over ? TrainingView.easeOffText : "Near your limit"
        let pillSize = min(WatchScale.pt(13), (screenWidth - 16 - 2 * WatchScale.pt(12)) / (CGFloat(pill.count) * 0.62))
        let small = WatchScale.text(11)
        return VStack(alignment: .leading, spacing: 0) {
            if gym {
                GymStateTag()
            } else {
                Text(paused ? "\u{23F8}\u{FE0E} PAUSED" : "\u{25CF} \(activity.watchTag)")
                    .font(.system(size: small, weight: .bold))
                    .tracking(small * 0.08)
                    .foregroundStyle(paused ? ShuttlXColor.ctaWarning
                                     : activity == .unknown ? ShuttlXColor.textSecondary : activity.themeColor)
                    .accessibilityLabel(paused ? "Paused" : activity == .unknown ? workoutManager.workoutName : activity.displayName)
            }
            Text("\(hr)")
                .font(.system(size: WatchScale.pt(58), weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(over ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                .fixedSize()
                .padding(.top, WatchScale.pt(4))
                .accessibilityLabel("Heart rate \(hr), limit \(limit)")
                .accessibilityAddTraits(.updatesFrequently)
            WatchFillBar(fraction: Double(hr) / Double(limit),
                         fill: LinearGradient(colors: [ShuttlXColor.running, ShuttlXColor.ctaWarning],
                                              startPoint: .leading, endPoint: .trailing),
                         height: WatchScale.pt(9))
                .padding(.top, WatchScale.pt(6))
            Text(pill)
                .font(.system(size: pillSize, weight: .heavy))
                .foregroundStyle(over ? ShuttlXColor.iconOnCTA : ShuttlXColor.ctaWarning)
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, WatchScale.pt(6))
                .padding(.horizontal, WatchScale.pt(12))
                .background {
                    // Filled above the limit; outline only while near it (warn before error).
                    RoundedRectangle(cornerRadius: 12).fill(ShuttlXColor.ctaWarning.opacity(over ? 1 : 0))
                    RoundedRectangle(cornerRadius: 12).stroke(ShuttlXColor.ctaWarning, lineWidth: 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, WatchScale.pt(10))
                .accessibilityLabel(over ? "Ease off, heart rate above your limit of \(limit)" : "Near your limit of \(limit)")
            Spacer(minLength: 0)
            if gym {
                GymSetButton()
            } else {
                HStack(alignment: .firstTextBaseline) {
                    ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                                     clock: workoutManager.clock,
                                     baseSize: WatchScale.pt(16),
                                     availableWidth: (screenWidth - 16) * 0.55,
                                     weight: .semibold,
                                     color: paused ? ShuttlXColor.ctaWarning : ShuttlXColor.textSecondary)
                    Spacer(minLength: 4)
                    Text("LIMIT \(limit)")
                        .font(.system(size: small, weight: .bold))
                        .foregroundStyle(ShuttlXColor.textSecondary)
                        .fixedSize()
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, max(10, screenHeight * 0.055))
        .frame(height: pageHeight)
    }
}

extension WorkoutPage {
    /// Gym page banner: "Ease off" above the limit, else the no-HR banner, else nothing.
    @ViewBuilder
    var gymSafetyBanner: some View {
        let labelSize = max(10, screenHeight * 0.08)
        if isHighIntensityWarning {
            highIntensityWarningView(labelSize: labelSize)
        } else if workoutManager.noHeartRateDetected {
            noHeartRateBanner(labelSize: labelSize)
        }
    }

}

/// More page (right of the Workout page) in every mode. Rows in the run/walk order:
/// free run = pace (speed while cycling), last split, calories, BPM; intervals add
/// distance first and time after pace (they left the interval page, R7); gym = time,
/// calories, BPM. HR and the safety banner never leave the screen (watchos.md): while
/// a banner shows it takes the calories row.
struct MorePage: View, WorkoutPage {
    @Environment(WatchWorkoutManager.self) var workoutManager
    let hrCalculator: HeartRateZoneCalculator
    let pageHeight: CGFloat?

    var body: some View {
        #if DEBUG
        let _ = BodyCounter.hit("MorePage")
        #endif
        let h = screenHeight
        let rowWidth = screenWidth - 16
        let unitSize = max(11, h * 0.062)
        let mode = workoutManager.workoutMode
        let split = mode == .freeRun ? workoutManager.splitCounter(for: distanceUnit).lastSplit : nil
        let rows = mode == .interval ? 5 : mode == .gymRecovery ? 3 : (split == nil ? 3 : 4)
        // Five rows at 0.12h, four at 0.15h, three at 0.17h: the stack stays inside the page on 40mm.
        let cap = h * (rows == 5 ? 0.12 : rows == 4 ? 0.15 : 0.17)
        let hr = workoutManager.heartRate
        let hrText = hr > 0 ? "\(hr)" : "\u{2014}"
        let calText = workoutManager.calories > 0 ? "\(workoutManager.calories)" : "\u{2014}"
        let labelSize = max(10, h * 0.08)
        func size(_ value: String, _ unit: String) -> CGFloat {
            fittedMetricSize(glyphs: max(3, value.count), unit: unit, unitSize: unitSize,
                             accessoryWidth: 0, available: rowWidth, cap: cap)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            if mode == .interval {
                unitNumber(compactDistanceValue, compactDistanceUnit, ShuttlXColor.textPrimary,
                           size(compactDistanceValue, compactDistanceUnit), unitSize) { EmptyView() }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Distance \(accessibleDistance)")
                Spacer(minLength: 0)
            }
            if mode != .gymRecovery {
                if showsSpeed {
                    unitNumber(speedValueText, speedUnit, ShuttlXColor.cycling,
                               size(speedValueText, speedUnit), unitSize) { EmptyView() }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(speedValueText == "\u{2014}" ? "Speed no data"
                                            : "Speed \(speedValueText) \(distanceUnit == .mi ? "miles" : "kilometers") per hour")
                } else {
                    let paceUnit = distanceUnit.paceSuffix.uppercased()
                    unitNumber(paceValueText, paceUnit, ShuttlXColor.running,
                               size(paceValueText, paceUnit), unitSize) { EmptyView() }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessiblePace)
                }
                Spacer(minLength: 0)
            }
            if let split {
                let label = TrainingView.splitLabel(distanceUnit, split.number)
                let value = TrainingView.splitClock(split.splitTime)
                HStack(alignment: .firstTextBaseline, spacing: max(1, unitSize * 0.18)) {
                    Text(label)
                        .font(.system(size: unitSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(ShuttlXColor.textSecondary)
                        .fixedSize()
                    Text(value)
                        .font(.system(size: size(value, label), weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(ShuttlXColor.textPrimary)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last split, \(TrainingView.splitAccessible(distanceUnit, split))")
                Spacer(minLength: 0)
            }
            if mode != .freeRun {
                // Total time: the Workout page of these modes shows the step or set clock.
                ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                                 clock: workoutManager.clock,
                                 baseSize: cap,
                                 availableWidth: rowWidth,
                                 color: workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                Spacer(minLength: 0)
            }
            if isHighIntensityWarning {
                highIntensityWarningView(labelSize: labelSize)
            } else if workoutManager.noHeartRateDetected {
                noHeartRateBanner(labelSize: labelSize)
            } else {
                unitNumber(calText, "CAL", ShuttlXColor.calories, size(calText, "CAL"), unitSize) { EmptyView() }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(workoutManager.calories > 0 ? "\(workoutManager.calories) calories, estimate" : "Calories no data")
            }
            Spacer(minLength: 0)
            unitNumber(hrText, "BPM", ShuttlXColor.heartRate, size(hrText, "BPM"), unitSize) { EmptyView() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hr > 0 ? "Heart rate \(hr) beats per minute" : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, max(10, h * 0.055))
        .frame(height: pageHeight)
    }
}

extension WorkoutPage {
    // MARK: - Overlays

    /// "KM 3 · 6:12" — green toast in the switch-toast row for `undoWindow` seconds.
    func splitToastView(_ toast: WatchWorkoutManager.SplitToast) -> some View {
        Text("\(TrainingView.splitLabel(toast.unit, toast.split.number)) \u{00B7} \(TrainingView.splitClock(toast.split.splitTime))")
            .font(.system(size: WatchScale.pt(14), weight: .heavy))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(ShuttlXColor.iconOnCTA)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 4)
            .frame(minHeight: 24 + 8)
            .background(ShuttlXColor.ctaPrimary, in: RoundedRectangle(cornerRadius: 18))
            .transition(.opacity)
            .accessibilityLabel(TrainingView.splitAccessible(toast.unit, toast.split))
            .task(id: toast.id) {
                AccessibilityNotification.Announcement(TrainingView.splitAccessible(toast.unit, toast.split)).post()
            }
    }

    /// "Now walking · Undo" — full-width orange toast for `WatchWorkoutManager.undoWindow`.
    func activitySwitchToast(_ sw: WatchWorkoutManager.ActivitySwitch) -> some View {
        HStack {
            Text(sw.to.nowText)
                .font(.system(size: WatchScale.pt(14), weight: .heavy))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            Button("Undo") { workoutManager.undoActivitySwitch() }
                .font(.system(size: WatchScale.pt(12), weight: .heavy))
                .fixedSize()
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .frame(minHeight: 24)
                .background(Color.black.opacity(0.18), in: Capsule())
                .contentShape(Rectangle().inset(by: -10))   // ~44pt hit area
                .accessibilityHint("Goes back to \(sw.from.displayName.lowercased())")
        }
        .foregroundStyle(ShuttlXColor.iconOnCTA)
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 4)
        .background(ShuttlXColor.ctaWarning, in: RoundedRectangle(cornerRadius: 18))
        .transition(.opacity)
        .task(id: sw.id) {
            AccessibilityNotification.Announcement("\(sw.to.nowText). Undo available.").post()
        }
    }
}
