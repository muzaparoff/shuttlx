//
//  WorkoutSummaryView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import MapKit

struct WorkoutSummaryView: View {
    let session: WorkoutSession?
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Main Stats
                    mainStatsSection
                    
                    // Heart Rate Section
                    if let session = session, !session.heartRateData.isEmpty {
                        heartRateSection
                    }
                    
                    // Route Map Section
                    if let session = session, !session.locationData.isEmpty {
                        routeSection
                    }
                    
                    // Interval Breakdown
                    if let session = session, !session.intervals.isEmpty {
                        intervalBreakdownSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Celebration Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            // Workout Type
            Text(session?.workoutType.displayName ?? "Workout")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Completion Message
            Text("Great job! You completed your workout.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var mainStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                SummaryStatCard(
                    title: "Duration",
                    value: formatDuration(session?.duration ?? 0),
                    icon: "clock.fill",
                    color: .blue
                )
                
                SummaryStatCard(
                    title: "Calories",
                    value: "\(Int(session?.caloriesBurned ?? 0))",
                    icon: "flame.fill",
                    color: .orange
                )
                
                if let distance = session?.totalDistance, distance > 0 {
                    SummaryStatCard(
                        title: "Distance",
                        value: String(format: "%.2f km", distance),
                        icon: "location.fill",
                        color: .green
                    )
                }
                
                if let avgHR = session?.averageHeartRate, avgHR > 0 {
                    SummaryStatCard(
                        title: "Avg Heart Rate",
                        value: "\(Int(avgHR)) bpm",
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
        }
    }
    
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Heart Rate")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(session?.averageHeartRate ?? 0)) bpm")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(session?.maxHeartRate ?? 0)) bpm")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                
                // Simple heart rate chart placeholder
                HeartRateChart(heartRateData: session?.heartRateData ?? [])
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let session = session, !session.locationData.isEmpty {
                RouteMapView(locationData: session.locationData)
                    .frame(height: 200)
                    .cornerRadius(12)
            }
        }
    }
    
    private var intervalBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Intervals")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if let session = session {
                LazyVStack(spacing: 8) {
                    ForEach(Array(session.intervals.enumerated()), id: \.offset) { index, interval in
                        IntervalSummaryRow(
                            interval: interval,
                            index: index + 1
                        )
                    }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Save to Health
            Button(action: {
                // TODO: Save workout to HealthKit
                print("Saving workout to Health...")
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("Save to Health")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.green)
                .cornerRadius(12)
            }
            
            // Share Workout
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Workout")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.blue)
                .cornerRadius(12)
            }
            
            // View Analytics
            Button(action: {
                // TODO: Navigate to detailed analytics
                print("Viewing detailed analytics...")
            }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                    Text("View Analytics")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.purple)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Supporting Views

struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct HeartRateChart: View {
    let heartRateData: [HeartRateDataPoint]
    
    var body: some View {
        VStack {
            if heartRateData.isEmpty {
                Text("No heart rate data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                // Simple line chart representation
                GeometryReader { geometry in
                    Path { path in
                        let maxHR = heartRateData.map { $0.heartRate }.max() ?? 200
                        let minHR = heartRateData.map { $0.heartRate }.min() ?? 60
                        let range = maxHR - minHR
                        
                        for (index, dataPoint) in heartRateData.enumerated() {
                            let x = CGFloat(index) / CGFloat(heartRateData.count - 1) * geometry.size.width
                            let y = geometry.size.height - CGFloat((dataPoint.heartRate - minHR) / range) * geometry.size.height
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(.red, lineWidth: 2)
                }
                .frame(height: 100)
            }
        }
    }
}

struct RouteMapView: View {
    let locationData: [LocationDataPoint]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        Map(coordinateRegion: .constant(region), annotationItems: routePoints) { point in
            MapPin(coordinate: point.coordinate, tint: .orange)
        }
        .onAppear {
            setupMapRegion()
        }
        .disabled(true)
    }
    
    private var routePoints: [RoutePoint] {
        return locationData.map { locationPoint in
            RoutePoint(coordinate: locationPoint.coordinate, timestamp: locationPoint.timestamp)
        }
    }
    
    private func setupMapRegion() {
        guard !locationData.isEmpty else { return }
        
        let coordinates = locationData.map { $0.coordinate }
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.2)
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

struct IntervalSummaryRow: View {
    let interval: SimpleWorkoutInterval
    let index: Int
    
    var body: some View {
        HStack {
            // Interval Number
            Text("\(index)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(interval.type == .work ? .orange : .gray))
            
            // Interval Info
            VStack(alignment: .leading, spacing: 4) {
                Text(interval.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(interval.instructions ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(interval.duration))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(interval.intensity.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    WorkoutSummaryView(session: nil)
}
