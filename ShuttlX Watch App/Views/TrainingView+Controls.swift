import SwiftUI
import HealthKit
import WatchKit
import ShuttlXShared

extension TrainingView {
    // MARK: - Controls Tab (Translucent Circles)

    @ViewBuilder
    var controlsTab: some View {
        if themeManager.current.id == "mixtape" {
            mixtapeControlsTab
        } else {
            defaultControlsTab
        }
    }

    var defaultControlsTab: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: ShuttlXSpacing.xxl) {
                // Pause / Resume
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(workoutManager.isPaused ? .directionUp : .directionDown)
                    #endif
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(workoutManager.isPaused ? ShuttlXColor.ctaPrimary : ShuttlXColor.ctaPause)
                }
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")

                // Finish
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                    showingStopConfirmation = true
                }) {
                    Image(systemName: "stop.fill")
                        .font(ShuttlXFont.watchControlIcon)
                        .foregroundColor(ShuttlXColor.ctaDestructive)
                }
                .buttonStyle(ThemedControlButtonStyle())
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            // Labels
            HStack(spacing: ShuttlXSpacing.xxl) {
                Text(workoutManager.isPaused ? "Resume" : "Pause")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
                Text("End")
                    .font(ShuttlXFont.watchControlLabel)
                    .foregroundStyle(ShuttlXColor.textSecondary)
                    .frame(width: ShuttlXSize.controlButtonDiameter)
            }
            .padding(.top, ShuttlXSpacing.sm)

            Spacer()
        }
    }

    // MARK: - Mixtape Controls (cassette transport keys)
    //
    // Replaces the circular pause/stop with real chunky cassette keys that depress
    // mechanically (ThemedTransportButtonStyle). PLAY latches DOWN green while
    // running, pops UP amber when paused; STOP is the red destructive key. The
    // controller calls are identical to the default tab — only the chrome differs.
    var mixtapeControlsTab: some View {
        VStack(spacing: ShuttlXSpacing.md) {
            Spacer()

            HStack(spacing: ShuttlXSpacing.lg) {
                // PLAY / PAUSE — latched down (green) while running, up (amber) when paused.
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(workoutManager.isPaused ? .directionUp : .directionDown)
                    #endif
                    if workoutManager.isPaused {
                        workoutManager.resumeWorkout()
                    } else {
                        workoutManager.pauseWorkout()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 22, weight: .bold))
                        Text(workoutManager.isPaused ? "PLAY" : "PAUSE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    }
                    .frame(width: 60, height: 56)
                }
                .buttonStyle(ThemedTransportButtonStyle(
                    role: .play,
                    isLatched: !workoutManager.isPaused,
                    latchedAmber: workoutManager.isPaused))
                .accessibilityLabel(workoutManager.isPaused ? "Resume workout" : "Pause workout")
                .accessibilityHint("Play key")

                // STOP — red destructive key.
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                    showingStopConfirmation = true
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(ShuttlXColor.ctaDestructive)
                        Text("STOP")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    }
                    .frame(width: 60, height: 56)
                }
                .buttonStyle(ThemedTransportButtonStyle(role: .stop))
                .accessibilityLabel("Finish workout")
                .accessibilityHint("Saves the workout and shows your summary")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // P3-D: a "clunk" on every pause/resume — including crown- or auto-pause
        // that happens without a visible key press — so the tape stop/start is
        // always tactilely confirmed (cardiac-safety nicety).
        .sensoryFeedback(.impact(weight: .medium), trigger: workoutManager.isPaused)
    }
}
