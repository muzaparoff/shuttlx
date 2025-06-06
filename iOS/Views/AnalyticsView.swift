import SwiftUI
import Charts
import HealthKit

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var selectedMetric: MetricType = .workoutFrequency
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Key Metrics Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        MetricCard(
                            title: "Total Workouts",
                            value: "\(viewModel.totalWorkouts)",
                            change: viewModel.workoutChange,
                            icon: "figure.run"
                        )
                        
                        MetricCard(
                            title: "Total Distance",
                            value: viewModel.formattedTotalDistance,
                            change: viewModel.distanceChange,
                            icon: "location"
                        )
                        
                        MetricCard(
                            title: "Avg Heart Rate",
                            value: "\(Int(viewModel.averageHeartRate)) BPM",
                            change: viewModel.heartRateChange,
                            icon: "heart.fill"
                        )
                        
                        MetricCard(
                            title: "Total Calories",
                            value: "\(Int(viewModel.totalCalories))",
                            change: viewModel.calorieChange,
                            icon: "flame.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Charts Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Performance Trends")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Picker("Metric", selection: $selectedMetric) {
                                ForEach(MetricType.allCases, id: \.self) { metric in
                                    Text(metric.displayName).tag(metric)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Performance Chart
                        Chart(viewModel.chartData) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(.blue.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: selectedPeriod == .week ? 1 : 7))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // Workout Types Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Workout Types")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Chart(viewModel.workoutTypeData) { data in
                            SectorMark(
                                angle: .value("Count", data.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(data.color)
                            .cornerRadius(4)
                        }
                        .frame(height: 200)
                        
                        // Legend
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(viewModel.workoutTypeData, id: \.type) { data in
                                HStack {
                                    Circle()
                                        .fill(data.color)
                                        .frame(width: 12, height: 12)
                                    
                                    Text(data.type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(data.count)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // Recent Achievements
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Achievements")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(viewModel.recentAchievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Analytics")
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .onAppear {
            viewModel.loadData(for: selectedPeriod)
        }
        .onChange(of: selectedPeriod) { period in
            viewModel.loadData(for: period)
        }
        .onChange(of: selectedMetric) { metric in
            viewModel.updateChartData(for: metric)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: Double
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                    
                    Text("\(abs(change), specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack {
            Image(systemName: achievement.iconName)
                .foregroundColor(.orange)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(RelativeDateTimeFormatter().localizedString(for: achievement.earnedDate, relativeTo: Date()))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

enum AnalyticsPeriod: CaseIterable {
    case week, month, threeMonths, year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .year: return "Year"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        }
    }
}

enum MetricType: CaseIterable {
    case workoutFrequency, distance, heartRate, calories, speed
    
    var displayName: String {
        switch self {
        case .workoutFrequency: return "Frequency"
        case .distance: return "Distance"
        case .heartRate: return "Heart Rate"
        case .calories: return "Calories"
        case .speed: return "Speed"
        }
    }
}

struct ChartDataPoint {
    let date: Date
    let value: Double
}

struct WorkoutTypeData {
    let type: WorkoutType
    let count: Int
    let color: Color
}

#Preview {
    AnalyticsView()
}
