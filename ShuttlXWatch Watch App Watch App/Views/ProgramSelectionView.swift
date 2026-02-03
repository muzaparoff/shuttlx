import SwiftUI
import os.log

struct ProgramSelectionView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    #if DEBUG
    @State private var showingDebugView = false
    #endif
    @State private var samplePrograms: [TrainingProgram] = []

    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ProgramSelectionView")

    var body: some View {
        List {
            #if DEBUG
            Button(action: {
                logger.info("Debug view requested")
                showingDebugView = true
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Debug Info")
                }
            }
            .accessibilityLabel("Debug Info")
            .accessibilityHint("Opens debug information screen")
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
            #endif

            // Sync button to manually sync programs from iPhone
            Button(action: {
                logger.info("Manual sync requested")
                dataManager.syncFromiPhone()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Sync from iPhone")
                }
            }
            .accessibilityLabel("Sync from iPhone")
            .accessibilityHint("Manually refreshes programs from your iPhone")

            // Note: HealthKit permissions are managed on iPhone - no need for message here
            Section("Available Programs") {
                if dataManager.syncedPrograms.isEmpty {
                    Text("Loading programs...")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Loading programs")
                        .onAppear {
                            logger.info("No programs available, showing loading state")
                        }
                } else {
                    ForEach(dataManager.syncedPrograms, id: \.id) { program in
                        Button(action: {
                            logger.info("Selected program: \(program.name)")
                            logger.info("Starting workout with selected program")
                            workoutManager.startWorkout(with: program)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(program.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                HStack {
                                    Text("\(program.intervals.count) intervals")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(formatDuration(program.totalDuration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                // Visual preview of intervals
                                HStack(spacing: 2) {
                                    ForEach(Array(program.intervals.enumerated()), id: \.offset) { index, interval in
                                        Rectangle()
                                            .fill(interval.phase == .work ? Color.red : Color.accentColor)
                                            .frame(height: 4)
                                            .frame(width: max(2, min(8, interval.duration / 30)))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityHidden(true)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(program.name)")
                        .accessibilityValue("\(program.intervals.count) intervals, \(formatDuration(program.totalDuration))")
                        .accessibilityHint("Double tap to start this workout")
                    }
                }
            }
        }
        .navigationTitle("Programs")
        .onAppear {
            logger.info("ProgramSelectionView onAppear called")
            logger.info("Current program count: \(dataManager.syncedPrograms.count)")
            // Programs are loaded via SharedDataManager
        }

    }

    private func loadSamplePrograms() {
        // Simple sample programs without complex dependencies
        samplePrograms = [
            TrainingProgram(
                name: "Beginner Walk-Run",
                type: .walkRun,
                intervals: [
                    TrainingInterval(phase: .rest, duration: 300, intensity: .low),
                    TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                    TrainingInterval(phase: .rest, duration: 120, intensity: .low)
                ],
                maxPulse: 180,
                createdDate: Date(),
                lastModified: Date()
            )
        ]
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    let dataManager = SharedDataManager.shared
    let workoutManager = WatchWorkoutManager()

    NavigationView {
        ProgramSelectionView()
            .environmentObject(dataManager)
            .environmentObject(workoutManager)
            .onAppear {
                workoutManager.setSharedDataManager(dataManager)
            }
    }
}
