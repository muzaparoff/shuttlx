//
//  TrainingProgramManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI

@MainActor
class TrainingProgramManager: ObservableObject {
    static let shared = TrainingProgramManager()
    
    @Published var customPrograms: [TrainingProgram] = []
    @Published var selectedProgram: TrainingProgram?
    
    private let userDefaults = UserDefaults.standard
    private let customProgramsKey = "custom_training_programs"
    
    private init() {
        loadCustomPrograms()
    }
    
    // MARK: - Default Programs
    var defaultPrograms: [TrainingProgram] {
        return TrainingProgram.defaultPrograms
    }
    
    // MARK: - All Programs
    var allPrograms: [TrainingProgram] {
        return defaultPrograms + customPrograms
    }
    
    // MARK: - Custom Program Management
    func saveCustomProgram(_ program: TrainingProgram) {
        customPrograms.append(program)
        saveToUserDefaults()
    }
    
    func deleteCustomProgram(_ program: TrainingProgram) {
        customPrograms.removeAll { $0.id == program.id }
        saveToUserDefaults()
    }
    
    func updateCustomProgram(_ program: TrainingProgram) {
        if let index = customPrograms.firstIndex(where: { $0.id == program.id }) {
            customPrograms[index] = program
            saveToUserDefaults()
        }
    }
    
    // MARK: - Persistence
    private func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(customPrograms)
            userDefaults.set(data, forKey: customProgramsKey)
        } catch {
            print("Failed to save custom programs: \(error)")
        }
    }
    
    private func loadCustomPrograms() {
        guard let data = userDefaults.data(forKey: customProgramsKey) else { return }
        
        do {
            customPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
        } catch {
            print("Failed to load custom programs: \(error)")
            customPrograms = []
        }
    }
    
    // MARK: - Program Selection
    func selectProgram(_ program: TrainingProgram) {
        selectedProgram = program
    }
    
    // MARK: - Program Filtering
    func programs(for difficulty: TrainingDifficulty) -> [TrainingProgram] {
        return allPrograms.filter { $0.difficulty == difficulty }
    }
    
    func programs(for heartRateZone: HeartRateZone) -> [TrainingProgram] {
        return allPrograms.filter { $0.targetHeartRateZone == heartRateZone }
    }
    
    // MARK: - Statistics
    var totalCustomPrograms: Int {
        return customPrograms.count
    }
    
    var averageCustomProgramDuration: Double {
        guard !customPrograms.isEmpty else { return 0 }
        return customPrograms.map { $0.totalDuration }.reduce(0, +) / Double(customPrograms.count)
    }
}
