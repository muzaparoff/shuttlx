import Foundation
import CloudKit
import Combine

class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let connectivityManager = WatchConnectivityManager.shared
    
    init() {
        loadFromLocal()
        if programs.isEmpty {
            loadSampleData()
        }
        setupCloudKitSync()
        setupWatchConnectivity()
    }
    
    // MARK: - Sample Data for Testing
    private func loadSampleData() {
        let beginnerProgram = TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),     // 2min walk
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate), // 1min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        
        let intermediateProgram = TrainingProgram(
            name: "Intermediate Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),     // 5min warmup walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),      // 1min walk
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate), // 2min run
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)      // 5min cooldown walk
            ],
            maxPulse: 185,
            createdDate: Date().addingTimeInterval(-86400), // Yesterday
            lastModified: Date().addingTimeInterval(-86400)
        )
        
        programs = [beginnerProgram, intermediateProgram]
        
        // Add sample training sessions
        let sampleSession = TrainingSession(
            programID: beginnerProgram.id,
            programName: beginnerProgram.name,
            startDate: Date().addingTimeInterval(-7200), // 2 hours ago
            endDate: Date().addingTimeInterval(-5400),   // 1.5 hours ago
            duration: 1800, // 30 minutes
            averageHeartRate: 145,
            maxHeartRate: 168,
            caloriesBurned: 245,
            distance: 2.1,
            completedIntervals: []
        )
        
        sessions = [sampleSession]
        saveToLocal()
        
        // Send sample data to watch immediately after loading
        connectivityManager.sendProgramsToWatch(programs)
    }
    
    // MARK: - CRUD Operations
    func saveProgram(_ program: TrainingProgram) {
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        } else {
            programs.append(program)
        }
        saveToLocal()
        
        // Sync to watch
        connectivityManager.sendProgramsToWatch(programs)
        
        // TODO: Sync to CloudKit
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        saveToLocal()
        
        // Send updated program list to watch after deletion
        connectivityManager.sendProgramsToWatch(programs)
        
        // TODO: Delete from CloudKit
    }
    
    func saveSession(_ session: TrainingSession) {
        sessions.append(session)
        saveToLocal()
        // TODO: Sync to CloudKit
    }
    
    // MARK: - Local Storage
    private func saveToLocal() {
        // Save programs to UserDefaults
        if let encoded = try? JSONEncoder().encode(programs) {
            UserDefaults.standard.set(encoded, forKey: "trainingPrograms")
        }
        
        // Save sessions to UserDefaults
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "trainingSessions")
        }
    }
    
    private func loadFromLocal() {
        // Load programs from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "trainingPrograms"),
           let decoded = try? JSONDecoder().decode([TrainingProgram].self, from: data) {
            programs = decoded
        }
        
        // Load sessions from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "trainingSessions"),
           let decoded = try? JSONDecoder().decode([TrainingSession].self, from: data) {
            sessions = decoded
        }
    }
    
    // MARK: - CloudKit Sync (placeholder)
    private func setupCloudKitSync() {
        // TODO: Implement CloudKit synchronization
        // This would handle:
        // - Uploading local changes to CloudKit
        // - Downloading remote changes from CloudKit
        // - Resolving conflicts
        print("CloudKit sync setup - TODO: Implement")
    }
    
    // MARK: - WatchConnectivity Setup
    private func setupWatchConnectivity() {
        // Listen for sessions received from watch
        NotificationCenter.default.publisher(for: .sessionReceivedFromWatch)
            .compactMap { $0.object as? TrainingSession }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.saveSession(session)
            }
            .store(in: &cancellables)
        
        // Listen for program requests from watch
        NotificationCenter.default.publisher(for: .programsRequestedFromWatch)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.connectivityManager.sendProgramsToWatch(self.programs)
            }
            .store(in: &cancellables)
        
        // Send current programs to watch when they change
        $programs
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] programs in
                self?.connectivityManager.sendProgramsToWatch(programs)
            }
            .store(in: &cancellables)
    }
}
