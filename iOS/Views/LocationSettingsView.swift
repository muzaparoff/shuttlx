import SwiftUI
import MapKit

struct LocationSettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var showingPermissionAlert = false
    @State private var showingLocationDetails = false
    
    var body: some View {
        List {
            // Location Permission Status
            Section("Location Access") {
                HStack {
                    Image(systemName: permissionIcon)
                        .foregroundColor(permissionColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(permissionStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if locationManager.authorizationStatus == .denied || 
                       locationManager.authorizationStatus == .restricted {
                        Button("Settings") {
                            showingPermissionAlert = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                if locationManager.authorizationStatus == .notDetermined {
                    Button("Request Permission") {
                        locationManager.requestPermission()
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Current Location Info
            if locationManager.currentLocation != nil {
                Section("Current Location") {
                    Button(action: {
                        showingLocationDetails = true
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location Details")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if !locationManager.currentAddress.isEmpty {
                                    Text(locationManager.currentAddress)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Tracking Settings
            Section("Tracking Preferences") {
                // Accuracy setting
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    Text("GPS Accuracy")
                    
                    Spacer()
                    
                    Picker("Accuracy", selection: $locationManager.trackingAccuracy) {
                        ForEach(LocationManager.LocationAccuracy.allCases, id: \.self) { accuracy in
                            Text(accuracy.rawValue).tag(accuracy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Auto-pause on GPS loss
                HStack {
                    Image(systemName: "pause.circle")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Auto-pause on GPS loss")
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                }
                
                // Show route on map
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Show route on map")
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(true))
                        .labelsHidden()
                }
            }
            
            // Route Data
            if !locationManager.route.isEmpty {
                Section("Current Route") {
                    NavigationLink(destination: RouteMapView(locationManager: locationManager)) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("View Route Map")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(locationManager.route.count) GPS points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        Button("Clear Route Data") {
                            locationManager.route.removeAll()
                            locationManager.totalDistance = 0
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            // GPS Information
            Section("GPS Information") {
                InfoRow(
                    icon: "info.circle",
                    title: "What is GPS tracking?",
                    description: "GPS tracking records your location during workouts to measure distance, pace, and route."
                )
                
                InfoRow(
                    icon: "battery.100",
                    title: "Battery Usage",
                    description: "GPS tracking may increase battery usage. Use 'Reduced' accuracy for longer workouts."
                )
                
                InfoRow(
                    icon: "shield",
                    title: "Privacy",
                    description: "Location data is only stored locally on your device and is not shared without your permission."
                )
            }
        }
        .navigationTitle("Location Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Location Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access in Settings to track your workouts with GPS.")
        }
        .sheet(isPresented: $showingLocationDetails) {
            LocationDetailsView(locationManager: locationManager)
        }
    }
    
    private var permissionIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }
    
    private var permissionColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .orange
        }
    }
    
    private var permissionStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "Always allowed - Best for workout tracking"
        case .authorizedWhenInUse:
            return "While using app - Good for workout tracking"
        case .denied:
            return "Denied - GPS tracking unavailable"
        case .restricted:
            return "Restricted - GPS tracking unavailable"
        case .notDetermined:
            return "Not determined - Tap to request permission"
        @unknown default:
            return "Unknown status"
        }
    }
}

struct LocationDetailsView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if let location = locationManager.currentLocation {
                    Section("Coordinates") {
                        DetailRow(title: "Latitude", value: String(format: "%.6f°", location.coordinate.latitude))
                        DetailRow(title: "Longitude", value: String(format: "%.6f°", location.coordinate.longitude))
                        DetailRow(title: "Altitude", value: String(format: "%.1f m", location.altitude))
                    }
                    
                    Section("Accuracy") {
                        DetailRow(title: "Horizontal", value: String(format: "±%.1f m", location.horizontalAccuracy))
                        DetailRow(title: "Vertical", value: String(format: "±%.1f m", location.verticalAccuracy))
                        DetailRow(title: "Speed", value: location.speed >= 0 ? String(format: "%.1f m/s", location.speed) : "N/A")
                        DetailRow(title: "Course", value: location.course >= 0 ? String(format: "%.1f°", location.course) : "N/A")
                    }
                    
                    Section("Timestamp") {
                        DetailRow(title: "Last Update", value: location.timestamp.formatted())
                        DetailRow(title: "Age", value: String(format: "%.1f seconds ago", Date().timeIntervalSince(location.timestamp)))
                    }
                    
                    if !locationManager.currentAddress.isEmpty {
                        Section("Address") {
                            Text(locationManager.currentAddress)
                                .font(.subheadline)
                        }
                    }
                    
                    Section("Map") {
                        Button("View on Map") {
                            // Open in Maps app
                            let placemark = MKPlacemark(coordinate: location.coordinate)
                            let mapItem = MKMapItem(placemark: placemark)
                            mapItem.name = "Current Location"
                            mapItem.openInMaps(launchOptions: [
                                MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
                            ])
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Section {
                        Text("No location data available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Location Details")
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

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GPSStatusIndicator: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        if locationManager.isTracking {
            if let location = locationManager.currentLocation {
                if location.horizontalAccuracy < 10 {
                    return .green
                } else if location.horizontalAccuracy < 50 {
                    return .yellow
                } else {
                    return .orange
                }
            } else {
                return .red
            }
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if !locationManager.isTracking {
            return "GPS Off"
        }
        
        guard let location = locationManager.currentLocation else {
            return "Searching..."
        }
        
        if location.horizontalAccuracy < 10 {
            return "GPS Strong"
        } else if location.horizontalAccuracy < 50 {
            return "GPS Good"
        } else {
            return "GPS Weak"
        }
    }
}

struct RoutePreviewCard: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        if !locationManager.route.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Text("Route Preview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    NavigationLink(destination: RouteMapView(locationManager: locationManager)) {
                        Text("View Map")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                HStack {
                    RouteStatView(
                        title: "Distance",
                        value: String(format: "%.2f km", locationManager.totalDistance / 1000),
                        icon: "location"
                    )
                    
                    Divider()
                        .frame(height: 30)
                    
                    RouteStatView(
                        title: "Pace",
                        value: formatPace(locationManager.pace),
                        icon: "timer"
                    )
                    
                    Divider()
                        .frame(height: 30)
                    
                    RouteStatView(
                        title: "Elevation",
                        value: String(format: "%.0f m", locationManager.elevation),
                        icon: "mountain.2"
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "0:00" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct RouteStatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        LocationSettingsView(locationManager: LocationManager())
    }
}
