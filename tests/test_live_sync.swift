#!/usr/bin/env swift

import Foundation

// MARK: - Live Sync Test for iOS to watchOS
// This script creates a test program and verifies it syncs correctly

print("📱⌚ LIVE SYNC TEST - iOS to watchOS")
print(String(repeating: "=", count: 50))

let appGroupIdentifier = "group.com.shuttlx.shared"
let programsKey = "programs.json"
let testMarker = "live_sync_test_\(Date().timeIntervalSince1970)"

func log(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] \(message)")
}

func getAppGroupContainer() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
}

// Simple data model for testing
struct TrainingProgram: Codable, Identifiable {
    var id = UUID()
    let name: String
    let type: String
    let totalDuration: TimeInterval
    let intervalCount: Int
    let maxPulse: Int
    let createdDate: Date
    let lastModified: Date
    let testMarker: String
}

func testLiveSync() {
    log("🧪 Testing live sync between iOS and watchOS...")
    
    guard let container = getAppGroupContainer() else {
        log("❌ Cannot access App Group container")
        return
    }
    
    let programsURL = container.appendingPathComponent(programsKey)
    
    // Load existing programs
    var existingPrograms: [TrainingProgram] = []
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            existingPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("✅ Found \(existingPrograms.count) existing programs")
        } catch {
            log("⚠️ Failed to load existing programs: \(error)")
        }
    }
    
    // Create a new test program
    let newProgram = TrainingProgram(
        name: "Live Sync Test Program",
        type: "walkRun",
        totalDuration: 1800, // 30 minutes
        intervalCount: 10,
        maxPulse: 180,
        createdDate: Date(),
        lastModified: Date(),
        testMarker: testMarker
    )
    
    // Add to existing programs
    var allPrograms = existingPrograms
    allPrograms.append(newProgram)
    
    // Save back to App Group
    do {
        let encodedData = try JSONEncoder().encode(allPrograms)
        try encodedData.write(to: programsURL)
        log("✅ Created new test program and saved to App Group")
        log("📋 Program details:")
        log("   - Name: \(newProgram.name)")
        log("   - Type: \(newProgram.type)")
        log("   - Duration: \(Int(newProgram.totalDuration/60)) minutes")
        log("   - Intervals: \(newProgram.intervalCount)")
        log("   - Test Marker: \(newProgram.testMarker)")
    } catch {
        log("❌ Failed to save new program: \(error)")
        return
    }
    
    log("")
    log("🔄 NEXT STEPS FOR MANUAL VERIFICATION:")
    log("1. Open the iOS ShuttlX app on iPhone 16 simulator")
    log("2. Look for the program 'Live Sync Test Program' in the list")
    log("3. Open the watchOS ShuttlX app on Apple Watch Series 10 simulator")
    log("4. Use the 'Sync from iPhone' button to trigger manual sync")
    log("5. Check if the 'Live Sync Test Program' appears on the watch")
    log("6. Check the Debug Info view for sync status")
    
    log("")
    log("📊 VERIFICATION CHECKLIST:")
    log("☐ Program appears in iOS app")
    log("☐ Program appears in watchOS app after sync")
    log("☐ Program details match between devices")
    log("☐ Sync logs show successful transfer")
    log("☐ DebugView shows updated program count")
    
    log("")
    log("🛠️ TROUBLESHOOTING:")
    log("- If program doesn't appear on watchOS, try the manual sync button")
    log("- Check DebugView for sync status and error messages")
    log("- Ensure both simulators are running simultaneously")
    log("- Check that both apps are in the foreground")
    log("- Look for WatchConnectivity session status in DebugView")
}

// Run the live sync test
testLiveSync()
