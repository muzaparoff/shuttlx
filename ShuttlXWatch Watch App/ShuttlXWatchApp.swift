//
//  ShuttlXWatchApp.swift
//  ShuttlXWatch Watch App
//
//  Created by sergey on 09/06/2025.
//

import SwiftUI
import WatchKit

@main
struct ShuttlXWatch_Watch_AppApp: App {
    
    init() {
        print("⌚ [WATCH-STARTUP] ShuttlX Watch App initializing...")
        print("⌚ [WATCH-STARTUP] Bundle ID: \(Bundle.main.bundleIdentifier ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] Build Number: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "UNKNOWN")")
        print("⌚ [WATCH-STARTUP] Watch OS Version: \(WKInterfaceDevice.current().systemVersion)")
        print("⌚ [WATCH-STARTUP] Watch Model: \(WKInterfaceDevice.current().model)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("⌚ [WATCH-STARTUP] ContentView appeared successfully")
                    print("⌚ [WATCH-STARTUP] Watch app fully loaded and ready!")
                }
        }
    }
}
