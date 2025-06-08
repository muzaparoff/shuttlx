//
//  WeatherManager.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Weather Data Models
struct WeatherData: Codable {
    let temperature: Double // Celsius
    let feelsLike: Double
    let humidity: Int // Percentage
    let windSpeed: Double // m/s
    let windDirection: Int // Degrees
    let pressure: Double // hPa
    let visibility: Double // km
    let uvIndex: Double
    let condition: WeatherCondition
    let timestamp: Date
    let location: String
    
    var temperatureFahrenheit: Double {
        return (temperature * 9/5) + 32
    }
    
    var windSpeedKmh: Double {
        return windSpeed * 3.6
    }
    
    var windSpeedMph: Double {
        return windSpeed * 2.237
    }
}

enum WeatherCondition: String, Codable, CaseIterable {
    case clear = "clear"
    case partlyCloudy = "partly_cloudy"
    case cloudy = "cloudy"
    case overcast = "overcast"
    case mist = "mist"
    case fog = "fog"
    case drizzle = "drizzle"
    case lightRain = "light_rain"
    case rain = "rain"
    case heavyRain = "heavy_rain"
    case thunderstorm = "thunderstorm"
    case snow = "snow"
    case sleet = "sleet"
    case hail = "hail"
    
    var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy: return "Cloudy"
        case .overcast: return "Overcast"
        case .mist: return "Mist"
        case .fog: return "Fog"
        case .drizzle: return "Drizzle"
        case .lightRain: return "Light Rain"
        case .rain: return "Rain"
        case .heavyRain: return "Heavy Rain"
        case .thunderstorm: return "Thunderstorm"
        case .snow: return "Snow"
        case .sleet: return "Sleet"
        case .hail: return "Hail"
        }
    }
    
    var iconName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .overcast: return "smoke.fill"
        case .mist, .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .lightRain: return "cloud.rain.fill"
        case .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .sleet: return "cloud.sleet.fill"
        case .hail: return "cloud.hail.fill"
        }
    }
    
    var isIdealForOutdoorWorkout: Bool {
        switch self {
        case .clear, .partlyCloudy, .cloudy: return true
        case .overcast, .mist: return true
        case .drizzle, .lightRain: return false
        case .rain, .heavyRain, .thunderstorm: return false
        case .fog, .snow, .sleet, .hail: return false
        }
    }
}

// MARK: - Weather Recommendations
struct WorkoutRecommendation {
    let message: String
    let intensity: RecommendationIntensity
    let suggestions: [String]
    
    enum RecommendationIntensity {
        case ideal, good, caution, avoid
        
        var color: String {
            switch self {
            case .ideal: return "green"
            case .good: return "yellow"
            case .caution: return "orange"
            case .avoid: return "red"
            }
        }
    }
}

// MARK: - Weather Manager
@MainActor
class WeatherManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var currentWeather: WeatherData?
    @Published var isLoading: Bool = false
    @Published var error: WeatherError?
    @Published var recommendation: WorkoutRecommendation?
    @Published var lastUpdated: Date?
    
    // MARK: - Private Properties
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 600 // 10 minutes
    private var updateTimer: Timer?
    
    // MARK: - API Configuration
    private let apiKey = "demo_key" // In production, this would be stored securely
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    // MARK: - Initialization
    override init() {
        super.init()
        startPeriodicUpdates()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func fetchWeather(for location: CLLocation) async {
        isLoading = true
        error = nil
        
        do {
            let weather = try await fetchWeatherData(latitude: location.coordinate.latitude, 
                                                   longitude: location.coordinate.longitude)
            currentWeather = weather
            recommendation = generateRecommendation(for: weather)
            lastUpdated = Date()
        } catch {
            self.error = error as? WeatherError ?? .networkError
        }
        
        isLoading = false
    }
    
    func fetchWeatherForCurrentLocation() async {
        // This would integrate with LocationManager to get current location
        // For now, using a sample location (San Francisco)
        let sampleLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        await fetchWeather(for: sampleLocation)
    }
    
    func generateMockWeatherData() {
        let mockWeather = WeatherData(
            temperature: Double.random(in: 15...25),
            feelsLike: Double.random(in: 15...25),
            humidity: Int.random(in: 40...80),
            windSpeed: Double.random(in: 0...15),
            windDirection: Int.random(in: 0...360),
            pressure: Double.random(in: 1000...1030),
            visibility: Double.random(in: 5...20),
            uvIndex: Double.random(in: 1...8),
            condition: WeatherCondition.allCases.randomElement() ?? .clear,
            timestamp: Date(),
            location: "Current Location"
        )
        
        currentWeather = mockWeather
        recommendation = generateRecommendation(for: mockWeather)
        lastUpdated = Date()
    }
    
    // MARK: - Private Methods
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchWeatherForCurrentLocation()
            }
        }
    }
    
    private func fetchWeatherData(latitude: Double, longitude: Double) async throws -> WeatherData {
        // In a real implementation, this would make an actual API call
        // For demo purposes, we'll simulate a network delay and return mock data
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Simulate potential network errors
        if Bool.random() && Double.random() < 0.1 { // 10% chance of error
            throw WeatherError.networkError
        }
        
        // Return mock data
        return WeatherData(
            temperature: Double.random(in: 5...35),
            feelsLike: Double.random(in: 5...35),
            humidity: Int.random(in: 30...90),
            windSpeed: Double.random(in: 0...20),
            windDirection: Int.random(in: 0...360),
            pressure: Double.random(in: 995...1040),
            visibility: Double.random(in: 1...20),
            uvIndex: Double.random(in: 0...11),
            condition: WeatherCondition.allCases.randomElement() ?? .clear,
            timestamp: Date(),
            location: "Current Location"
        )
    }
    
    private func generateRecommendation(for weather: WeatherData) -> WorkoutRecommendation {
        var suggestions: [String] = []
        var intensity: WorkoutRecommendation.RecommendationIntensity
        var message: String
        
        // Temperature analysis
        let temp = weather.temperature
        
        if temp < -5 {
            intensity = .avoid
            message = "Extremely cold conditions. Consider indoor workouts."
            suggestions = [
                "Try indoor HIIT workouts",
                "Use a treadmill if available",
                "Consider bodyweight exercises indoors"
            ]
        } else if temp < 0 {
            intensity = .caution
            message = "Very cold. Take extra precautions if exercising outdoors."
            suggestions = [
                "Warm up indoors before going out",
                "Wear appropriate winter gear",
                "Keep workouts shorter than usual",
                "Watch for ice on running surfaces"
            ]
        } else if temp < 5 {
            intensity = .caution
            message = "Cold weather. Dress appropriately and warm up thoroughly."
            suggestions = [
                "Layer your clothing",
                "Extended warm-up recommended",
                "Protect extremities (hands, feet, head)"
            ]
        } else if temp >= 5 && temp <= 25 {
            if weather.condition.isIdealForOutdoorWorkout {
                intensity = .ideal
                message = "Perfect weather for outdoor workouts!"
                suggestions = [
                    "Great conditions for any workout type",
                    "Consider outdoor activities you enjoy",
                    "Perfect for longer workout sessions"
                ]
            } else {
                intensity = .good
                message = "Good temperature, but watch the weather conditions."
                suggestions = [
                    "Check if rain is expected",
                    "Consider covered outdoor areas"
                ]
            }
        } else if temp <= 30 {
            intensity = .good
            message = "Warm weather. Stay hydrated and avoid peak sun hours."
            suggestions = [
                "Bring plenty of water",
                "Workout early morning or evening",
                "Wear light, breathable clothing",
                "Take breaks in shade if needed"
            ]
        } else if temp <= 35 {
            intensity = .caution
            message = "Hot weather. Take extra precautions for heat safety."
            suggestions = [
                "Exercise early morning or late evening",
                "Increase hydration significantly",
                "Consider shorter, less intense sessions",
                "Stay in shaded areas when possible"
            ]
        } else {
            intensity = .avoid
            message = "Extremely hot conditions. Indoor workouts recommended."
            suggestions = [
                "Avoid outdoor exercise during peak heat",
                "Use air-conditioned indoor spaces",
                "Consider swimming if available",
                "Postpone until cooler temperatures"
            ]
        }
        
        // Weather condition adjustments
        if !weather.condition.isIdealForOutdoorWorkout {
            if intensity == .ideal { intensity = .good }
            else if intensity == .good { intensity = .caution }
            
            switch weather.condition {
            case .rain, .heavyRain:
                suggestions.append("Avoid slippery surfaces")
                suggestions.append("Consider indoor alternatives")
            case .thunderstorm:
                intensity = .avoid
                message = "Thunderstorm conditions. Stay indoors for safety."
                suggestions = ["Wait for storm to pass", "Indoor workouts only"]
            case .snow, .sleet, .hail:
                suggestions.append("Watch for icy conditions")
                suggestions.append("Reduce workout intensity")
            case .fog:
                suggestions.append("Improve visibility with reflective gear")
                suggestions.append("Stick to familiar routes")
            default:
                break
            }
        }
        
        // Wind considerations
        if weather.windSpeed > 15 {
            suggestions.append("Strong winds - adjust workout intensity")
            if intensity == .ideal { intensity = .good }
        }
        
        // UV Index considerations
        if weather.uvIndex > 6 {
            suggestions.append("High UV - use sunscreen and protective clothing")
            suggestions.append("Seek shade when possible")
        }
        
        // Humidity considerations
        if weather.humidity > 80 {
            suggestions.append("High humidity - take frequent breaks")
            suggestions.append("Monitor for heat exhaustion symptoms")
        }
        
        return WorkoutRecommendation(message: message, intensity: intensity, suggestions: Array(suggestions.prefix(4)))
    }
}

// MARK: - Weather Error Types
enum WeatherError: Error, LocalizedError {
    case networkError
    case invalidLocation
    case apiKeyInvalid
    case dataParsing
    case locationDenied
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to fetch weather data. Check your internet connection."
        case .invalidLocation:
            return "Invalid location provided."
        case .apiKeyInvalid:
            return "Weather service unavailable."
        case .dataParsing:
            return "Unable to process weather data."
        case .locationDenied:
            return "Location access denied. Enable location services for weather updates."
        }
    }
}

// MARK: - Weather Display Helpers
extension WeatherData {
    func temperatureString(unit: TemperatureUnit = .celsius) -> String {
        switch unit {
        case .celsius:
            return String(format: "%.0f°C", temperature)
        case .fahrenheit:
            return String(format: "%.0f°F", temperatureFahrenheit)
        }
    }
    
    func windString(unit: SpeedUnit = .kmh) -> String {
        switch unit {
        case .kmh:
            return String(format: "%.0f km/h", windSpeedKmh)
        case .mph:
            return String(format: "%.0f mph", windSpeedMph)
        case .ms:
            return String(format: "%.1f m/s", windSpeed)
        }
    }
    
    enum TemperatureUnit {
        case celsius, fahrenheit
    }
    
    enum SpeedUnit {
        case kmh, mph, ms
    }
}
