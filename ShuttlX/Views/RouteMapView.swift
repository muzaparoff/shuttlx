import SwiftUI
import MapKit

struct RouteMapView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingMapOptions = false
    @State private var mapType: MKMapType = .standard
    @State private var showUserLocation = true
    
    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $mapRegion,
                interactionModes: .all,
                showsUserLocation: showUserLocation,
                userTrackingMode: .constant(.none),
                annotationItems: routeAnnotations) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: annotation.color)
                }
                .mapStyle(mapStyleForType(mapType))
                .onAppear {
                    updateMapRegion()
                }
                .onChange(of: locationManager.route) { _ in
                    updateMapRegion()
                }
            
            // Route overlay
            if let polyline = locationManager.getRoutePolyline() {
                RouteOverlayView(polyline: polyline)
            }
            
            // Map controls
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        // Map type button
                        Button(action: {
                            showingMapOptions.toggle()
                        }) {
                            Image(systemName: "map")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(22)
                        }
                        
                        // Center on route button
                        if !locationManager.route.isEmpty {
                            Button(action: {
                                centerOnRoute()
                            }) {
                                Image(systemName: "scope")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(22)
                            }
                        }
                        
                        // User location button
                        Button(action: {
                            centerOnUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(22)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Route statistics overlay
                if !locationManager.route.isEmpty {
                    RouteStatsOverlay(locationManager: locationManager)
                        .padding()
                }
            }
        }
        .actionSheet(isPresented: $showingMapOptions) {
            ActionSheet(
                title: Text("Map Options"),
                buttons: [
                    .default(Text("Standard")) { mapType = .standard },
                    .default(Text("Satellite")) { mapType = .satellite },
                    .default(Text("Hybrid")) { mapType = .hybrid },
                    .default(Text(showUserLocation ? "Hide User Location" : "Show User Location")) {
                        showUserLocation.toggle()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func updateMapRegion() {
        if let region = locationManager.getMapRegion() {
            mapRegion = region
        } else if let currentLocation = locationManager.currentLocation {
            mapRegion = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func centerOnRoute() {
        if let region = locationManager.getMapRegion() {
            withAnimation(.easeInOut(duration: 0.5)) {
                mapRegion = region
            }
        }
    }
    
    private func centerOnUserLocation() {
        if let currentLocation = locationManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                mapRegion = MKCoordinateRegion(
                    center: currentLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    private func mapStyleForType(_ type: MKMapType) -> MapStyle {
        switch type {
        case .standard:
            return .standard
        case .satellite:
            return .imagery
        case .hybrid:
            return .hybrid
        default:
            return .standard
        }
    }
    
    private var routeAnnotations: [RouteAnnotation] {
        var annotations: [RouteAnnotation] = []
        
        // Start point
        if let start = locationManager.route.first {
            annotations.append(RouteAnnotation(
                id: "start",
                coordinate: start.coordinate,
                title: "Start",
                subtitle: "Workout started here",
                color: .green
            ))
        }
        
        // End point (current location if tracking)
        if let end = locationManager.route.last, locationManager.route.count > 1 {
            annotations.append(RouteAnnotation(
                id: "end",
                coordinate: end.coordinate,
                title: locationManager.isTracking ? "Current" : "Finish",
                subtitle: locationManager.isTracking ? "Current position" : "Workout ended here",
                color: locationManager.isTracking ? .blue : .red
            ))
        }
        
        return annotations
    }
}

struct RouteAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let color: Color
}

struct RouteOverlayView: View {
    let polyline: MKPolyline
    
    var body: some View {
        // This would be implemented using MapKit's overlay system
        // For SwiftUI, we'd need to use UIViewRepresentable
        EmptyView()
    }
}

struct RouteStatsOverlay: View {
    @ObservedObject var locationManager: LocationManager
    @State private var selectedStat: StatType = .distance
    
    enum StatType: String, CaseIterable {
        case distance = "Distance"
        case pace = "Pace"
        case elevation = "Elevation"
        case speed = "Speed"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Stat selector
            Picker("Stat", selection: $selectedStat) {
                ForEach(StatType.allCases, id: \.self) { stat in
                    Text(stat.rawValue).tag(stat)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Stat display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedStat.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(valueForSelectedStat())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Additional info
                VStack(alignment: .trailing, spacing: 4) {
                    Text(additionalInfoTitle())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(additionalInfoValue())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func valueForSelectedStat() -> String {
        switch selectedStat {
        case .distance:
            return String(format: "%.2f km", locationManager.totalDistance / 1000)
        case .pace:
            let minutes = Int(locationManager.pace)
            let seconds = Int((locationManager.pace - Double(minutes)) * 60)
            return String(format: "%d:%02d /km", minutes, seconds)
        case .elevation:
            return String(format: "%.0f m", locationManager.elevation)
        case .speed:
            return String(format: "%.1f km/h", locationManager.currentSpeed * 3.6)
        }
    }
    
    private func additionalInfoTitle() -> String {
        switch selectedStat {
        case .distance:
            return "Average Speed"
        case .pace:
            return "Current Speed"
        case .elevation:
            return "Elevation Gain"
        case .speed:
            return "Average Speed"
        }
    }
    
    private func additionalInfoValue() -> String {
        switch selectedStat {
        case .distance:
            return String(format: "%.1f km/h", locationManager.averageSpeed * 3.6)
        case .pace:
            return String(format: "%.1f km/h", locationManager.currentSpeed * 3.6)
        case .elevation:
            return String(format: "%.0f m", locationManager.elevationGain)
        case .speed:
            return String(format: "%.1f km/h", locationManager.averageSpeed * 3.6)
        }
    }
}

struct RouteDetailsView: View {
    let routeStatistics: RouteStatistics
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Splits").tag(1)
                Text("Elevation").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            TabView(selection: $selectedTab) {
                // Overview
                RouteOverviewView(statistics: routeStatistics)
                    .tag(0)
                
                // Splits
                RouteSplitsView(splits: routeStatistics.splits)
                    .tag(1)
                
                // Elevation
                RouteElevationView(statistics: routeStatistics)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Route Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RouteOverviewView: View {
    let statistics: RouteStatistics
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Total Distance",
                    value: String(format: "%.2f km", statistics.totalDistance / 1000),
                    icon: "location",
                    color: .blue
                )
                
                StatCard(
                    title: "Average Pace",
                    value: formatPace(statistics.averagePace),
                    icon: "timer",
                    color: .green
                )
                
                StatCard(
                    title: "Max Speed",
                    value: String(format: "%.1f km/h", statistics.maxSpeed * 3.6),
                    icon: "speedometer",
                    color: .orange
                )
                
                StatCard(
                    title: "Elevation Gain",
                    value: String(format: "%.0f m", statistics.elevationGain),
                    icon: "mountain.2",
                    color: .purple
                )
                
                StatCard(
                    title: "Elevation Loss",
                    value: String(format: "%.0f m", statistics.elevationLoss),
                    icon: "mountain.2",
                    color: .red
                )
                
                StatCard(
                    title: "Elevation Range",
                    value: String(format: "%.0f - %.0f m", statistics.minElevation, statistics.maxElevation),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .indigo
                )
            }
            .padding()
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

struct RouteSplitsView: View {
    let splits: [RouteSplit]
    
    var body: some View {
        List {
            ForEach(splits.indices, id: \.self) { index in
                let split = splits[index]
                
                HStack {
                    // Split number
                    Text("\(index + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Time: \(split.formattedTime)")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("Pace: \(split.formattedPace)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if split.elevationGain > 0 {
                            Text("Elevation Gain: \(String(format: "%.0f m", split.elevationGain))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct RouteElevationView: View {
    let statistics: RouteStatistics
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Elevation summary
                VStack(spacing: 12) {
                    HStack {
                        StatCard(
                            title: "Total Gain",
                            value: String(format: "%.0f m", statistics.elevationGain),
                            icon: "arrow.up",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Total Loss",
                            value: String(format: "%.0f m", statistics.elevationLoss),
                            icon: "arrow.down",
                            color: .red
                        )
                    }
                    
                    HStack {
                        StatCard(
                            title: "Highest Point",
                            value: String(format: "%.0f m", statistics.maxElevation),
                            icon: "mountain.2.fill",
                            color: .purple
                        )
                        
                        StatCard(
                            title: "Lowest Point",
                            value: String(format: "%.0f m", statistics.minElevation),
                            icon: "mountain.2",
                            color: .blue
                        )
                    }
                }
                
                // Elevation profile placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elevation Profile")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            Text("Elevation chart would be displayed here")
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

#Preview {
    RouteMapView(locationManager: LocationManager())
}
