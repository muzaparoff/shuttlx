#!/usr/bin/env swift

import Foundation
import WatchConnectivity
import Combine

// MARK: - WatchConnectivity Investigation Script
// This script investigates WatchConnectivity setup and communication

print("📱⌚ WATCHCONNECTIVITY INVESTIGATION - Phase 19")
print(String(repeating: "=", count: 50))

// MARK: - Test Helper Functions
func log(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] \(message)")
}

// MARK: - WatchConnectivity Status Check
func investigateWatchConnectivity() {
    log("🔍 Investigating WatchConnectivity setup...")
    
    // Check if WatchConnectivity is supported
    if WCSession.isSupported() {
        log("✅ WatchConnectivity is supported on this device")
        
        let session = WCSession.default
        log("📱 Session activation state: \(session.activationState.rawValue)")
        
        switch session.activationState {
        case .notActivated:
            log("⚠️ WatchConnectivity session is not activated")
        case .inactive:
            log("⚠️ WatchConnectivity session is inactive")
        case .activated:
            log("✅ WatchConnectivity session is activated")
        @unknown default:
            log("❓ Unknown WatchConnectivity activation state")
        }
        
        // Check session properties
        log("📊 Session properties:")
        log("   - Is paired: \(session.isPaired)")
        log("   - Is reachable: \(session.isReachable)")
        log("   - Is watch app installed: \(session.isWatchAppInstalled)")
        log("   - Is complication enabled: \(session.isComplicationEnabled)")
        log("   - Watch directory URL: \(session.watchDirectoryURL?.path ?? "nil")")
        log("   - Remaining complication user info transfers: \(session.remainingComplicationUserInfoTransfers)")
        
        // Check if we can send messages
        if session.activationState == .activated {
            if session.isReachable {
                log("✅ Watch is reachable - immediate messaging available")
            } else {
                log("⚠️ Watch is not reachable - only background transfers available")
            }
        } else {
            log("❌ Session not activated - no messaging available")
        }
        
    } else {
        log("❌ WatchConnectivity is not supported on this device")
    }
}

// MARK: - Check App Group Configuration
func investigateAppGroupConfiguration() {
    log("📁 Investigating App Group configuration...")
    
    let appGroupIdentifier = "group.com.shuttlx.shared"
    
    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
        log("✅ App Group container found: \(containerURL.path)")
        
        // Check if we can write to the container
        let testFile = containerURL.appendingPathComponent("connectivity_test.txt")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            log("✅ App Group container is writable")
            
            // Check if we can read from the container
            let content = try String(contentsOf: testFile, encoding: .utf8)
            log("✅ App Group container is readable: \(content)")
            
            // Cleanup
            try FileManager.default.removeItem(at: testFile)
            log("✅ App Group container cleanup successful")
        } catch {
            log("❌ App Group container access failed: \(error)")
        }
    } else {
        log("❌ App Group container not found - check entitlements")
    }
}

// MARK: - Check iOS SharedDataManager Implementation
func investigateiOSSharedDataManager() {
    log("📱 Investigating iOS SharedDataManager implementation...")
    
    // Check if iOS SharedDataManager file exists
    let iOSSharedDataManagerPath = "/Users/sergey/Documents/github/shuttlx/ShuttlX/Services/SharedDataManager.swift"
    
    if FileManager.default.fileExists(atPath: iOSSharedDataManagerPath) {
        log("✅ iOS SharedDataManager file found")
        
        do {
            let content = try String(contentsOfFile: iOSSharedDataManagerPath, encoding: .utf8)
            
            // Check for key methods
            let keyMethods = [
                "session(_ session: WCSession, didReceiveMessage message:",
                "session(_ session: WCSession, didReceiveUserInfo userInfo:",
                "syncProgramsToWatch",
                "sendProgramsToWatch",
                "requestPrograms"
            ]
            
            for method in keyMethods {
                if content.contains(method) {
                    log("✅ Found method: \(method)")
                } else {
                    log("⚠️ Missing method: \(method)")
                }
            }
            
            // Check for WCSessionDelegate conformance
            if content.contains("WCSessionDelegate") {
                log("✅ iOS SharedDataManager conforms to WCSessionDelegate")
            } else {
                log("❌ iOS SharedDataManager does not conform to WCSessionDelegate")
            }
            
        } catch {
            log("❌ Failed to read iOS SharedDataManager: \(error)")
        }
    } else {
        log("❌ iOS SharedDataManager file not found")
    }
}

// MARK: - Check watchOS SharedDataManager Implementation
func investigatewatchOSSharedDataManager() {
    log("⌚ Investigating watchOS SharedDataManager implementation...")
    
    // Check if watchOS SharedDataManager file exists
    let watchOSSharedDataManagerPath = "/Users/sergey/Documents/github/shuttlx/ShuttlXWatch Watch App Watch App/Services/SharedDataManager.swift"
    
    if FileManager.default.fileExists(atPath: watchOSSharedDataManagerPath) {
        log("✅ watchOS SharedDataManager file found")
        
        do {
            let content = try String(contentsOfFile: watchOSSharedDataManagerPath, encoding: .utf8)
            
            // Check for key methods
            let keyMethods = [
                "session(_ session: WCSession, didReceiveMessage message:",
                "session(_ session: WCSession, didReceiveUserInfo userInfo:",
                "requestProgramsFromiOS",
                "syncFromiPhone",
                "sendMessage"
            ]
            
            for method in keyMethods {
                if content.contains(method) {
                    log("✅ Found method: \(method)")
                } else {
                    log("⚠️ Missing method: \(method)")
                }
            }
            
            // Check for WCSessionDelegate conformance
            if content.contains("WCSessionDelegate") {
                log("✅ watchOS SharedDataManager conforms to WCSessionDelegate")
            } else {
                log("❌ watchOS SharedDataManager does not conform to WCSessionDelegate")
            }
            
        } catch {
            log("❌ Failed to read watchOS SharedDataManager: \(error)")
        }
    } else {
        log("❌ watchOS SharedDataManager file not found")
    }
}

// MARK: - Test Current Program Synchronization
func testCurrentProgramSync() {
    log("🧪 Testing current program synchronization...")
    
    let appGroupIdentifier = "group.com.shuttlx.shared"
    let programsKey = "programs.json"
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
        log("❌ Cannot access App Group container")
        return
    }
    
    let programsURL = containerURL.appendingPathComponent(programsKey)
    
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            
            log("✅ Found \(programs.count) programs in App Group")
            
            // List recent programs
            let recentPrograms = programs.filter { $0.lastModified.timeIntervalSinceNow > -86400 }
            log("📊 Recent programs (last 24h): \(recentPrograms.count)")
            
            for program in recentPrograms.prefix(3) {
                log("   - \(program.name) (modified: \(program.lastModified))")
            }
            
            // Check if programs are being created by iOS
            let iOSPrograms = programs.filter { !$0.name.contains("Test") }
            log("📱 Non-test programs: \(iOSPrograms.count)")
            
            if iOSPrograms.isEmpty {
                log("⚠️ No real iOS programs found - sync may not be working")
            }
            
        } catch {
            log("❌ Failed to decode programs: \(error)")
        }
    } else {
        log("⚠️ No programs file found in App Group")
    }
}

// MARK: - Data Model for Testing
struct TrainingProgram: Codable, Identifiable {
    var id = UUID()
    let name: String
    let type: String
    let totalDuration: TimeInterval
    let intervalCount: Int
    let maxPulse: Int
    let createdDate: Date
    let lastModified: Date
}

// MARK: - Main Investigation Function
func runWatchConnectivityInvestigation() {
    log("🚀 Starting WatchConnectivity investigation...")
    
    // Run all investigations
    investigateWatchConnectivity()
    log("")
    
    investigateAppGroupConfiguration()
    log("")
    
    investigateiOSSharedDataManager()
    log("")
    
    investigatewatchOSSharedDataManager()
    log("")
    
    testCurrentProgramSync()
    log("")
    
    // Provide summary and recommendations
    log(String(repeating: "=", count: 50))
    log("📋 WATCHCONNECTIVITY INVESTIGATION SUMMARY")
    log(String(repeating: "=", count: 50))
    
    log("🔧 SYNC TROUBLESHOOTING STEPS:")
    log("1. Ensure both iOS and watchOS simulators are running")
    log("2. Check that WatchConnectivity session is activated in both apps")
    log("3. Verify delegate methods are properly implemented")
    log("4. Test with real devices if simulator sync is limited")
    log("5. Add more logging to sync methods for debugging")
    log("6. Consider using transferUserInfo for reliable background sync")
    
    log("\n🎯 NEXT STEPS:")
    log("1. Add debug logging to sync methods")
    log("2. Test manual sync button in watchOS app")
    log("3. Monitor sync activity in both apps")
    log("4. Create programs on iOS and verify watchOS receives them")
    log("5. Check for any error messages in the sync logs")
}

// Execute the investigation
runWatchConnectivityInvestigation()
