//
//  WorkoutTemplatesViewModel.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import SwiftUI

@MainActor
class WorkoutTemplatesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var templates: [WorkoutTemplate] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: TemplateFilter = .all
    @Published var sortBy: SortOption = .name
    @Published var showCreateTemplate: Bool = false
    
    // MARK: - Computed Properties
    var featuredTemplates: [WorkoutTemplate] {
        templates.filter { $0.isFeatured }.prefix(5).map { $0 }
    }
    
    var filteredTemplates: [WorkoutTemplate] {
        var filtered = templates
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.notes.localizedCaseInsensitiveContains(searchText) ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply category filter
        switch selectedFilter {
        case .all:
            break
        case .shuttleRun:
            filtered = filtered.filter { $0.type == .shuttleRun }
        case .hiit:
            filtered = filtered.filter { $0.type == .hiit }
        case .intervals:
            filtered = filtered.filter { $0.type == .intervals }
        case .beginner:
            filtered = filtered.filter { $0.difficulty == .beginner }
        case .intermediate:
            filtered = filtered.filter { $0.difficulty == .intermediate }
        case .advanced:
            filtered = filtered.filter { $0.difficulty == .advanced || $0.difficulty == .expert }
        }
        
        // Apply sorting
        switch sortBy {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .duration:
            filtered.sort { $0.estimatedDuration < $1.estimatedDuration }
        case .difficulty:
            filtered.sort { $0.difficulty.sortValue < $1.difficulty.sortValue }
        case .recent:
            filtered.sort { $0.createdAt > $1.createdAt }
        }
        
        return filtered
    }
    
    // MARK: - Methods
    func loadTemplates() {
        // Load from local storage, predefined templates, and cloud
        templates = defaultTemplates + loadCustomTemplates()
    }
    
    func addTemplate(_ template: WorkoutTemplate) {
        templates.append(template)
        saveCustomTemplates()
    }
    
    func deleteTemplate(_ template: WorkoutTemplate) {
        templates.removeAll { $0.id == template.id }
        saveCustomTemplates()
    }
    
    // MARK: - Private Methods
    private func loadCustomTemplates() -> [WorkoutTemplate] {
        // Load from UserDefaults or Core Data
        // For now, return empty array
        return []
    }
    
    private func saveCustomTemplates() {
        // Save custom templates to UserDefaults or Core Data
        let customTemplates = templates.filter { !$0.isBuiltIn }
        // Implementation would save to persistent storage
        print("Saving \(customTemplates.count) custom templates")
    }
    
    // MARK: - Default Templates
    private var defaultTemplates: [WorkoutTemplate] {
        [
            // Shuttle Run Templates
            WorkoutTemplate(
                name: "Beginner Shuttle Run",
                type: .shuttleRun,
                difficulty: .beginner,
                intervals: [
                    WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Light jogging and dynamic stretching"),
                    WorkoutInterval(type: .work, duration: 15, intensity: .moderate, distance: 15, notes: "15m shuttle run"),
                    WorkoutInterval(type: .rest, duration: 45, intensity: .low, distance: nil, notes: "Walk back and prepare"),
                    WorkoutInterval(type: .work, duration: 15, intensity: .moderate, distance: 15, notes: "15m shuttle run"),
                    WorkoutInterval(type: .rest, duration: 45, intensity: .low, distance: nil, notes: "Walk back and prepare"),
                    WorkoutInterval(type: .work, duration: 15, intensity: .moderate, distance: 15, notes: "15m shuttle run"),
                    WorkoutInterval(type: .rest, duration: 45, intensity: .low, distance: nil, notes: "Walk back and prepare"),
                    WorkoutInterval(type: .work, duration: 15, intensity: .moderate, distance: 15, notes: "15m shuttle run"),
                    WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Walking and static stretching")
                ],
                notes: "Perfect for beginners to learn shuttle run technique and build basic fitness",
                tags: ["beginner", "shuttle", "technique", "fitness"],
                isFeatured: true,
                isBuiltIn: true
            ),
            
            WorkoutTemplate(
                name: "Pro Shuttle Challenge",
                type: .shuttleRun,
                difficulty: .expert,
                intervals: [
                    WorkoutInterval(type: .warmup, duration: 600, intensity: .moderate, distance: nil, notes: "Thorough warmup with dynamic movements"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .rest, duration: 40, intensity: .low, distance: nil, notes: "Active recovery"),
                    WorkoutInterval(type: .work, duration: 20, intensity: .maximum, distance: 20, notes: "20m shuttle - maximum effort"),
                    WorkoutInterval(type: .cooldown, duration: 600, intensity: .low, distance: nil, notes: "Extended cooldown and recovery")
                ],
                notes: "Elite level shuttle run workout for advanced athletes",
                tags: ["expert", "shuttle", "elite", "challenge"],
                isFeatured: true,
                isBuiltIn: true
            ),
            
            // HIIT Templates
            WorkoutTemplate(
                name: "Quick HIIT Blast",
                type: .hiit,
                difficulty: .beginner,
                intervals: [
                    WorkoutInterval(type: .warmup, duration: 180, intensity: .low, distance: nil, notes: "Light cardio warmup"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .high, distance: nil, notes: "High intensity work"),
                    WorkoutInterval(type: .rest, duration: 30, intensity: .low, distance: nil, notes: "Active rest"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .high, distance: nil, notes: "High intensity work"),
                    WorkoutInterval(type: .rest, duration: 30, intensity: .low, distance: nil, notes: "Active rest"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .high, distance: nil, notes: "High intensity work"),
                    WorkoutInterval(type: .rest, duration: 30, intensity: .low, distance: nil, notes: "Active rest"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .high, distance: nil, notes: "High intensity work"),
                    WorkoutInterval(type: .cooldown, duration: 180, intensity: .low, distance: nil, notes: "Cool down and stretch")
                ],
                notes: "Quick and effective HIIT workout for busy schedules",
                tags: ["hiit", "quick", "beginner", "cardio"],
                isFeatured: true,
                isBuiltIn: true
            ),
            
            WorkoutTemplate(
                name: "Tabata Protocol",
                type: .hiit,
                difficulty: .advanced,
                intervals: generateTabataIntervals(),
                notes: "Classic Tabata protocol - 4 minutes of maximum effort",
                tags: ["tabata", "hiit", "advanced", "protocol"],
                isFeatured: true,
                isBuiltIn: true
            ),
            
            // Interval Templates
            WorkoutTemplate(
                name: "Pyramid Intervals",
                type: .intervals,
                difficulty: .intermediate,
                intervals: [
                    WorkoutInterval(type: .warmup, duration: 300, intensity: .low, distance: nil, notes: "Gradual warmup"),
                    WorkoutInterval(type: .work, duration: 60, intensity: .moderate, distance: nil, notes: "1 minute effort"),
                    WorkoutInterval(type: .rest, duration: 60, intensity: .low, distance: nil, notes: "1 minute recovery"),
                    WorkoutInterval(type: .work, duration: 120, intensity: .high, distance: nil, notes: "2 minute effort"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "90 second recovery"),
                    WorkoutInterval(type: .work, duration: 180, intensity: .high, distance: nil, notes: "3 minute effort"),
                    WorkoutInterval(type: .rest, duration: 120, intensity: .low, distance: nil, notes: "2 minute recovery"),
                    WorkoutInterval(type: .work, duration: 120, intensity: .high, distance: nil, notes: "2 minute effort"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "90 second recovery"),
                    WorkoutInterval(type: .work, duration: 60, intensity: .moderate, distance: nil, notes: "1 minute effort"),
                    WorkoutInterval(type: .cooldown, duration: 300, intensity: .low, distance: nil, notes: "Gradual cooldown")
                ],
                notes: "Pyramid structure builds endurance and mental toughness",
                tags: ["intervals", "pyramid", "endurance", "intermediate"],
                isFeatured: false,
                isBuiltIn: true
            ),
            
            WorkoutTemplate(
                name: "Speed Intervals",
                type: .intervals,
                difficulty: .advanced,
                intervals: [
                    WorkoutInterval(type: .warmup, duration: 600, intensity: .moderate, distance: nil, notes: "Thorough speed preparation"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .maximum, distance: nil, notes: "30s sprint"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "Full recovery"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .maximum, distance: nil, notes: "30s sprint"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "Full recovery"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .maximum, distance: nil, notes: "30s sprint"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "Full recovery"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .maximum, distance: nil, notes: "30s sprint"),
                    WorkoutInterval(type: .rest, duration: 90, intensity: .low, distance: nil, notes: "Full recovery"),
                    WorkoutInterval(type: .work, duration: 30, intensity: .maximum, distance: nil, notes: "30s sprint"),
                    WorkoutInterval(type: .cooldown, duration: 600, intensity: .low, distance: nil, notes: "Extended recovery")
                ],
                notes: "High-intensity speed work for developing maximum velocity",
                tags: ["speed", "sprint", "intervals", "advanced"],
                isFeatured: false,
                isBuiltIn: true
            )
        ]
    }
    
    private func generateTabataIntervals() -> [WorkoutInterval] {
        var intervals: [WorkoutInterval] = []
        
        // Warmup
        intervals.append(WorkoutInterval(
            type: .warmup,
            duration: 300,
            intensity: .moderate,
            distance: nil,
            notes: "Tabata warmup - prepare for maximum effort"
        ))
        
        // 8 rounds of 20s work / 10s rest
        for i in 0..<8 {
            intervals.append(WorkoutInterval(
                type: .work,
                duration: 20,
                intensity: .maximum,
                distance: nil,
                notes: "Tabata round \(i + 1) - ALL OUT!"
            ))
            
            if i < 7 { // No rest after last round
                intervals.append(WorkoutInterval(
                    type: .rest,
                    duration: 10,
                    intensity: .low,
                    distance: nil,
                    notes: "Brief rest - prepare for next round"
                ))
            }
        }
        
        // Cooldown
        intervals.append(WorkoutInterval(
            type: .cooldown,
            duration: 300,
            intensity: .low,
            distance: nil,
            notes: "Tabata recovery - you earned it!"
        ))
        
        return intervals
    }
}

// MARK: - Supporting Enums

enum TemplateFilter: String, CaseIterable {
    case all = "All"
    case shuttleRun = "Shuttle Run"
    case hiit = "HIIT"
    case intervals = "Intervals"
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum SortOption: String, CaseIterable {
    case name = "Name"
    case duration = "Duration"
    case difficulty = "Difficulty"
    case recent = "Recent"
}

// MARK: - Extensions

extension WorkoutTemplate {
    var isFeatured: Bool {
        tags.contains("featured") || isBuiltIn
    }
    
    var isBuiltIn: Bool = false
    
    init(name: String, type: WorkoutType, difficulty: DifficultyLevel, intervals: [WorkoutInterval], notes: String, tags: [String], isFeatured: Bool = false, isBuiltIn: Bool = false) {
        self.name = name
        self.type = type
        self.difficulty = difficulty
        self.intervals = intervals
        self.notes = notes
        self.tags = tags
    }
}

extension DifficultyLevel {
    var sortValue: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .expert: return 3
        }
    }
}

#Preview {
    ContentView()
}
