#!/usr/bin/env swift

import Foundation

// MARK: - Sync Configuration Investigation Script
// This script investigates sync setup and identifies potential issues

print("📱⌚ SYNC CONFIGURATION INVESTIGATION - Phase 19")
print(String(repeating: "=", count: 50))

// MARK: - Test Helper Functions
func log(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] \(message)")
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

// MARK: - Check Entitlements Files
func checkEntitlements() {
    log("🔐 Checking entitlements files...")
    
    // Check iOS entitlements
    let iOSEntitlementsPath = "/Users/sergey/Documents/github/shuttlx/ShuttlX/ShuttlX.entitlements"
    if FileManager.default.fileExists(atPath: iOSEntitlementsPath) {
        log("✅ iOS entitlements file found")
        
        do {
            let content = try String(contentsOfFile: iOSEntitlementsPath, encoding: .utf8)
            
            if content.contains("group.com.shuttlx.shared") {
                log("✅ iOS entitlements include App Group")
            } else {
                log("❌ iOS entitlements missing App Group")
            }
            
            if content.contains("com.apple.security.application-groups") {
                log("✅ iOS entitlements include App Group capability")
            } else {
                log("❌ iOS entitlements missing App Group capability")
            }
            
        } catch {
            log("❌ Failed to read iOS entitlements: \(error)")
        }
    } else {
        log("❌ iOS entitlements file not found")
    }
    
    // Check watchOS entitlements
    let watchOSEntitlementsPath = "/Users/sergey/Documents/github/shuttlx/ShuttlXWatch Watch App Watch App/ShuttlXWatch.entitlements"
    if FileManager.default.fileExists(atPath: watchOSEntitlementsPath) {
        log("✅ watchOS entitlements file found")
        
        do {
            let content = try String(contentsOfFile: watchOSEntitlementsPath, encoding: .utf8)
            
            if content.contains("group.com.shuttlx.shared") {
                log("✅ watchOS entitlements include App Group")
            } else {
                log("❌ watchOS entitlements missing App Group")
            }
            
            if content.contains("com.apple.security.application-groups") {
                log("✅ watchOS entitlements include App Group capability")
            } else {
                log("❌ watchOS entitlements missing App Group capability")
            }
            
        } catch {
            log("❌ Failed to read watchOS entitlements: \(error)")
        }
    } else {
        log("❌ watchOS entitlements file not found")
    }
}

// MARK: - Check DataManager Integration
func checkDataManagerIntegration() {
    log("🔗 Checking DataManager integration...")
    
    // Check iOS DataManager
    let iOSDataManagerPath = "/Users/sergey/Documents/github/shuttlx/ShuttlX/Services/DataManager.swift"
    if FileManager.default.fileExists(atPath: iOSDataManagerPath) {
        log("✅ iOS DataManager file found")
        
        do {
            let content = try String(contentsOfFile: iOSDataManagerPath, encoding: .utf8)
            
            // Check for SharedDataManager integration
            if content.contains("SharedDataManager") {
                log("✅ iOS DataManager integrates with SharedDataManager")
            } else {
                log("⚠️ iOS DataManager may not integrate with SharedDataManager")
            }
            
            // Check for sync triggers
            if content.contains("syncProgramsToWatch") {
                log("✅ iOS DataManager triggers sync to watch")
            } else {
                log("⚠️ iOS DataManager may not trigger sync to watch")
            }
            
        } catch {
            log("❌ Failed to read iOS DataManager: \(error)")
        }
    } else {
        log("❌ iOS DataManager file not found")
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
func runSyncConfigurationInvestigation() {
    log("🚀 Starting sync configuration investigation...")
    
    // Run all investigations
    investigateAppGroupConfiguration()
    log("")
    
    checkEntitlements()
    log("")
    
    investigateiOSSharedDataManager()
    log("")
    
    investigatewatchOSSharedDataManager()
    log("")
    
    checkDataManagerIntegration()
    log("")
    
    testCurrentProgramSync()
    log("")
    
    // Provide summary and recommendations
    log(String(repeating: "=", count: 50))
    log("📋 SYNC CONFIGURATION INVESTIGATION SUMMARY")
    log(String(repeating: "=", count: 50))
    
    log("🔧 POTENTIAL SYNC ISSUES:")
    log("1. Check if DataManager calls SharedDataManager.syncProgramsToWatch()")
    log("2. Verify WatchConnectivity session activation in both apps")
    log("3. Ensure both apps are running for real-time sync")
    log("4. Check if sync methods are being called when programs are created")
    log("5. Verify entitlements are properly configured")
    
    log("\n🎯 NEXT STEPS:")
    log("1. Add debug logging to program creation in iOS")
    log("2. Test manual sync button in watchOS app")
    log("3. Monitor sync activity in both apps")
    log("4. Check for any error messages in the sync logs")
    log("5. Consider testing with real devices if simulators have issues")
}

// Execute the investigation
runSyncConfigurationInvestigation()
