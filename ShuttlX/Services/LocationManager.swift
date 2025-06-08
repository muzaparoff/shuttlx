import Foundation
import CoreLocation
import MapKit
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String = ""
    @Published var isTracking = false
    @Published var trackingAccuracy: LocationAccuracy = .best
    @Published var route: [CLLocation] = []
    @Published var totalDistance: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var averageSpeed: Double = 0
    @Published var pace: Double = 0 // minutes per kilometer
    @Published var elevation: Double = 0
    @Published var elevationGain: Double = 0
    @Published var elevationLoss: Double = 0
    
    // Route statistics
    @Published var routeStatistics = RouteStatistics()
    
    // Location accuracy settings
    enum LocationAccuracy: String, CaseIterable {
        case best = "Best"
        case navigation = "Navigation"
        case nearestTenMeters = "10m"
        case hundredMeters = "100m"
        case kilometer = "1km"
        case reduced = "Reduced"
        
        var clAccuracy: CLLocationAccuracy {
            switch self {
            case .best: return kCLLocationAccuracyBest
            case .navigation: return kCLLocationAccuracyBestForNavigation
            case .nearestTenMeters: return kCLLocationAccuracyNearestTenMeters
            case .hundredMeters: return kCLLocationAccuracyHundredMeters
            case .kilometer: return kCLLocationAccuracyKilometer
            case .reduced: return kCLLocationAccuracyReduced
            }
        }
    }
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = trackingAccuracy.clAccuracy
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Show alert to go to settings
            break
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        
        isTracking = true
        route.removeAll()
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        routeStatistics = RouteStatistics()
        
        locationManager.startUpdatingLocation()
        
        // For better accuracy during workouts
        if #available(iOS 14.0, *) {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        calculateFinalStatistics()
    }
    
    func pauseTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        locationManager.startUpdatingLocation()
    }
    
    func updateAccuracy(_ accuracy: LocationAccuracy) {
        trackingAccuracy = accuracy
        locationManager.desiredAccuracy = accuracy.clAccuracy
    }
    
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }
    
    private func calculateSpeed(from currentLocation: CLLocation) -> Double {
        guard currentLocation.speed >= 0 else { return 0 }
        return currentLocation.speed // m/s
    }
    
    private func calculatePace(speed: Double) -> Double {
        guard speed > 0 else { return 0 }
        // Convert m/s to min/km
        let kmPerHour = speed * 3.6
        return 60.0 / kmPerHour
    }
    
    private func calculateElevationChanges() {
        guard route.count >= 2 else { return }
        
        var gain: Double = 0
        var loss: Double = 0
        
        for i in 1..<route.count {
            let previous = route[i-1]
            let current = route[i]
            
            let elevationDiff = current.altitude - previous.altitude
            
            if elevationDiff > 0 {
                gain += elevationDiff
            } else {
                loss += abs(elevationDiff)
            }
        }
        
        elevationGain = gain
        elevationLoss = loss
    }
    
    private func calculateFinalStatistics() {
        guard !route.isEmpty else { return }
        
        routeStatistics.totalDistance = totalDistance
        routeStatistics.averageSpeed = averageSpeed
        routeStatistics.averagePace = pace
        routeStatistics.elevationGain = elevationGain
        routeStatistics.elevationLoss = elevationLoss
        routeStatistics.maxSpeed = route.compactMap { $0.speed >= 0 ? $0.speed : nil }.max() ?? 0
        routeStatistics.minElevation = route.map { $0.altitude }.min() ?? 0
        routeStatistics.maxElevation = route.map { $0.altitude }.max() ?? 0
        
        // Calculate splits (per kilometer)
        routeStatistics.splits = calculateSplits()
    }
    
    private func calculateSplits() -> [RouteSplit] {
        guard !route.isEmpty else { return [] }
        
        var splits: [RouteSplit] = []
        var currentDistance: Double = 0
        var splitStartIndex = 0
        let splitDistance: Double = 1000 // 1km splits
        
        for i in 1..<route.count {
            let segmentDistance = calculateDistance(from: route[i-1], to: route[i])
            currentDistance += segmentDistance
            
            if currentDistance >= splitDistance {
                let splitTime = route[i].timestamp.timeIntervalSince(route[splitStartIndex].timestamp)
                let splitPace = splitTime / 60.0 // minutes per km
                
                splits.append(RouteSplit(
                    distance: splitDistance,
                    time: splitTime,
                    pace: splitPace,
                    elevationGain: calculateElevationGainForSegment(from: splitStartIndex, to: i)
                ))
                
                currentDistance = 0
                splitStartIndex = i
            }
        }
        
        return splits
    }
    
    private func calculateElevationGainForSegment(from startIndex: Int, to endIndex: Int) -> Double {
        guard startIndex < endIndex && endIndex < route.count else { return 0 }
        
        var gain: Double = 0
        
        for i in (startIndex + 1)...endIndex {
            let elevationDiff = route[i].altitude - route[i-1].altitude
            if elevationDiff > 0 {
                gain += elevationDiff
            }
        }
        
        return gain
    }
    
    func getMapRegion() -> MKCoordinateRegion? {
        guard !route.isEmpty else { return nil }
        
        let coordinates = route.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    func getRoutePolyline() -> MKPolyline? {
        guard route.count >= 2 else { return nil }
        
        let coordinates = route.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    // Reverse geocoding for address
    private func updateCurrentAddress() {
        guard let location = currentLocation else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self?.currentAddress = [
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out inaccurate locations
        guard location.horizontalAccuracy < 100 else { return }
        
        currentLocation = location
        
        if isTracking {
            // Add to route
            route.append(location)
            
            // Calculate distance if we have a previous location
            if route.count >= 2 {
                let previousLocation = route[route.count - 2]
                let segmentDistance = calculateDistance(from: previousLocation, to: location)
                totalDistance += segmentDistance
                
                // Update average speed
                let totalTime = location.timestamp.timeIntervalSince(route.first?.timestamp ?? Date())
                if totalTime > 0 {
                    averageSpeed = totalDistance / totalTime
                    pace = calculatePace(speed: averageSpeed)
                }
            }
            
            // Update current speed
            currentSpeed = calculateSpeed(from: location)
            
            // Update elevation
            elevation = location.altitude
            calculateElevationChanges()
        }
        
        // Update address for current location
        updateCurrentAddress()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            isTracking = false
            manager.stopUpdatingLocation()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Data Models
struct RouteStatistics {
    var totalDistance: Double = 0
    var averageSpeed: Double = 0
    var averagePace: Double = 0
    var maxSpeed: Double = 0
    var elevationGain: Double = 0
    var elevationLoss: Double = 0
    var minElevation: Double = 0
    var maxElevation: Double = 0
    var splits: [RouteSplit] = []
}

struct RouteSplit {
    let distance: Double
    let time: TimeInterval
    let pace: Double
    let elevationGain: Double
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: time) ?? "0:00"
    }
    
    var formattedPace: String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
