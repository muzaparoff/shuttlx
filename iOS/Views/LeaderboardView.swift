import SwiftUI
import Charts

struct LeaderboardView: View {
    @EnvironmentObject var socialService: SocialService
    @StateObject private var viewModel: LeaderboardViewModel
    @State private var selectedTimeframe: LeaderboardTimeframe = .weekly
    @State private var selectedCategory: LeaderboardCategory = .overall
    @State private var showingFilters = false
    
    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(socialService: socialService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
                headerView
                
                // Category picker
                categoryPicker
                
                // Leaderboard content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.leaderboardEntries.isEmpty {
                            emptyStateView
                        } else {
                            leaderboardContent
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshLeaderboard()
                }
            }
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                LeaderboardFiltersView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadLeaderboard(timeframe: selectedTimeframe, category: selectedCategory)
            }
            .onChange(of: selectedTimeframe) { newValue in
                viewModel.loadLeaderboard(timeframe: newValue, category: selectedCategory)
            }
            .onChange(of: selectedCategory) { newValue in
                viewModel.loadLeaderboard(timeframe: selectedTimeframe, category: newValue)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Timeframe picker
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(LeaderboardTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Current user position
            if let userPosition = viewModel.currentUserPosition {
                currentUserPositionView(userPosition)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LeaderboardCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: category.iconName)
                                .font(.title2)
                            
                            Text(category.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedCategory == category ? Color.blue : Color(.systemGray6))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var leaderboardContent: some View {
        LazyVStack(spacing: 0) {
            // Top 3 podium
            if viewModel.leaderboardEntries.count >= 3 {
                podiumView
                    .padding(.vertical)
            }
            
            // Rest of the leaderboard
            ForEach(Array(viewModel.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                if index >= 3 {
                    LeaderboardRowView(
                        entry: entry,
                        rank: index + 1,
                        category: selectedCategory,
                        isCurrentUser: entry.userID == viewModel.currentUserID
                    )
                    .padding(.horizontal)
                }
            }
            
            // Load more button
            if viewModel.hasMoreEntries {
                Button("Load More") {
                    viewModel.loadMoreEntries()
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }
    
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Second place
            if viewModel.leaderboardEntries.count > 1 {
                podiumPosition(entry: viewModel.leaderboardEntries[1], rank: 2, height: 80)
            }
            
            // First place
            if viewModel.leaderboardEntries.count > 0 {
                podiumPosition(entry: viewModel.leaderboardEntries[0], rank: 1, height: 100)
            }
            
            // Third place
            if viewModel.leaderboardEntries.count > 2 {
                podiumPosition(entry: viewModel.leaderboardEntries[2], rank: 3, height: 60)
            }
        }
        .padding(.horizontal)
    }
    
    private func podiumPosition(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            // User avatar
            AsyncImage(url: URL(string: entry.user.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Text(entry.user.initials)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(rankColor(rank), lineWidth: 3)
            )
            
            // Rank badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(rankColor(rank))
                .clipShape(Circle())
                .offset(y: -45)
            
            // User name
            Text(entry.user.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .offset(y: -20)
            
            // Score
            Text(selectedCategory.formatValue(entry.value))
                .font(.caption2)
                .foregroundColor(.secondary)
                .offset(y: -20)
            
            // Podium base
            Rectangle()
                .fill(rankColor(rank).opacity(0.3))
                .frame(width: 60, height: height)
                .cornerRadius(8, corners: [.topLeft, .topRight])
        }
    }
    
    private func currentUserPositionView(_ position: LeaderboardPosition) -> some View {
        HStack {
            Text("Your Rank:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("#\(position.rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                if let change = position.change {
                    Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                        .font(.caption)
                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : .secondary)
                    
                    if change != 0 {
                        Text("\(abs(change))")
                            .font(.caption)
                            .foregroundColor(change > 0 ? .green : .red)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading leaderboard...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("No Rankings Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete some workouts to appear on the leaderboard!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .blue
        }
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let rank: Int
    let category: LeaderboardCategory
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(isCurrentUser ? .blue : .primary)
                .frame(width: 40, alignment: .leading)
            
            // User avatar
            AsyncImage(url: URL(string: entry.user.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Text(entry.user.initials)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user.displayName)
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .blue : .primary)
                
                if let location = entry.user.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Statistics
            VStack(alignment: .trailing, spacing: 2) {
                Text(category.formatValue(entry.value))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentUser ? .blue : .primary)
                
                if let change = entry.change {
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                            .font(.caption2)
                        
                        Text(change > 0 ? "+\(change)" : "\(change)")
                            .font(.caption2)
                    }
                    .foregroundColor(change > 0 ? .green : change < 0 ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentUser ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 1)
        )
    }
}

struct LeaderboardFiltersView: View {
    @ObservedObject var viewModel: LeaderboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    Picker("Scope", selection: $viewModel.locationScope) {
                        ForEach(LocationScope.allCases, id: \.self) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Age Group") {
                    Picker("Age Range", selection: $viewModel.ageGroup) {
                        Text("All Ages").tag(AgeGroup?.none)
                        ForEach(AgeGroup.allCases, id: \.self) { group in
                            Text(group.displayName).tag(AgeGroup?.some(group))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Gender") {
                    Picker("Gender", selection: $viewModel.genderFilter) {
                        Text("All").tag(GenderFilter?.none)
                        ForEach(GenderFilter.allCases, id: \.self) { gender in
                            Text(gender.displayName).tag(GenderFilter?.some(gender))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Friends Only") {
                    Toggle("Show Friends Only", isOn: $viewModel.friendsOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        viewModel.resetFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Enums

enum LeaderboardTimeframe: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .yearly: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

enum LeaderboardCategory: String, CaseIterable {
    case overall = "overall"
    case distance = "distance"
    case duration = "duration"
    case workouts = "workouts"
    case calories = "calories"
    case pace = "pace"
    case consistency = "consistency"
    
    var displayName: String {
        switch self {
        case .overall: return "Overall"
        case .distance: return "Distance"
        case .duration: return "Duration"
        case .workouts: return "Workouts"
        case .calories: return "Calories"
        case .pace: return "Pace"
        case .consistency: return "Consistency"
        }
    }
    
    var iconName: String {
        switch self {
        case .overall: return "trophy.fill"
        case .distance: return "location.fill"
        case .duration: return "clock.fill"
        case .workouts: return "figure.run"
        case .calories: return "flame.fill"
        case .pace: return "speedometer"
        case .consistency: return "calendar"
        }
    }
    
    func formatValue(_ value: Double) -> String {
        switch self {
        case .overall:
            return "\(Int(value)) pts"
        case .distance:
            return String(format: "%.1f km", value)
        case .duration:
            let hours = Int(value) / 3600
            let minutes = (Int(value) % 3600) / 60
            return "\(hours)h \(minutes)m"
        case .workouts:
            return "\(Int(value))"
        case .calories:
            return "\(Int(value)) cal"
        case .pace:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return "\(minutes):\(String(format: "%02d", seconds))/km"
        case .consistency:
            return "\(Int(value))%"
        }
    }
}

enum LocationScope: String, CaseIterable {
    case global = "global"
    case country = "country"
    case city = "city"
    case nearby = "nearby"
    
    var displayName: String {
        switch self {
        case .global: return "Global"
        case .country: return "Country"
        case .city: return "City"
        case .nearby: return "Nearby"
        }
    }
}

enum AgeGroup: String, CaseIterable {
    case teens = "13-19"
    case twenties = "20-29"
    case thirties = "30-39"
    case forties = "40-49"
    case fifties = "50-59"
    case sixties = "60+"
    
    var displayName: String {
        return rawValue
    }
}

enum GenderFilter: String, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

#Preview {
    LeaderboardView()
}
