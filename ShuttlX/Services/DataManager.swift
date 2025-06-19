import Foundation
import CloudKit
import Combine

class DataManager: ObservableObject {
    @Published var programs: [TrainingProgram] = []
    @Published var sessions: [TrainingSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitManager = CloudKitManager()
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let programsKey = "saved_training_programs"
    private let sessionsKey = "saved_training_sessions"
    
    init() {
        loadLocalData()
        setupCloudKitSync()
    }
    
    // MARK: - Program Management
    
    func saveProgram(_ program: TrainingProgram) {
        var updatedProgram = program
        updatedProgram.lastModified = Date()
        
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = updatedProgram
        } else {
            programs.append(updatedProgram)
        }
        
        saveToLocal()
        
        // Sync to CloudKit
        cloudKitManager.saveProgram(updatedProgram) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedProgram):
                    if let index = self?.programs.firstIndex(where: { $0.id == savedProgram.id }) {
                        self?.programs[index] = savedProgram
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to sync program: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteProgram(_ program: TrainingProgram) {
        programs.removeAll { $0.id == program.id }
        saveToLocal()
        
        // Delete from CloudKit
        if let recordID = program.recordID {
            cloudKitManager.deleteProgram(recordID) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // Successfully deleted
                    case .failure(let error):
                        self?.errorMessage = "Failed to delete program from cloud: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func getProgram(by id: UUID) -> TrainingProgram? {
        return programs.first { $0.id == id }
    }
    
    // MARK: - Session Management
    
    func saveSession(_ session: TrainingSession) {
        sessions.append(session)
        saveToLocal()
        
        // Sync to CloudKit
        cloudKitManager.saveSession(session) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let savedSession):
                    if let index = self?.sessions.firstIndex(where: { $0.id == savedSession.id }) {
                        self?.sessions[index] = savedSession
                    }
                case .failure(let error):
                    self?.errorMessage = "Failed to sync session: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func getSessionsForProgram(_ programID: UUID) -> [TrainingSession] {
        return sessions.filter { $0.programID == programID }
    }
    
    func getRecentSessions(limit: Int = 10) -> [TrainingSession] {
        return Array(sessions.sorted { $0.startDate > $1.startDate }.prefix(limit))
    }
    
    // MARK: - Local Storage
    
    private func loadLocalData() {
        loadPrograms()
        loadSessions()
    }
    
    private func loadPrograms() {
        if let data = UserDefaults.standard.data(forKey: programsKey) {
            do {
                programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            } catch {
                print("Failed to load programs from local storage: \(error)")
                programs = []
            }
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey) {
            do {
                sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            } catch {
                print("Failed to load sessions from local storage: \(error)")
                sessions = []
            }
        }
    }
    
    private func saveToLocal() {
        savePrograms()
        saveSessions()
    }
    
    private func savePrograms() {
        do {
            let data = try JSONEncoder().encode(programs)
            UserDefaults.standard.set(data, forKey: programsKey)
        } catch {
            print("Failed to save programs to local storage: \(error)")
        }
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to save sessions to local storage: \(error)")
        }
    }
    
    // MARK: - CloudKit Sync
    
    private func setupCloudKitSync() {
        // Load initial data from CloudKit
        loadFromCloudKit()
        
        // Setup periodic sync
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.syncWithCloudKit()
        }
    }
    
    func loadFromCloudKit() {
        isLoading = true
        
        let group = DispatchGroup()
        
        // Load programs
        group.enter()
        cloudKitManager.fetchPrograms { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudPrograms):
                    self?.mergePrograms(cloudPrograms)
                case .failure(let error):
                    self?.errorMessage = "Failed to load programs from cloud: \(error.localizedDescription)"
                }
                group.leave()
            }
        }
        
        // Load sessions
        group.enter()
        cloudKitManager.fetchSessions { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudSessions):
                    self?.mergeSessions(cloudSessions)
                case .failure(let error):
                    self?.errorMessage = "Failed to load sessions from cloud: \(error.localizedDescription)"
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func syncWithCloudKit() {
        // This would implement incremental sync based on modification dates
        // For now, we'll just do a simple fetch
        loadFromCloudKit()
    }
    
    private func mergePrograms(_ cloudPrograms: [TrainingProgram]) {
        for cloudProgram in cloudPrograms {
            if let localIndex = programs.firstIndex(where: { $0.id == cloudProgram.id }) {
                // Update local program if cloud version is newer
                if cloudProgram.lastModified > programs[localIndex].lastModified {
                    programs[localIndex] = cloudProgram
                }
            } else {
                // Add new program from cloud
                programs.append(cloudProgram)
            }
        }
        saveToLocal()
    }
    
    private func mergeSessions(_ cloudSessions: [TrainingSession]) {
        for cloudSession in cloudSessions {
            if !sessions.contains(where: { $0.id == cloudSession.id }) {
                sessions.append(cloudSession)
            }
        }
        saveToLocal()
    }
    
    // MARK: - Data Reset (for development/testing)
    
    func resetAllData() {
        programs.removeAll()
        sessions.removeAll()
        saveToLocal()
        
        UserDefaults.standard.removeObject(forKey: programsKey)
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }
    
    // MARK: - Sample Data (for testing)
    
    func createSampleData() {
        let samplePrograms = [
            TrainingProgram(
                name: "Beginner Walk-Run",
                intervals: [
                    TrainingInterval(type: .walk, duration: 300), // 5 min warm-up walk
                    TrainingInterval(type: .run, duration: 60),   // 1 min run
                    TrainingInterval(type: .walk, duration: 90),  // 1.5 min walk
                    TrainingInterval(type: .run, duration: 60),   // 1 min run
                    TrainingInterval(type: .walk, duration: 90),  // 1.5 min walk
                    TrainingInterval(type: .run, duration: 60),   // 1 min run
                    TrainingInterval(type: .walk, duration: 300)  // 5 min cool-down walk
                ],
                maxPulse: 160
            ),
            TrainingProgram(
                name: "Intermediate Intervals",
                intervals: [
                    TrainingInterval(type: .walk, duration: 180), // 3 min warm-up
                    TrainingInterval(type: .run, duration: 120),  // 2 min run
                    TrainingInterval(type: .walk, duration: 60),  // 1 min walk
                    TrainingInterval(type: .run, duration: 120),  // 2 min run
                    TrainingInterval(type: .walk, duration: 60),  // 1 min walk
                    TrainingInterval(type: .run, duration: 120),  // 2 min run
                    TrainingInterval(type: .walk, duration: 180)  // 3 min cool-down
                ],
                maxPulse: 175
            )
        ]
        
        for program in samplePrograms {
            saveProgram(program)
        }
    }
}
