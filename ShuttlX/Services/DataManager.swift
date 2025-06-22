import Foundation
import Combine

class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let sharedDataManager = SharedDataManager.shared
    
    // MARK: - App Group Properties
    private let programsKey = "programs.json"
    private let sessionsKey = "sessions.json"
    private let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared")

    init() {
        loadProgramsFromAppGroup()
        loadSessionsFromAppGroup()
        
        if programs.isEmpty {
            loadSampleData()
            saveProgramsToAppGroup() // Save samples to App Group
        }
        setupBindings()
        
        // Initial sync to ensure watch is up-to-date
        sharedDataManager.syncProgramsToWatch(programs)
    }
    
    private func setupBindings() {
        // When local programs change, save to App Group and notify watch
        $programs
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] updatedPrograms in
                self?.saveProgramsToAppGroup()
                self?.sharedDataManager.syncProgramsToWatch(updatedPrograms)
            }
            .store(in: &cancellables)
        
        // When a session is received from the watch, merge and save it
        sharedDataManager.$syncedSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] receivedSessions in
                self?.handleReceivedSessions(receivedSessions)
            }
            .store(in: &cancellables)
    }
    
    private func handleReceivedSessions(_ receivedSessions: [TrainingSession]) {
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
        let beginnerProgram = TrainingProgram(
            name: "Beginner Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 120, intensity: .low),
                TrainingInterval(phase: .work, duration: 60, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)
            ],
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date()
        )
        
        let intermediateProgram = TrainingProgram(
            name: "Intermediate Walk-Run",
            type: .walkRun,
            intervals: [
                TrainingInterval(phase: .rest, duration: 300, intensity: .low),
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 60, intensity: .low),
                TrainingInterval(phase: .work, duration: 120, intensity: .moderate),
                TrainingInterval(phase: .rest, duration: 300, intensity: .low)
            ],
            maxPulse: 185,
            createdDate: Date().addingTimeInterval(-86400),
            lastModified: Date().addingTimeInterval(-86400)
        )
        
        programs = [beginnerProgram, intermediateProgram]
        saveProgramsToAppGroup()
    }
    
    // MARK: - CRUD Operations
    func saveProgram(_ program: TrainingProgram) {
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        } else {
            programs.append(program)
        }
        // Publisher binding will handle saving and syncing
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        // Publisher binding will handle saving and syncing
    }
    
    // MARK: - App Group Storage (Replaces Local Storage)
    private func saveProgramsToAppGroup() {
        guard let url = sharedContainer?.appendingPathComponent(programsKey) else {
            print("❌ Invalid shared container URL for programs.")
            return
        }
        do {
            let data = try JSONEncoder().encode(programs)
            try data.write(to: url)
            print("✅ Saved \(programs.count) programs to App Group.")
        } catch {
            print("❌ Failed to save programs to App Group: \(error)")
        }
    }
    
    private func loadProgramsFromAppGroup() {
        guard let url = sharedContainer?.appendingPathComponent(programsKey) else { return }
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("ℹ️ No program file found in App Group. Starting fresh.")
                return
            }
            let data = try Data(contentsOf: url)
            self.programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            print("✅ Loaded \(programs.count) programs from App Group.")
        } catch {
            print("❌ Failed to load programs from App Group: \(error)")
        }
    }
    
    private func saveSessionsToAppGroup() {
        guard let url = sharedContainer?.appendingPathComponent(sessionsKey) else {
            print("❌ Invalid shared container URL for sessions.")
            return
        }
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
            print("✅ Saved \(sessions.count) sessions to App Group.")
        } catch {
            print("❌ Failed to save sessions to App Group: \(error)")
        }
    }
    
    private func loadSessionsFromAppGroup() {
        guard let url = sharedContainer?.appendingPathComponent(sessionsKey) else { return }
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("ℹ️ No session file found in App Group. Starting fresh.")
                return
            }
            let data = try Data(contentsOf: url)
            self.sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            print("✅ Loaded \(sessions.count) sessions from App Group.")
        } catch {
            print("❌ Failed to load sessions from App Group: \(error)")
        }
    }
}
