import Foundation
import Combine
import HealthKit

class DataManager: ObservableObject, @unchecked Sendable {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    @Published var healthKitAuthorized = false
    
    private var cancellables = Set<AnyCancellable>()
    private let healthStore = HKHealthStore()
    
    // MARK: - App Group Properties
    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")
    
    // Fallback container for when App Groups is not available (e.g., in simulator without provisioning)
    private var fallbackContainer: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    }

    init() {
        loadProgramsFromAppGroup()
        loadSessionsFromAppGroup()
        
        if programs.isEmpty {
            loadSampleData()
            saveProgramsToAppGroup() // Save samples to App Group
        }
        
        if sessions.isEmpty {
            loadSampleSessions()
            saveSessionsToAppGroup()
        }
        
        // FIXED: Modified to prevent potential MainActor deadlocks
        // Set DataManager reference in SharedDataManager using detached task
        Task.detached {
            // Set data manager reference first
            await MainActor.run {
                SharedDataManager.shared.setDataManager(self)
            }
            
            // Small delay to ensure proper initialization order
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Then sync programs after a brief delay to avoid startup contention
            await MainActor.run {
                print("🔄 Initial sync to watch (delayed to prevent deadlock)...")
                SharedDataManager.shared.syncProgramsToWatch(self.programs)
            }
        }
        
        // Setup bindings on main actor
        Task { @MainActor in
            setupBindings()
        }
    }
    
    @MainActor
    private func setupBindings() {
        // When local programs change, save to App Group and notify watch
        $programs
            .debounce(for: .seconds(0.1), scheduler: DispatchQueue.main)  // Reduced from 0.5 to 0.1 seconds
            .sink { [weak self] updatedPrograms in
                self?.saveProgramsToAppGroup()
                print("📱 Programs changed, syncing \(updatedPrograms.count) to watch...")
                SharedDataManager.shared.syncProgramsToWatch(updatedPrograms)
            }
            .store(in: &cancellables)
        
        // When a session is received from the watch, merge and save it
        SharedDataManager.shared.$syncedSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedSessions in
                self?.handleReceivedSessions(receivedSessions)
            }
            .store(in: &cancellables)
    }
    
    func handleReceivedSessions(_ receivedSessions: [TrainingSession]) {
        var hasChanges = false
        for session in receivedSessions {
            if !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
                hasChanges = true
                print("📱✅ New session received and merged: \(session.programName)")
            }
        }
        if hasChanges {
            saveSessionsToAppGroup()
        }
    }

    // MARK: - Sample Data
    private func loadSampleData() {
        // Ensure consistent sample data across platforms
        let beginnerProgram = TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),   // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),   // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)    // 5min cooldown walk
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        
        print("📋 Creating Beginner Walk-Run with \(beginnerProgram.intervals.count) intervals, total duration: \(beginnerProgram.totalDuration/60) minutes")
        
        let intermediateProgram = TrainingProgram(
            name: "Intermediate Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),   // 5min warmup walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),    // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),    // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)    // 5min cooldown walk
            ],
            maxPulse: 185,
            createdDate: Date().addingTimeInterval(-86400),
            lastModified: Date().addingTimeInterval(-86400)
        )
        
        print("📋 Creating Intermediate Walk-Run with \(intermediateProgram.intervals.count) intervals, total duration: \(intermediateProgram.totalDuration/60) minutes")
        
        programs = [beginnerProgram, intermediateProgram]
        print("📱 Loaded \(programs.count) sample programs on iOS")
    }
    
    private func loadSampleSessions() {
        let calendar = Calendar.current
        let now = Date()
        
        // Add sessions for the past week
        for i in 1...7 {
            if let sessionDate = calendar.date(byAdding: .day, value: -i, to: now) {
                let session = TrainingSession(
                    programID: programs.first?.id ?? UUID(),
                    programName: programs.first?.name ?? "Sample Program",
                    startDate: sessionDate,
                    endDate: calendar.date(byAdding: .minute, value: 25, to: sessionDate),
                    duration: 25 * 60, // 25 minutes
                    averageHeartRate: Double.random(in: 140...160),
                    maxHeartRate: Double.random(in: 170...185),
                    caloriesBurned: Double.random(in: 200...350),
                    distance: Double.random(in: 2.0...4.5),
                    completedIntervals: []
                )
                sessions.append(session)
            }
        }
    }
    
    // MARK: - CRUD Operations
    func addProgram(_ program: TrainingProgram) {
        programs.append(program)
        // Publisher binding will handle saving and syncing
    }
    
    func saveProgram(_ program: TrainingProgram) {
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        } else {
            programs.append(program)
        }
        
        // Force immediate sync to ensure watchOS gets the new program
        print("💾 Saving program: \(program.name) with \(program.intervals.count) intervals")
        saveProgramsToAppGroup()
        
        // Force immediate sync without waiting for debounce
        Task { @MainActor in
            print("🔄 Triggering immediate sync to watch...")
            SharedDataManager.shared.syncProgramsToWatch(programs)
            
            // Add a delay and retry mechanism to ensure sync succeeds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔄 Retry sync to watch (ensuring delivery)...")
                SharedDataManager.shared.syncProgramsToWatch(self.programs)
            }
        }
        
        // Additional debug info
        print("📱 Total programs after save: \(programs.count)")
        print("📱 Program details: \(program.name) - \(program.intervals.count) intervals - \(program.totalDuration/60) minutes")
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        // Publisher binding will handle saving and syncing
    }
    
    // MARK: - HealthKit Integration
    func requestHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        let typesToRead: Set<HKQuantityType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            await MainActor.run {
                self.healthKitAuthorized = true
                print("✅ HealthKit permissions granted")
            }
        } catch {
            print("❌ HealthKit permission request failed: \(error)")
        }
    }
    
    // MARK: - App Group Storage (Replaces Local Storage)
    private func saveProgramsToAppGroup() {
        guard let containerURL = getWorkingContainer() else {
            print("❌ No valid container URL available for programs.")
            return
        }
        
        let url = containerURL.appendingPathComponent(programsKey)
        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: url)
            print("✅ Saved \(programs.count) programs to shared storage.")
        } catch {
            print("❌ Failed to save programs to shared storage: \(error)")
        }
    }
    
    private func loadProgramsFromAppGroup() {
        guard let containerURL = getWorkingContainer() else {
            print("⚠️ No valid container URL available for loading programs")
            return
        }
        
        let url = containerURL.appendingPathComponent(programsKey)
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("ℹ️ No program file found in shared storage. Starting fresh.")
                return
            }
            let data = try Data(contentsOf: url)
            self.programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            print("✅ Loaded \(programs.count) programs from shared storage.")
        } catch {
            print("❌ Failed to load programs from shared storage: \(error)")
        }
    }
    
    private func saveSessionsToAppGroup() {
        guard let containerURL = getWorkingContainer() else {
            print("❌ No valid container URL available for sessions.")
            return
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
            print("✅ Saved \(sessions.count) sessions to shared storage.")
        } catch {
            print("❌ Failed to save sessions to shared storage: \(error)")
        }
    }
    
    func loadSessionsFromAppGroup() {
        guard let containerURL = getWorkingContainer() else {
            print("⚠️ No valid container URL available for loading sessions")
            return
        }
        
        let url = containerURL.appendingPathComponent(sessionsKey)
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("ℹ️ No session file found in shared storage. Starting fresh.")
                return
            }
            let data = try Data(contentsOf: url)
            self.sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            print("✅ Loaded \(sessions.count) sessions from App Group.")
        } catch {
            print("❌ Failed to load sessions from App Group: \(error)")
        }
    }
    
    // MARK: - Container Management
    private func getWorkingContainer() -> URL? {
        // First try the App Group container
        if let appGroupContainer = sharedContainer {
            // Check if the directory exists or can be created
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: appGroupContainer.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                return appGroupContainer
            } else {
                // Try to create the App Group directory
                do {
                    try fileManager.createDirectory(at: appGroupContainer, withIntermediateDirectories: true, attributes: nil)
                    print("✅ Created App Group container directory")
                    return appGroupContainer
                } catch {
                    print("⚠️ Failed to create App Group container, using fallback: \(error.localizedDescription)")
                }
            }
        }
        
        // Fallback to Documents directory
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: fallbackContainer, withIntermediateDirectories: true, attributes: nil)
            print("ℹ️ Using fallback container: \(fallbackContainer.path)")
            return fallbackContainer
        } catch {
            print("❌ Failed to create fallback container: \(error.localizedDescription)")
            return nil
        }
    }
}
