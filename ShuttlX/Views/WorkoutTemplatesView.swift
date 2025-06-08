//
//  WorkoutTemplatesView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct WorkoutTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutTemplatesViewModel()
    let onTemplateSelected: (WorkoutTemplate) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Search Bar
                    searchSection
                    
                    // Filter Chips
                    filterSection
                    
                    // Featured Templates
                    if !viewModel.featuredTemplates.isEmpty {
                        featuredSection
                    }
                    
                    // All Templates
                    templatesSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New") {
                        viewModel.showCreateTemplate = true
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search templates...")
            .onAppear {
                viewModel.loadTemplates()
            }
            .sheet(isPresented: $viewModel.showCreateTemplate) {
                CreateTemplateView { template in
                    viewModel.addTemplate(template)
                }
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.searchText.isEmpty {
                HStack {
                    Text("Search Results")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(viewModel.filteredTemplates.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: viewModel.selectedFilter == .all,
                    action: { viewModel.selectedFilter = .all }
                )
                
                FilterChip(
                    title: "Shuttle Run",
                    isSelected: viewModel.selectedFilter == .shuttleRun,
                    action: { viewModel.selectedFilter = .shuttleRun }
                )
                
                FilterChip(
                    title: "HIIT",
                    isSelected: viewModel.selectedFilter == .hiit,
                    action: { viewModel.selectedFilter = .hiit }
                )
                
                FilterChip(
                    title: "Intervals",
                    isSelected: viewModel.selectedFilter == .intervals,
                    action: { viewModel.selectedFilter = .intervals }
                )
                
                FilterChip(
                    title: "Beginner",
                    isSelected: viewModel.selectedFilter == .beginner,
                    action: { viewModel.selectedFilter = .beginner }
                )
                
                FilterChip(
                    title: "Advanced",
                    isSelected: viewModel.selectedFilter == .advanced,
                    action: { viewModel.selectedFilter = .advanced }
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Templates")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.featuredTemplates) { template in
                        FeaturedTemplateCard(template: template) {
                            onTemplateSelected(template)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Templates Section
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(viewModel.searchText.isEmpty ? "All Templates" : "Search Results")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Sort by Name") { viewModel.sortBy = .name }
                    Button("Sort by Duration") { viewModel.sortBy = .duration }
                    Button("Sort by Difficulty") { viewModel.sortBy = .difficulty }
                    Button("Sort by Recent") { viewModel.sortBy = .recent }
                } label: {
                    HStack {
                        Text("Sort")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTemplates) { template in
                    TemplateRowCard(template: template) {
                        onTemplateSelected(template)
                        dismiss()
                    }
                }
            }
            
            if viewModel.filteredTemplates.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Templates Found",
                    subtitle: viewModel.searchText.isEmpty ? 
                        "Create your first template to get started" : 
                        "Try adjusting your search or filters"
                )
                .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(16)
        }
    }
}

struct FeaturedTemplateCard: View {
    let template: WorkoutTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: template.type.icon)
                        .font(.title2)
                        .foregroundColor(template.difficulty.color)
                    
                    Spacer()
                    
                    DifficultyBadge(difficulty: template.difficulty)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(template.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    HStack {
                        StatBadge(
                            icon: "clock",
                            text: "\(template.estimatedDuration) min"
                        )
                        
                        StatBadge(
                            icon: "repeat",
                            text: "\(template.intervals.count)"
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 200, height: 150)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct TemplateRowCard: View {
    let template: WorkoutTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: template.type.icon)
                    .font(.title2)
                    .foregroundColor(template.difficulty.color)
                    .frame(width: 40, height: 40)
                    .background(template.difficulty.color.opacity(0.1))
                    .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(template.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        StatBadge(
                            icon: "clock",
                            text: "\(template.estimatedDuration) min"
                        )
                        
                        StatBadge(
                            icon: "repeat",
                            text: "\(template.intervals.count)"
                        )
                        
                        DifficultyBadge(difficulty: template.difficulty)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct StatBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Extensions

extension WorkoutTemplate {
    var estimatedDuration: Int {
        Int(intervals.reduce(0) { $0 + $1.duration } / 60)
    }
}

#Preview {
    WorkoutTemplatesView { template in
        print("Selected template: \(template.name)")
    }
}
