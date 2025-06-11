//
//  ShuttlXWatchApp.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
//

import SwiftUI
import HealthKit

@main
struct ShuttlXWatch_Watch_AppApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()
    @StateObject private var connectivityManager = WatchConnectivityManager()
    
    init() {
        print("⌚ [WATCH-STARTUP] ShuttlX Watch App initializing...")
        print("⌚ [WATCH-STARTUP] Bundle ID: \(Bundle.main.bundleIdentifier ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] Build Number: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] Watch app initializing for watchOS")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(connectivityManager)
                .onAppear {
                    workoutManager.requestAuthorization()
                    print("⌚ [WATCH-STARTUP] ContentView appeared successfully")
                    print("⌚ [WATCH-STARTUP] Watch app fully loaded and ready!")
                    print("🚀 [DEBUG] ShuttlXWatch app launched successfully")
                }
        }
    }
}
