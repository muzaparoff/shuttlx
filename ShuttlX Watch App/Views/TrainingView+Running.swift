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

    /// Heart-limit mode: a synced limit and HR within 10% of it (or above).
    var heartLimitModeLimit: Int? {
        guard let limit = WatchSyncCoordinator.shared.heartSafety.upperLimit, limit > 0 else { return nil }
        let hr = workoutManager.heartRate
        return hr > 0 && Double(hr) >= Double(limit) * 0.9 ? limit : nil
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
            }

            ElapsedTimerText(referenceDate: workoutManager.timerReferenceDate,
                             clock: workoutManager.clock,
                             baseSize: WatchScale.pt(workoutManager.activitySwitch == nil ? 48 : 44),
                             availableWidth: screenWidth - 16,
                             weight: .semibold,
                             color: workoutManager.isPaused ? ShuttlXColor.ctaWarning : ShuttlXColor.textPrimary)
                .modifier(PausePulse(active: workoutManager.isPaused, low: 0.35))
                .padding(.top, WatchScale.pt(6))

            if let word, let ref = zoneReferenceHR {
                let color = zoneWordColor(word)
                Text(word)
                    .font(.system(size: WatchScale.pt(workoutManager.activitySwitch == nil ? 30 : 28), weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(color)
                    .fixedSize()
                    .padding(.top, WatchScale.pt(workoutManager.activitySwitch == nil ? 10 : 6))
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

            if !bannerShown && workoutManager.activitySwitch == nil {
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

    private func heartLimitPage(limit: Int) -> some View {
        let hr = workoutManager.heartRate
        return VStack(spacing: 0) {
            Text("HEART LIMIT \(limit)")
                .font(.system(size: WatchScale.pt(12), weight: .bold))
                .tracking(WatchScale.pt(12) * 0.08)
                .foregroundStyle(ShuttlXColor.textPrimary)
            Text("\(hr)")
                .font(.system(size: WatchScale.pt(62), weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ShuttlXColor.ctaWarning)
                .fixedSize()
                .padding(.top, WatchScale.pt(6))
            WatchFillBar(fraction: Double(hr) / Double(limit),
                         fill: LinearGradient(colors: [ShuttlXColor.running, ShuttlXColor.ctaWarning],
                                              startPoint: .leading, endPoint: .trailing),
                         height: WatchScale.pt(9))
                .padding(.top, WatchScale.pt(10))
            Text("Ease off — HR high")
                .font(.system(size: WatchScale.pt(13), weight: .heavy))
                .foregroundStyle(ShuttlXColor.ctaWarning)
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, WatchScale.pt(6))
                .padding(.horizontal, WatchScale.pt(12))
                .background(ShuttlXColor.ctaWarning.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, WatchScale.pt(12))
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate \(hr), limit \(limit). Ease off, heart rate high.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Page 1 (swipe left)

    var freeRunMetricsPage: some View {
        let h = screenHeight
        let rowWidth = screenWidth - 16
        let unitSize = max(11, h * 0.062)
        let cap = h * 0.17
        let calText = workoutManager.calories > 0 ? "\(workoutManager.calories)" : "\u{2014}"
        func size(_ value: String, _ unit: String) -> CGFloat {
            fittedMetricSize(glyphs: max(3, value.count), unit: unit, unitSize: unitSize,
                             accessoryWidth: 0, available: rowWidth, cap: cap)
        }

        return VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            unitNumber(compactDistanceValue, compactDistanceUnit, ShuttlXColor.textPrimary,
                       size(compactDistanceValue, compactDistanceUnit), unitSize) { EmptyView() }
                .background(kmSplitHighlight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Distance \(accessibleDistance)")
            Spacer(minLength: 0)
            unitNumber(paceValueText, "/KM", ShuttlXColor.running,
                       size(paceValueText, "/KM"), unitSize) { EmptyView() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessiblePace)
            Spacer(minLength: 0)
            unitNumber(calText, "CAL", ShuttlXColor.calories, size(calText, "CAL"), unitSize) { EmptyView() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(workoutManager.calories > 0 ? "\(workoutManager.calories) calories, estimate" : "Calories no data")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.bottom, max(10, h * 0.055))
    }

    // MARK: - Overlays

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
