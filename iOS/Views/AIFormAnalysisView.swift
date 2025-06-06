//
//  AIFormAnalysisView.swift
//  ShuttlX
//
//  Enhanced AI-powered form analysis interface
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import AVFoundation

struct AIFormAnalysisView: View {
    @StateObject private var aiFormService = AIFormAnalysisService()
    @State private var selectedTab = 0
    @State private var showingPermissions = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Tab Content
                if aiFormService.isModelReady {
                    TabView(selection: $selectedTab) {
                        // Real-time Analysis
                        RealTimeAIAnalysisView()
                            .environmentObject(aiFormService)
                            .tag(0)
                        
                        // Form Insights
                        AIFormInsightsView()
                            .environmentObject(aiFormService)
                            .tag(1)
                        
                        // AI Coaching
                        AICoachingView()
                            .environmentObject(aiFormService)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    modelLoadingSection
                }
                
                // Custom Tab Bar
                if aiFormService.isModelReady {
                    customTabBar
                }
            }
            .navigationTitle("AI Form Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingHistory = true }) {
                            Label("Analysis History", systemImage: "clock.arrow.circlepath")
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Label("AI Settings", systemImage: "brain")
                        }
                        
                        Button(action: { showingPermissions = true }) {
                            Label("Permissions", systemImage: "lock.shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $showingPermissions) {
            CameraPermissionView(permissionStatus: $cameraPermissionStatus)
        }
        .sheet(isPresented: $showingSettings) {
            AIFormAnalysisSettingsView()
                .environmentObject(aiFormService)
        }
        .sheet(isPresented: $showingHistory) {
            AIFormAnalysisHistoryView()
                .environmentObject(aiFormService)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // AI Status Indicator
            HStack {
                Circle()
                    .fill(aiFormService.isAnalyzing ? .green : (aiFormService.isModelReady ? .blue : .orange))
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if aiFormService.isAnalyzing {
                    Text("Confidence: \(Int(aiFormService.confidenceLevel * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            // Current Form Score
            if aiFormService.isAnalyzing {
                VStack(spacing: 8) {
                    Text("AI Form Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(aiFormService.currentFormScore * 100))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text(scoreDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if aiFormService.isModelReady {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("AI Form Coach Ready")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Advanced pose detection and form analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var modelLoadingSection: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 12) {
                Text("Loading AI Models")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Preparing advanced pose detection and form analysis models for optimal performance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                title: "Live AI",
                icon: "camera.viewfinder",
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
                title: "AI Coach",
                icon: "brain.head.profile",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .padding(.horizontal)
    }
    
    private var statusText: String {
        if aiFormService.isAnalyzing {
            return "AI Analyzing Form"
        } else if aiFormService.isModelReady {
            return "AI Models Ready"
        } else {
            return "Loading AI Models"
        }
    }
    
    private var scoreColor: Color {
        let score = aiFormService.currentFormScore
        switch score {
        case 0.9...1.0: return .green
        case 0.8..<0.9: return .mint
        case 0.7..<0.8: return .yellow
        case 0.6..<0.7: return .orange
        default: return .red
        }
    }
    
    private var scoreDescription: String {
        let score = aiFormService.currentFormScore
        switch score {
        case 0.9...1.0: return "Excellent Form!"
        case 0.8..<0.9: return "Very Good"
        case 0.7..<0.8: return "Good Form"
        case 0.6..<0.7: return "Needs Work"
        default: return "Focus on Form"
        }
    }
    
    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
}

// MARK: - Real-time AI Analysis View
struct RealTimeAIAnalysisView: View {
    @EnvironmentObject var aiFormService: AIFormAnalysisService
    @State private var showingCameraView = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Camera Section
                if aiFormService.isAnalyzing {
                    aiCameraSection
                } else {
                    startAnalysisSection
                }
                
                // Pose Detection Status
                if aiFormService.isAnalyzing {
                    poseDetectionSection
                }
                
                // Real-time Metrics
                if let metrics = aiFormService.realTimeMetrics {
                    realTimeMetricsSection(metrics)
                }
                
                // AI Recommendations
                if let metrics = aiFormService.realTimeMetrics, !metrics.recommendations.isEmpty {
                    aiRecommendationsSection(metrics.recommendations)
                }
            }
            .padding()
        }
    }
    
    private var startAnalysisSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Start AI Form Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Position yourself in front of the camera for advanced AI-powered form analysis with real-time pose detection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await aiFormService.startAnalysis()
                }
            }) {
                HStack {
                    Image(systemName: "brain")
                    Text("Start AI Analysis")
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
    
    private var aiCameraSection: some View {
        VStack(spacing: 16) {
            // AI Camera Preview Placeholder
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(height: 300)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("AI Vision Active")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Analyzing pose and form in real-time")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
                .cornerRadius(12)
            
            // Live Analysis Controls
            HStack {
                VStack(alignment: .leading) {
                    Text("Live AI Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(aiFormService.currentFormScore * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                }
                
                Spacer()
                
                Button("Stop Analysis") {
                    aiFormService.stopAnalysis()
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
    
    private var poseDetectionSection: some View {
        HStack {
            Image(systemName: aiFormService.bodyPoseDetected ? "figure.walk.motion" : "figure.stand")
                .font(.title2)
                .foregroundColor(aiFormService.bodyPoseDetected ? .green : .orange)
            
            VStack(alignment: .leading) {
                Text("Pose Detection")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(aiFormService.bodyPoseDetected ? "Body pose detected" : "Position yourself in frame")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(aiFormService.confidenceLevel * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.2))
                .foregroundColor(confidenceColor)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func realTimeMetricsSection(_ metrics: FormMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Form Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(title: "Posture", score: metrics.postureScore, icon: "figure.stand")
                MetricCard(title: "Stride", score: metrics.strideScore, icon: "figure.walk")
                MetricCard(title: "Arms", score: metrics.armMovementScore, icon: "hands.clap")
                MetricCard(title: "Foot Strike", score: metrics.footStrikeScore, icon: "shoe")
                MetricCard(title: "Balance", score: metrics.balanceScore, icon: "scale.3d")
                MetricCard(title: "Turns", score: metrics.turnTechniqueScore, icon: "arrow.uturn.left")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func aiRecommendationsSection(_ recommendations: [FormRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(recommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                AIRecommendationCard(recommendation: recommendation)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var scoreColor: Color {
        let score = aiFormService.currentFormScore
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
    
    private var confidenceColor: Color {
        let confidence = aiFormService.confidenceLevel
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - AI Form Insights View
struct AIFormInsightsView: View {
    @EnvironmentObject var aiFormService: AIFormAnalysisService
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
                
                // AI Analysis Summary
                aiAnalysisSummarySection
                
                // Form Progress Trends
                formProgressSection
                
                // Detailed Insights
                detailedInsightsSection
            }
            .padding()
        }
    }
    
    private var aiAnalysisSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Analysis Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !aiFormService.analysisResults.isEmpty {
                VStack(spacing: 12) {
                    AnalysisSummaryRow(
                        title: "Total AI Sessions",
                        value: "\(aiFormService.analysisResults.count)",
                        icon: "brain.head.profile"
                    )
                    
                    AnalysisSummaryRow(
                        title: "Average Form Score",
                        value: "\(Int(averageFormScore * 100))%",
                        icon: "chart.bar.fill"
                    )
                    
                    AnalysisSummaryRow(
                        title: "Average Confidence",
                        value: "\(Int(averageConfidence * 100))%",
                        icon: "checkmark.seal.fill"
                    )
                    
                    AnalysisSummaryRow(
                        title: "Improvement Areas",
                        value: "\(topRecommendations.count)",
                        icon: "arrow.up.circle.fill"
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text("No AI analysis data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start an AI form analysis session to see insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var formProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Progress Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !aiFormService.analysisResults.isEmpty {
                // Placeholder for chart
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                            
                            Text("AI Form Progress Chart")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    )
                    .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No progress data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Complete AI form analysis sessions to track progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var detailedInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !topRecommendations.isEmpty {
                ForEach(Array(topRecommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                    AIRecommendationCard(recommendation: recommendation)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                    
                    Text("No AI insights available yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start analyzing your form to get personalized AI insights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 100)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var averageFormScore: Double {
        guard !aiFormService.analysisResults.isEmpty else { return 0.0 }
        return aiFormService.analysisResults.map { $0.averageFormScore }.reduce(0, +) / Double(aiFormService.analysisResults.count)
    }
    
    private var averageConfidence: Double {
        guard !aiFormService.analysisResults.isEmpty else { return 0.0 }
        return aiFormService.analysisResults.map { $0.averageConfidence }.reduce(0, +) / Double(aiFormService.analysisResults.count)
    }
    
    private var topRecommendations: [FormRecommendation] {
        let allRecommendations = aiFormService.analysisResults.flatMap { $0.topRecommendations }
        let groupedByType = Dictionary(grouping: allRecommendations) { $0.type }
        
        return groupedByType.compactMap { (type, recommendations) in
            recommendations.max { $0.priority < $1.priority }
        }.sorted { $0.priority > $1.priority }
    }
}

// MARK: - AI Coaching View
struct AICoachingView: View {
    @EnvironmentObject var aiFormService: AIFormAnalysisService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // AI Coach Header
                aiCoachHeaderSection
                
                // Personalized Recommendations
                if !topRecommendations.isEmpty {
                    personalizedRecommendationsSection
                }
                
                // Exercise Library
                exerciseLibrarySection
                
                // AI Tips
                aiTipsSection
            }
            .padding()
        }
    }
    
    private var aiCoachHeaderSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("AI Personal Coach")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Personalized recommendations based on your AI form analysis data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var personalizedRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized AI Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(topRecommendations.prefix(3).enumerated()), id: \.offset) { index, recommendation in
                ExpandedAIRecommendationCard(recommendation: recommendation)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var exerciseLibrarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Exercise Library")
                .font(.headline)
                .fontWeight(.semibold)
            
            let exercises = [
                AIExercise(
                    name: "AI-Guided High Knees",
                    description: "Improve leg turnover with AI pose tracking",
                    duration: "30 seconds x 3 sets",
                    difficulty: .beginner,
                    formAspects: [.stride, .posture]
                ),
                AIExercise(
                    name: "Smart Balance Training",
                    description: "AI-monitored single-leg balance holds",
                    duration: "45 seconds each leg",
                    difficulty: .intermediate,
                    formAspects: [.balance, .posture]
                ),
                AIExercise(
                    name: "Precision Turn Drills",
                    description: "AI-analyzed agility cone drills",
                    duration: "20m x 4 sets",
                    difficulty: .advanced,
                    formAspects: [.turnTechnique, .balance]
                )
            ]
            
            ForEach(exercises.indices, id: \.self) { index in
                AIExerciseCard(exercise: exercises[index])
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var aiTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Coaching Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            let tips = [
                "Use consistent lighting for better AI pose detection",
                "Position camera at waist height for optimal analysis",
                "Wear contrasting colors for improved body tracking",
                "Practice in a clear space for accurate movement analysis",
                "Review AI feedback immediately after each session"
            ]
            
            ForEach(tips.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    Text(tips[index])
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var topRecommendations: [FormRecommendation] {
        let allRecommendations = aiFormService.analysisResults.flatMap { $0.topRecommendations }
        let groupedByType = Dictionary(grouping: allRecommendations) { $0.type }
        
        return groupedByType.compactMap { (type, recommendations) in
            recommendations.max { $0.priority < $1.priority }
        }.sorted { $0.priority > $1.priority }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let score: Double
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(scoreColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                Text("\(Int(score * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
                
                Spacer()
            }
            
            ProgressView(value: score)
                .progressViewStyle(LinearProgressViewStyle(tint: scoreColor))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var scoreColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
}

struct AIRecommendationCard: View {
    let recommendation: FormRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.type.icon)
                .foregroundColor(priorityColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.type.rawValue.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(priorityText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)
                }
                
                Text(recommendation.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(priorityColor.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var priorityColor: Color {
        switch recommendation.priority.color {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .blue
        }
    }
    
    private var priorityText: String {
        switch recommendation.priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

struct ExpandedAIRecommendationCard: View {
    let recommendation: FormRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: recommendation.type.icon)
                    .foregroundColor(priorityColor)
                    .frame(width: 24)
                
                Text(recommendation.type.rawValue.capitalized)
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
            
            Text(recommendation.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if !recommendation.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Exercises:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendation.exercises, id: \.self) { exercise in
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
    
    private var priorityColor: Color {
        switch recommendation.priority.color {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .blue
        }
    }
    
    private var priorityText: String {
        switch recommendation.priority {
        case .low: return "Low Priority"
        case .medium: return "Medium Priority"
        case .high: return "High Priority"
        }
    }
}

struct AIExerciseCard: View {
    let exercise: AIExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(exercise.difficulty.rawValue.capitalized)
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
            
            HStack {
                Text("Duration: \(exercise.duration)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(exercise.formAspects, id: \.self) { aspect in
                        Text(aspect.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
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

struct CameraPermissionView: View {
    @Binding var permissionStatus: AVAuthorizationStatus
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("ShuttlX needs camera access for AI-powered form analysis. Your video is processed locally and never stored or shared.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    if permissionStatus == .notDetermined {
                        Button("Allow Camera Access") {
                            requestCameraPermission()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    } else if permissionStatus == .denied {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Camera Permission")
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
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
                if granted {
                    dismiss()
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

struct AIFormAnalysisSettingsView: View {
    @EnvironmentObject var aiFormService: AIFormAnalysisService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("AI Analysis Settings") {
                    HStack {
                        Text("Analysis Frequency")
                        Spacer()
                        Text("Real-time")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("AI Model Quality")
                        Spacer()
                        Text("High")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Real-time Feedback", isOn: .constant(true))
                    Toggle("Confidence Display", isOn: .constant(true))
                    Toggle("Pose Visualization", isOn: .constant(true))
                }
                
                Section("Performance") {
                    HStack {
                        Text("Model Status")
                        Spacer()
                        Text(aiFormService.isModelReady ? "Ready" : "Loading")
                            .foregroundColor(aiFormService.isModelReady ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Analysis Sessions")
                        Spacer()
                        Text("\(aiFormService.analysisResults.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Privacy & Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Processing")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("All AI analysis is performed locally on your device. No video data is transmitted or stored on external servers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AI Settings")
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

struct AIFormAnalysisHistoryView: View {
    @EnvironmentObject var aiFormService: AIFormAnalysisService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(aiFormService.analysisResults.reversed()) { session in
                    NavigationLink(destination: AIFormAnalysisDetailView(session: session)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text("\(Int(session.averageFormScore * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(session.averageFormScore))
                            }
                            
                            HStack {
                                Text("AI Analysis • \(Int(session.duration))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("Confidence: \(Int(session.averageConfidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Analysis History")
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
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
}

struct AIFormAnalysisDetailView: View {
    let session: FormAnalysisSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Summary
                VStack(spacing: 12) {
                    Text("\(Int(session.averageFormScore * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text("Average AI Form Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(session.startTime.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // AI Recommendations
                if !session.topRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Recommendations")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(session.topRecommendations.indices, id: \.self) { index in
                            ExpandedAIRecommendationCard(recommendation: session.topRecommendations[index])
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
        .navigationTitle("AI Analysis Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var scoreColor: Color {
        switch session.averageFormScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
}

// MARK: - Supporting Data Models

struct AIExercise {
    let name: String
    let description: String
    let duration: String
    let difficulty: Difficulty
    let formAspects: [FormAspect]
    
    enum Difficulty: String {
        case beginner, intermediate, advanced
    }
    
    enum FormAspect: String {
        case posture, stride, armMovement, footStrike, balance, turnTechnique
    }
}

// MARK: - Tab Bar Button
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
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
