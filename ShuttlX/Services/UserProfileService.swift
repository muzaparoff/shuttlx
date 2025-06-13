//
//  UserProfileService.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import Foundation
import SwiftUI

enum UserProfileError: Error {
    case profileNotFound
    case invalidData
    case saveFailed
    case loadFailed
}

class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    @Published var currentProfile: UserProfile?
    private let userDefaults = UserDefaults.standard
    private let profileKey = "userProfile"
    
    private init() {
        loadProfile()
    }
    
    // MARK: - Profile Management
    
    func saveProfile(_ profile: UserProfile) {
        currentProfile = profile
        
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: profileKey)
            
            // Notify other services about profile update
            NotificationCenter.default.post(
                name: .userProfileUpdated,
                object: profile
            )
            
            print("✅ User profile saved successfully")
        } catch {
            print("❌ Failed to save user profile: \(error.localizedDescription)")
        }
    }
    
    func loadProfile() {
        guard let data = userDefaults.data(forKey: profileKey) else {
            currentProfile = nil
            return
        }
        
        do {
            currentProfile = try JSONDecoder().decode(UserProfile.self, from: data)
            print("✅ User profile loaded successfully")
        } catch {
            print("❌ Failed to load user profile: \(error.localizedDescription)")
            currentProfile = nil
        }
    }
    
    func updateProfile(_ update: (inout UserProfile) -> Void) {
        guard var profile = currentProfile else {
            print("❌ No current profile to update")
            return
        }
        
        update(&profile)
        saveProfile(profile)
    }
    
    func deleteProfile() {
        currentProfile = nil
        userDefaults.removeObject(forKey: profileKey)
        
        NotificationCenter.default.post(
            name: .userProfileDeleted,
            object: nil
        )
        
        print("🗑 User profile deleted")
    }
    
    func getCurrentProfile() async throws -> UserProfile {
        if let profile = currentProfile {
            return profile
        } else {
            throw UserProfileError.profileNotFound
        }
    }
    
    // MARK: - Profile Validation
    
    func isProfileComplete() -> Bool {
        guard let profile = currentProfile else { return false }
        
        return !profile.name.isEmpty &&
               profile.age != nil &&
               profile.height != nil &&
               profile.weight != nil
    }
    
    func getMissingProfileFields() -> [String] {
        guard let profile = currentProfile else {
            return ["All profile information"]
        }
        
        var missing: [String] = []
        
        if profile.name.isEmpty {
            missing.append("Name")
        }
        if profile.age == nil {
            missing.append("Age")
        }
        if profile.height == nil {
            missing.append("Height")
        }
        if profile.weight == nil {
            missing.append("Weight")
        }
        
        return missing
    }
    
    // MARK: - Calculated Properties
    
    var bmi: Double? {
        guard let profile = currentProfile,
              let height = profile.height,
              let weight = profile.weight else {
            return nil
        }
        
        let heightInMeters = height / 100.0 // Convert cm to meters
        return weight / (heightInMeters * heightInMeters)
    }
    
    var estimatedMaxHeartRate: Int? {
        guard let profile = currentProfile,
              let age = profile.age else {
            return nil
        }
        
        return 220 - age
    }
    
    var targetHeartRateZones: [String: ClosedRange<Int>]? {
        guard let maxHR = estimatedMaxHeartRate else { return nil }
        
        return [
            "Recovery": 50...60,
            "Easy": 60...70,
            "Moderate": 70...80,
            "Hard": 80...90,
            "Maximum": 90...100
        ].mapValues { range in
            let lower = Int(Double(maxHR) * Double(range.lowerBound) / 100.0)
            let upper = Int(Double(maxHR) * Double(range.upperBound) / 100.0)
            return lower...upper
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
    static let userProfileDeleted = Notification.Name("userProfileDeleted")
}

// MARK: - UserProfile Extensions

extension UserProfile {
    var isComplete: Bool {
        return !name.isEmpty &&
               age != nil &&
               height != nil &&
               weight != nil
    }
    
    var displayAge: String {
        guard let age = age else { return "Not set" }
        return "\(age) years"
    }
    
    var displayHeight: String {
        guard let height = height else { return "Not set" }
        return "\(Int(height)) cm"
    }
    
    var displayWeight: String {
        guard let weight = weight else { return "Not set" }
        return "\(Int(weight)) kg"
    }
    
    var displayBMI: String {
        guard let height = height,
              let weight = weight else {
            return "Not available"
        }
        
        let heightInMeters = height / 100.0
        let bmi = weight / (heightInMeters * heightInMeters)
        return String(format: "%.1f", bmi)
    }
}

// MARK: - Training Program Manager
// Added here temporarily since TrainingProgramManager.swift is not in the build target

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
        // Using the default programs from TrainingModels.swift
        return [
            TrainingProgram(
                name: "Beginner 5K Builder",
                distance: 5.0,
                runInterval: 3.0,
                walkInterval: 2.0,
                difficulty: .beginner,
                description: "Perfect for starting your running journey. Gentle intervals to build endurance.",
                estimatedCalories: 250,
                targetHeartRateZone: .zone2
            ),
            TrainingProgram(
                name: "HIIT Power Blast",
                distance: 3.0,
                runInterval: 1.0,
                walkInterval: 1.0,
                difficulty: .intermediate,
                description: "High-intensity interval training for maximum calorie burn and fitness gains.",
                estimatedCalories: 300,
                targetHeartRateZone: .zone4
            ),
            TrainingProgram(
                name: "Endurance Challenge",
                distance: 10.0,
                runInterval: 5.0,
                walkInterval: 1.0,
                difficulty: .advanced,
                description: "Build serious endurance with longer running intervals and minimal rest.",
                estimatedCalories: 500,
                targetHeartRateZone: .zone3
            )
        ]
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
    
    func deleteCustomProgramById(_ id: String) {
        customPrograms.removeAll { $0.id.uuidString == id }
        saveToUserDefaults()
    }
    
    func updateCustomProgram(_ program: TrainingProgram) {
        if let index = customPrograms.firstIndex(where: { $0.id == program.id }) {
            customPrograms[index] = program
            saveToUserDefaults()
        }
    }
    
    // MARK: - Persistence
    func saveToUserDefaults() {
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
