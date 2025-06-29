import SwiftUI
import os.log

struct ProgramSelectionView: View {
    @EnvironmentObject var dataManager: SharedDataManager
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var showingDebugView = false
    @State private var samplePrograms: [TrainingProgram] = []
    
    private let logger = Logger(subsystem: "com.shuttlx.ShuttlX.watchkitapp", category: "ProgramSelectionView")
    
    var body: some View {
        List {
            Button(action: {
                logger.info("🐛 Debug view requested")
                showingDebugView = true
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Debug Info")
                }
            }
            .sheet(isPresented: $showingDebugView) {
                DebugView()
            }
            
            // Refresh button to manually sync programs
            Button(action: {
                logger.info("🔄 Manual refresh requested")
                dataManager.refreshProgramsFromiOS()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Programs")
                }
            }
            
            // Note: HealthKit permissions are managed on iPhone - no need for message here
            Section("Available Programs") {
                if dataManager.syncedPrograms.isEmpty {
                    Text("Loading programs...")
                        .foregroundColor(.secondary)
                        .onAppear {
                            logger.info("📋 No programs available, showing loading state")
                        }
                } else {
                    ForEach(dataManager.syncedPrograms, id: \.id) { program in
                        Button(action: {
                            logger.info("🎯 Selected program: \(program.name)")
                            logger.info("🏃‍♂️ Starting workout with selected program")
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
                                            .fill(interval.phase == .work ? Color.red : Color.blue)
                                            .frame(height: 4)
                                            .frame(width: max(2, min(8, interval.duration / 30)))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("Programs")
        .onAppear {
            logger.info("📺 ProgramSelectionView onAppear called")
            logger.info("📊 Current program count: \(dataManager.syncedPrograms.count)")
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
    let dataManager = SharedDataManager()
    let workoutManager = WatchWorkoutManager()
    workoutManager.setSharedDataManager(dataManager)
    
    return NavigationView {
        ProgramSelectionView()
            .environmentObject(dataManager)
            .environmentObject(workoutManager)
    }
}
