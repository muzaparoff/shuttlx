//
//  WorkoutView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import MapKit

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkoutViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var showingWorkoutSummary = false
    @State private var showingRouteMap = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Main Content
                mainContentSection
                
                // Bottom Controls
                bottomControlsSection
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startWorkout()
            if viewModel.workoutType.usesGPS {
                locationManager.startTracking()
            }
        }
        .onDisappear {
            locationManager.stopTracking()
        }
        .sheet(isPresented: $showingWorkoutSummary) {
            WorkoutSummaryView(session: viewModel.currentSession)
        }
        .sheet(isPresented: $showingRouteMap) {
            NavigationView {
                RouteMapView(locationManager: locationManager)
                    .navigationTitle("Route Map")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingRouteMap = false
                            }
                        }
                    }
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Close Button
            Button(action: {
                if viewModel.workoutState == .active {
                    viewModel.pauseWorkout()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: viewModel.workoutState == .active ? "pause.fill" : "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Spacer()
            
            // Workout Type and GPS Status
            VStack(spacing: 4) {
                Text(viewModel.workoutType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                GPSStatusIndicator(locationManager: locationManager)
            }
            
            Spacer()
            
            // Route Map Button
            Button(action: {
                showingRouteMap = true
            }) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .opacity(locationManager.route.isEmpty ? 0.5 : 1.0)
            .disabled(locationManager.route.isEmpty)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var mainContentSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Timer and Current Interval
                currentIntervalSection
                
                // Next Interval Preview
                if let nextInterval = viewModel.nextInterval {
                    nextIntervalSection(nextInterval)
                }
                
                // Progress Overview
                progressSection
                
                // Real-time Stats
                statsSection
                
                // Map (if tracking location)
                if viewModel.isTrackingLocation {
                    mapSection
                }
            }
            .padding()
        }
    }
    
    private var currentIntervalSection: some View {
        VStack(spacing: 16) {
            // Current Interval Title
            Text(viewModel.currentInterval?.instructions ?? "Get Ready")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Timer
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: viewModel.timerProgress)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.timerProgress)
                
                VStack(spacing: 8) {
                    Text(viewModel.currentTimeText)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if let interval = viewModel.currentInterval {
                        Text(interval.type.displayName)
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Intensity Indicator
            if let interval = viewModel.currentInterval {
                IntensityIndicator(intensity: interval.intensity)
            }
        }
    }
    
    private func nextIntervalSection(_ interval: SimpleWorkoutInterval) -> some View {
        VStack(spacing: 12) {
            Text("Next")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: interval.type.iconName)
                    .font(.title3)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(interval.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("\(Int(interval.duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(viewModel.currentIntervalIndex + 1)/\(viewModel.totalIntervals)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: viewModel.workoutProgress)
                .tint(.orange)
                .scaleEffect(y: 2)
        }
    }
    
    private var statsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            WorkoutStatCard(
                title: "Duration",
                value: viewModel.elapsedTimeText,
                icon: "clock.fill",
                color: .blue
            )
            
            WorkoutStatCard(
                title: "Calories",
                value: "\(Int(viewModel.estimatedCalories))",
                icon: "flame.fill",
                color: .orange
            )
            
            if let distance = viewModel.totalDistance {
                WorkoutStatCard(
                    title: "Distance",
                    value: String(format: "%.2f km", distance),
                    icon: "location.fill",
                    color: .green
                )
            }
            
            if let avgHeartRate = viewModel.averageHeartRate {
                WorkoutStatCard(
                    title: "Avg HR",
                    value: "\(Int(avgHeartRate))",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
                .foregroundColor(.white)
            
            Map(coordinateRegion: $viewModel.mapRegion, annotationItems: viewModel.routePoints) { point in
                MapPin(coordinate: point.coordinate, tint: .orange)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .disabled(true)
        }
    }
    
    private var bottomControlsSection: some View {
        HStack(spacing: 24) {
            // End Workout
            Button(action: {
                viewModel.endWorkout()
                showingWorkoutSummary = true
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("End")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.red)
                .cornerRadius(12)
            }
            
            // Pause/Resume Button
            Button(action: {
                if viewModel.workoutState == .active {
                    viewModel.pauseWorkout()
                } else {
                    viewModel.resumeWorkout()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.workoutState == .active ? "pause.fill" : "play.fill")
                    Text(viewModel.workoutState == .active ? "Pause" : "Resume")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.orange)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Supporting Views

struct IntensityIndicator: View {
    let intensity: ExerciseIntensity
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= intensity.level ? intensity.color : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 20)
            }
        }
    }
}

struct WorkoutStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension IntervalType {
    var iconName: String {
        switch self {
        case .warmup: return "flame"
        case .work: return "bolt.fill"
        case .rest: return "pause.fill"
        case .cooldown: return "leaf.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .work: return "Work"
        case .rest: return "Rest"
        case .cooldown: return "Cool Down"
        }
    }
}

extension ExerciseIntensity {
    var level: Int {
        switch self {
        case .veryLight: return 1
        case .light: return 2
        case .moderate: return 3
        case .vigorous: return 4
        case .maximal: return 5
        }
    }
    
    var color: Color {
        switch self {
        case .veryLight: return .blue
        case .light: return .green
        case .moderate: return .yellow
        case .vigorous: return .orange
        case .maximal: return .red
        }
    }
}

// MARK: - Route Point Model

struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}

#Preview {
    WorkoutView()
}
