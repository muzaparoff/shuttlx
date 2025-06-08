import SwiftUI
import AVFoundation

struct FormAnalysisView: View {
    @StateObject private var formAnalysisManager = FormAnalysisManager()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab View
                TabView(selection: $selectedTab) {
                    // Real-time Analysis
                    RealTimeFormView()
                        .environmentObject(formAnalysisManager)
                        .tag(0)
                    
                    // Form Insights
                    FormInsightsView()
                        .environmentObject(formAnalysisManager)
                        .tag(1)
                    
                    // Improvement Tips
                    ImprovementTipsView()
                        .environmentObject(formAnalysisManager)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom Tab Bar
                customTabBar
            }
            .navigationTitle("Form Analysis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingHistory = true }) {
                            Label("Analysis History", systemImage: "clock")
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            FormAnalysisHistoryView()
                .environmentObject(formAnalysisManager)
        }
        .sheet(isPresented: $showingSettings) {
            FormAnalysisSettingsView()
                .environmentObject(formAnalysisManager)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Current Score
            if formAnalysisManager.isAnalyzing {
                VStack(spacing: 8) {
                    Text("Current Form Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(formAnalysisManager.currentFormScore * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color.forScore(formAnalysisManager.currentFormScore))
                    
                    Text(scoreDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("AI Form Analysis")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Get real-time feedback on your running form")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Analysis Status
            HStack(spacing: 12) {
                Circle()
                    .fill(formAnalysisManager.isAnalyzing ? .green : .gray)
                    .frame(width: 8, height: 8)
                
                Text(formAnalysisManager.isAnalyzing ? "Analyzing" : "Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if formAnalysisManager.isAnalyzing {
                    Spacer()
                    
                    Button("Stop") {
                        formAnalysisManager.stopFormAnalysis()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                title: "Live",
                icon: "video",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabBarButton(
                title: "Insights",
                icon: "chart.line.uptrend.xyaxis",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabBarButton(
                title: "Tips",
                icon: "lightbulb",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var scoreDescription: String {
        let score = formAnalysisManager.currentFormScore
        switch score {
        case 0.9...1.0: return "Excellent Form"
        case 0.8..<0.9: return "Very Good"
        case 0.7..<0.8: return "Good Form"
        case 0.6..<0.7: return "Fair Form"
        default: return "Needs Improvement"
        }
    }
}

struct TabBarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

struct RealTimeFormView: View {
    @EnvironmentObject var formAnalysisManager: FormAnalysisManager
    @State private var showingCamera = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Camera/Analysis Section
                if formAnalysisManager.isAnalyzing {
                    cameraAnalysisSection
                } else {
                    startAnalysisSection
                }
                
                // Real-time Feedback
                if !formAnalysisManager.formFeedback.isEmpty {
                    realTimeFeedbackSection
                }
                
                // Form Aspects
                if let analysis = formAnalysisManager.realTimeAnalysis {
                    formAspectsSection(analysis.aspects)
                }
            }
            .padding()
        }
    }
    
    private var startAnalysisSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "camera")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Start Form Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Position yourself in front of the camera and start your workout to get real-time form feedback.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                formAnalysisManager.startFormAnalysis()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Analysis")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var cameraAnalysisSection: some View {
        VStack(spacing: 16) {
            // Camera preview placeholder
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(height: 300)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("Camera Active")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("AI analyzing your form...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
                .cornerRadius(12)
            
            // Live form score
            HStack {
                VStack(alignment: .leading) {
                    Text("Live Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(formAnalysisManager.currentFormScore * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.forScore(formAnalysisManager.currentFormScore))
                }
                
                Spacer()
                
                Button("Stop Analysis") {
                    formAnalysisManager.stopFormAnalysis()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var realTimeFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Feedback")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(formAnalysisManager.formFeedback.indices, id: \.self) { index in
                let feedback = formAnalysisManager.formFeedback[index]
                
                HStack(spacing: 12) {
                    Image(systemName: feedback.type.icon)
                        .foregroundColor(feedback.type.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feedback.message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(feedback.suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(feedback.type.color.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func formAspectsSection(_ aspects: [FormAspect]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(aspects.indices, id: \.self) { index in
                let aspect = aspects[index]
                
                VStack(spacing: 8) {
                    HStack {
                        Text(aspect.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(aspect.scoreText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(aspect.scoreColor.opacity(0.2))
                            .foregroundColor(aspect.scoreColor)
                            .cornerRadius(8)
                    }
                    
                    ProgressView(value: aspect.score)
                        .progressViewStyle(LinearProgressViewStyle(tint: aspect.scoreColor))
                    
                    HStack {
                        Text("Ideal: \(aspect.ideal)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(aspect.score * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(aspect.scoreColor)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct FormInsightsView: View {
    @EnvironmentObject var formAnalysisManager: FormAnalysisManager
    @State private var selectedTimeframe: Timeframe = .week
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Timeframe Selector
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Progress Trend
                progressTrendSection
                
                // Strengths and Weaknesses
                strengthsWeaknessesSection
                
                // Detailed Analysis
                detailedAnalysisSection
            }
            .padding()
        }
    }
    
    private var progressTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress Trend")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Mock chart data
            let trendData = formAnalysisManager.getFormTrend(days: timeframeDays)
            
            if trendData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start analyzing your form to see progress trends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 150)
            } else {
                // Chart placeholder
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 150)
                    .overlay(
                        Text("Form Score Trend Chart")
                            .foregroundColor(.blue)
                    )
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var strengthsWeaknessesSection: some View {
        HStack(spacing: 16) {
            // Strengths
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Strengths")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                if let strongest = formAnalysisManager.getStrongestAspect() {
                    Text(strongest.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(Int(strongest.score * 100))% average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Keep analyzing to identify strengths")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // Weaknesses
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Focus Areas")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                if let weakest = formAnalysisManager.getWeakestAspect() {
                    Text(weakest.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(Int(weakest.score * 100))% average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Keep analyzing to identify areas for improvement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var detailedAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                AnalysisSummaryRow(
                    title: "Total Sessions",
                    value: "\(formAnalysisManager.analysisHistory.count)",
                    icon: "calendar"
                )
                
                AnalysisSummaryRow(
                    title: "Average Score",
                    value: averageScoreText,
                    icon: "chart.bar"
                )
                
                AnalysisSummaryRow(
                    title: "Improvement Areas",
                    value: "\(totalImprovements)",
                    icon: "arrow.up.circle"
                )
                
                AnalysisSummaryRow(
                    title: "Consistency",
                    value: "Good", // Mock value
                    icon: "checkmark.seal"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var timeframeDays: Int {
        switch selectedTimeframe {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
    
    private var averageScoreText: String {
        guard !formAnalysisManager.analysisHistory.isEmpty else { return "N/A" }
        
        let average = formAnalysisManager.analysisHistory
            .map { $0.averageScore }
            .reduce(0, +) / Double(formAnalysisManager.analysisHistory.count)
        
        return "\(Int(average * 100))%"
    }
    
    private var totalImprovements: Int {
        return formAnalysisManager.analysisHistory
            .flatMap { $0.improvements }
            .count
    }
}

struct AnalysisSummaryRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ImprovementTipsView: View {
    @EnvironmentObject var formAnalysisManager: FormAnalysisManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Personalized Tips
                if !formAnalysisManager.analysisHistory.isEmpty {
                    personalizedTipsSection
                }
                
                // General Tips
                generalTipsSection
                
                // Exercise Recommendations
                exerciseRecommendationsSection
            }
            .padding()
        }
    }
    
    private var personalizedTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            let allImprovements = formAnalysisManager.analysisHistory
                .flatMap { $0.improvements }
            
            ForEach(Array(allImprovements.prefix(3).enumerated()), id: \.offset) { index, improvement in
                ImprovementTipCard(suggestion: improvement)
            }
            
            if allImprovements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    
                    Text("Start analyzing your form to get personalized tips")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var generalTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General Form Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            let generalTips = [
                GeneralTip(
                    title: "Maintain Proper Posture",
                    description: "Keep your back straight and shoulders relaxed while running",
                    icon: "figure.stand"
                ),
                GeneralTip(
                    title: "Focus on Foot Strike",
                    description: "Land on your forefoot or midfoot for better efficiency",
                    icon: "figure.walk"
                ),
                GeneralTip(
                    title: "Rhythmic Arm Movement",
                    description: "Pump your arms in rhythm with your stride",
                    icon: "hands.clap"
                ),
                GeneralTip(
                    title: "Controlled Turns",
                    description: "Decelerate before turns and accelerate out of them",
                    icon: "arrow.uturn.left"
                )
            ]
            
            ForEach(generalTips.indices, id: \.self) { index in
                GeneralTipCard(tip: generalTips[index])
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var exerciseRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Exercises")
                .font(.headline)
                .fontWeight(.semibold)
            
            let exercises = [
                Exercise(
                    name: "High Knees",
                    description: "Improve leg turnover and running form",
                    duration: "30 seconds x 3 sets",
                    difficulty: "Beginner"
                ),
                Exercise(
                    name: "Butt Kicks",
                    description: "Enhance hamstring flexibility and form",
                    duration: "30 seconds x 3 sets",
                    difficulty: "Beginner"
                ),
                Exercise(
                    name: "A-Skips",
                    description: "Perfect running posture and coordination",
                    duration: "20m x 4 sets",
                    difficulty: "Intermediate"
                ),
                Exercise(
                    name: "Carioca",
                    description: "Improve agility and lateral movement",
                    duration: "20m x 3 sets",
                    difficulty: "Intermediate"
                )
            ]
            
            ForEach(exercises.indices, id: \.self) { index in
                ExerciseCard(exercise: exercises[index])
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ImprovementTipCard: View {
    let suggestion: ImprovementSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: priorityIcon)
                    .foregroundColor(priorityColor)
                
                Text(suggestion.area)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(priorityText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundColor(priorityColor)
                    .cornerRadius(8)
            }
            
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !suggestion.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(suggestion.exercises, id: \.self) { exercise in
                        Text("• \(exercise)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(priorityColor.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var priorityIcon: String {
        switch suggestion.priority {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    private var priorityText: String {
        switch suggestion.priority {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        }
    }
}

struct GeneralTip {
    let title: String
    let description: String
    let icon: String
}

struct GeneralTipCard: View {
    let tip: GeneralTip
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(tip.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct Exercise {
    let name: String
    let description: String
    let duration: String
    let difficulty: String
}

struct ExerciseCard: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(exercise.difficulty)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundColor(difficultyColor)
                    .cornerRadius(8)
            }
            
            Text(exercise.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Duration: \(exercise.duration)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch exercise.difficulty {
        case "Beginner": return .green
        case "Intermediate": return .orange
        case "Advanced": return .red
        default: return .blue
        }
    }
}

struct FormAnalysisHistoryView: View {
    @EnvironmentObject var formAnalysisManager: FormAnalysisManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(formAnalysisManager.analysisHistory) { result in
                    NavigationLink(destination: FormAnalysisDetailView(result: result)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(Int(result.averageScore * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.forScore(result.averageScore))
                            }
                            
                            Text("\(result.sessions.count) analysis sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FormAnalysisDetailView: View {
    let result: FormAnalysisResult
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                VStack(spacing: 12) {
                    Text("\(Int(result.averageScore * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color.forScore(result.averageScore))
                    
                    Text("Average Form Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(result.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Improvements
                if !result.improvements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Improvement Areas")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(result.improvements.indices, id: \.self) { index in
                            ImprovementTipCard(suggestion: result.improvements[index])
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                // Strengths
                if !result.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Strengths")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(result.strengths, id: \.self) { strength in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text(strength)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .navigationTitle("Analysis Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FormAnalysisSettingsView: View {
    @EnvironmentObject var formAnalysisManager: FormAnalysisManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Analysis Settings") {
                    HStack {
                        Text("Feedback Frequency")
                        Spacer()
                        Text("Real-time")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Analysis Quality")
                        Spacer()
                        Text("High")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Voice Feedback", isOn: .constant(true))
                    Toggle("Haptic Feedback", isOn: .constant(true))
                }
                
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Camera Access")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("ShuttlX uses your camera for form analysis. Video is processed locally and not stored or shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Data") {
                    Button("Export Analysis Data") {
                        // Export functionality
                    }
                    
                    Button("Clear Analysis History") {
                        // Clear history
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Form Analysis Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FormAnalysisView()
}
