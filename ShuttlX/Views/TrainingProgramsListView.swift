//
//  TrainingProgramsListView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI

struct TrainingProgramsListView: View {
    @StateObject private var programManager = TrainingProgramManager.shared
    @State private var showingBuilder = false
    @State private var searchText = ""
    @State private var selectedDifficulty: TrainingDifficulty?
    @State private var showingProgramDetail: TrainingProgram?
    
    var filteredPrograms: [TrainingProgram] {
        var programs = programManager.allPrograms
        
        if !searchText.isEmpty {
            programs = programs.filter { program in
                program.name.localizedCaseInsensitiveContains(searchText) ||
                program.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let difficulty = selectedDifficulty {
            programs = programs.filter { $0.difficulty == difficulty }
        }
        
        return programs.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                headerSection
                
                // Search and filter
                searchAndFilterSection
                
                // Programs list
                programsList
            }
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color.red.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Training Programs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingBuilder = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                TrainingProgramBuilderView()
            }
            .sheet(item: $showingProgramDetail) { program in
                TrainingProgramDetailView(program: program)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatBubble(
                    title: "Total Programs",
                    value: "\(programManager.allPrograms.count)",
                    icon: "list.bullet.circle.fill",
                    color: .orange
                )
                
                StatBubble(
                    title: "Custom Programs",
                    value: "\(programManager.totalCustomPrograms)",
                    icon: "star.circle.fill",
                    color: .blue
                )
                
                StatBubble(
                    title: "Avg Duration",
                    value: "\(Int(programManager.averageCustomProgramDuration))m",
                    icon: "clock.circle.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.8))
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search programs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            
            // Difficulty filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    DifficultyFilterButton(
                        title: "All",
                        isSelected: selectedDifficulty == nil,
                        color: .gray
                    ) {
                        selectedDifficulty = nil
                    }
                    
                    ForEach(TrainingDifficulty.allCases, id: \.self) { difficulty in
                        DifficultyFilterButton(
                            title: difficulty.rawValue.capitalized,
                            isSelected: selectedDifficulty == difficulty,
                            color: difficulty.color
                        ) {
                            selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Programs List
    private var programsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPrograms) { program in
                    TrainingProgramCard(program: program) {
                        showingProgramDetail = program
                    }
                }
                
                if filteredPrograms.isEmpty {
                    EmptyStateView(
                        title: searchText.isEmpty ? "No Programs" : "No Results",
                        subtitle: searchText.isEmpty ? "Create your first training program" : "Try adjusting your search or filters",
                        systemImage: searchText.isEmpty ? "plus.circle" : "magnifyingglass"
                    )
                    .padding(.top, 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Supporting Views

struct StatBubble: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct DifficultyFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? color.opacity(0.2) : Color.white.opacity(0.8)
                )
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
    }
}

struct TrainingProgramCard: View {
    let program: TrainingProgram
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if !program.description.isEmpty {
                            Text(program.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: program.difficulty.icon)
                            .font(.title2)
                            .foregroundColor(program.difficulty.color)
                        
                        Text(program.difficulty.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(program.difficulty.color)
                    }
                }
                
                // Stats
                HStack(spacing: 20) {
                    StatItem(
                        icon: "figure.run.circle.fill",
                        value: "\(String(format: "%.1f", program.distance)) km",
                        color: .orange
                    )
                    
                    StatItem(
                        icon: "clock.fill",
                        value: "\(Int(program.totalDuration)) min",
                        color: .blue
                    )
                    
                    StatItem(
                        icon: "flame.fill",
                        value: "\(program.estimatedCalories)",
                        color: .red
                    )
                    
                    Spacer()
                    
                    if program.isCustom {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    TrainingProgramsListView()
}
