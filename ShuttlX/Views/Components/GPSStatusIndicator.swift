//
//  GPSStatusIndicator.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
import CoreLocation

struct GPSStatusIndicator: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: gpsIconName)
                .font(.caption)
                .foregroundColor(gpsColor)
            
            Text(gpsStatusText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(gpsColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(gpsBackgroundColor)
        .cornerRadius(8)
    }
    
    private var gpsIconName: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return locationManager.isTracking ? "location.fill" : "location"
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location"
        @unknown default:
            return "location"
        }
    }
    
    private var gpsStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationManager.isTracking {
                switch locationManager.accuracy {
                case let accuracy where accuracy < 5:
                    return "GPS High"
                case let accuracy where accuracy < 10:
                    return "GPS Good"
                case let accuracy where accuracy < 20:
                    return "GPS Fair"
                default:
                    return "GPS Low"
                }
            } else {
                return "GPS Ready"
            }
        case .denied, .restricted:
            return "GPS Off"
        case .notDetermined:
            return "GPS Wait"
        @unknown default:
            return "GPS Unknown"
        }
    }
    
    private var gpsColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if locationManager.isTracking {
                switch locationManager.accuracy {
                case let accuracy where accuracy < 5:
                    return .green
                case let accuracy where accuracy < 10:
                    return .green
                case let accuracy where accuracy < 20:
                    return .yellow
                default:
                    return .orange
                }
            } else {
                return .blue
            }
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private var gpsBackgroundColor: Color {
        gpsColor.opacity(0.2)
    }
}

#Preview {
    VStack(spacing: 16) {
        GPSStatusIndicator(locationManager: LocationManager())
        
        Text("Different GPS states")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
