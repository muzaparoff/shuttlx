import SwiftUI
import WatchKit
import ShuttlXShared

/// Free-run pages from the timeline mockup (watch screens 2-4):
/// page 0 `runningPage` (tag, time, one zone word, HR — or heart-limit mode),
/// page 1 `freeRunMetricsPage` (distance, pace, calories).
/// Sizes are mockup px via `WatchScale.pt` — solved, never scale-to-fit.
extension TrainingView {

    // MARK: - Page 0

    @ViewBuilder
    var runningPage: some View {
        if let limit = heartLimitModeLimit {
            heartLimitPage(limit: limit)
        } else {
            oneWordPage
        }
    }

    /// Heart-limit mode: on at 90 % of the resolved limit, off below 85 %
    /// (`HeartLimitMode`, updated per HR sample in TrainingView).
    var heartLimitModeLimit: Int? {
        heartLimitModeOn ? resolvedHeartLimit : nil
    }

    private var oneWordPage: some View {
        let activity = workoutManager.currentActivity
        let paused = workoutManager.isPaused
        let tagColor = paused ? ShuttlXColor.ctaWarning
            : activity == .unknown ? ShuttlXColor.textSecondary : activity.themeColor
        let hr = workoutManager.heartRate
        let word = heartZoneWord
        let bannerShown = isHighIntensityWarning || workoutManager.noHeartRateDetected
        let labelSize = max(10, screenHeight * 0.08)
        // The switch toast wins; a split toast waits behind it (WatchWorkoutManager).
        let toastShown = workoutManager.activitySwitch != nil || workoutManager.splitToast != nil

        return VStack(alignment: .leading, spacing: 0) {
            // Paused: the word, not just the amber clock (colour alone is not a state).
            Text(paused ? "\u{23F8}\u{FE0E} PAUSED" : "\u{25CF} \(activity.watchTag)")
                .font(.system(size: WatchScale.text(11), weight: .bold))
                .tracking(WatchScale.text(11) * 0.08)
                .foregroundStyle(tagColor)
                .accessibilityLabel(paused ? "Paused" : activity == .unknown ? workoutManager.workoutName : activity.displayName)

            // The toast gets its own row under the tag (the tag shares its line
            // with the system clock); the hint below steps aside to pay for it.
            if let sw = workoutManager.activitySwitch {
                activitySwitchToast(sw).padding(.top, 4)
            } else if let split = workoutManager.splitToast {
                splitToastView(split).padding(.top, 4)
            }

            ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                             clock: workoutManager.clock,
                             baseSize: WatchScale.pt(toastShown ? 44 : 48),
                             availableWidth: screenWidth - 16,
                             weight: .semibold,
                             color: workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                .modifier(PausePulse(active: workoutManager.isPaused, low: 0.35))
                .padding(.top, WatchScale.pt(6))

            if let word, let ref = zoneReferenceHR {
                let color = zoneWordColor(word)
                Text(word)
                    .font(.system(size: WatchScale.pt(toastShown ? 28 : 30), weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(color)
                    .fixedSize()
                    .padding(.top, WatchScale.pt(toastShown ? 6 : 10))
                    .accessibilityLabel("Effort \(word.lowercased())")
                WatchFillBar(fraction: Double(hr) / ref, fill: color)
                    .padding(.top, WatchScale.pt(8))
            }

            Spacer(minLength: 0)

            if isHighIntensityWarning {
                highIntensityWarningView(labelSize: labelSize).padding(.bottom, 4)
            }
            if workoutManager.noHeartRateDetected {
                noHeartRateBanner(labelSize: labelSize).padding(.bottom, 4)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(hr > 0 ? "\(hr)" : "\u{2014}")
                    .font(.system(size: WatchScale.pt(30), weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(ShuttlXColor.heartRate)
                    .fixedSize()
                Text("BPM")
                    .font(.system(size: WatchScale.text(11), weight: .bold))
                    .foregroundStyle(ShuttlXColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(hr > 0 ? "Heart rate \(hr) beats per minute" : "Heart rate no data")
            .accessibilityAddTraits(.updatesFrequently)

            if !bannerShown && !toastShown {
                // Short enough for the 10pt text floor on 40mm.
                Text("Swipe left: more metrics")
                    .font(.system(size: WatchScale.text(10)))
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.top, 1)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        // Keep the last line clear of the TabView page dots.
        .padding(.bottom, max(10, screenHeight * 0.055))
        // The page TabView proposes no height, so the maxHeight frame above collapses
        // to the content and a short stack (no HR) floated to the centre. Pinned to
        // `pageHeight`, BPM stays at the bottom whatever is shown.
        .frame(height: pageHeight)
    }

    /// Audit W3 / 3A: the activity or PAUSED tag stays, BPM is white up to the limit
    /// and amber above it, the pill warns "Near your limit" from 90 % and says
    /// "Ease off" only above the limit (the alert's threshold), and a small timer +
    /// the limit sit at the bottom.
    private func heartLimitPage(limit: Int) -> some View {
        let hr = workoutManager.heartRate
        let over = hr > limit
        let paused = workoutManager.isPaused
        let activity = workoutManager.currentActivity
        let pill = over ? Self.easeOffText : "Near your limit"
        let pillSize = min(WatchScale.pt(13), (screenWidth - 16 - 2 * WatchScale.pt(12)) / (CGFloat(pill.count) * 0.62))
        let small = WatchScale.text(11)
        return VStack(alignment: .leading, spacing: 0) {
            Text(paused ? "\u{23F8}\u{FE0E} PAUSED" : "\u{25CF} \(activity.watchTag)")
                .font(.system(size: small, weight: .bold))
                .tracking(small * 0.08)
                .foregroundStyle(paused ? ShuttlXColor.ctaWarning
                                 : activity == .unknown ? ShuttlXColor.textSecondary : activity.themeColor)
                .accessibilityLabel(paused ? "Paused" : activity == .unknown ? workoutManager.workoutName : activity.displayName)
            Text("\(hr)")
                .font(.system(size: WatchScale.pt(58), weight: .semibold, design: .monospaced))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, max(10, screenHeight * 0.055))
        .frame(height: pageHeight)
    }

    // MARK: - Page 1 (swipe left)

    /// Distance, pace (speed while cycling), BPM, then the last split (calories until
    /// the first one). HR and the safety banner never leave the screen (watchos.md):
    /// while a banner shows it takes the 4th row (audit W1 / 1E).
    var freeRunMetricsPage: some View {
        let h = screenHeight
        let rowWidth = screenWidth - 16
        let unitSize = max(11, h * 0.062)
        // Four rows: 0.15h each (was 0.17h for three) keeps the stack inside the page on 40mm.
        let cap = h * 0.15
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
            unitNumber(compactDistanceValue, compactDistanceUnit, ShuttlXColor.textPrimary,
                       size(compactDistanceValue, compactDistanceUnit), unitSize) { EmptyView() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Distance \(accessibleDistance)")
            Spacer(minLength: 0)
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
            unitNumber(hrText, "BPM", ShuttlXColor.heartRate, size(hrText, "BPM"), unitSize) { EmptyView() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hr > 0 ? "Heart rate \(hr) beats per minute" : "Heart rate no data")
                .accessibilityAddTraits(.updatesFrequently)
            Spacer(minLength: 0)
            if isHighIntensityWarning {
                highIntensityWarningView(labelSize: labelSize)
            } else if workoutManager.noHeartRateDetected {
                noHeartRateBanner(labelSize: labelSize)
            } else if let split = workoutManager.splitCounter(for: distanceUnit).lastSplit {
                let label = Self.splitLabel(distanceUnit, split.number)
                let value = Self.splitClock(split.splitTime)
                HStack(alignment: .firstTextBaseline, spacing: max(1, unitSize * 0.18)) {
                    Text(label)
                        .font(.system(size: unitSize, weight: .bold, design: .monospaced))
                        .foregroundColor(ShuttlXColor.textSecondary)
                        .fixedSize()
                    Text(value)
                        .font(.system(size: size(value, label), weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(ShuttlXColor.textPrimary)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last split, \(Self.splitAccessible(distanceUnit, split))")
            } else {
                unitNumber(calText, "CAL", ShuttlXColor.calories, size(calText, "CAL"), unitSize) { EmptyView() }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(workoutManager.calories > 0 ? "\(workoutManager.calories) calories, estimate" : "Calories no data")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, max(10, h * 0.055))
        .frame(height: pageHeight)
    }

    // MARK: - Overlays

    /// "KM 3 · 6:12" — green toast in the switch-toast row for `undoWindow` seconds.
    func splitToastView(_ toast: WatchWorkoutManager.SplitToast) -> some View {
        Text("\(Self.splitLabel(toast.unit, toast.split.number)) \u{00B7} \(Self.splitClock(toast.split.splitTime))")
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
            .accessibilityLabel(Self.splitAccessible(toast.unit, toast.split))
            .task(id: toast.id) {
                AccessibilityNotification.Announcement(Self.splitAccessible(toast.unit, toast.split)).post()
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
