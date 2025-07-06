#!/usr/bin/env swift

import Foundation

// Test program creation with proper intervals for live sync verification
print("🔄 Live Sync Manual Test - Phase 19")
print("============================================================")

// 1. Verify App Group container access
let appGroupIdentifier = "group.com.shuttlx.shared"
guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
    print("❌ Cannot access App Group container")
    exit(1)
}

print("1. App Group container: \(sharedContainer.path)")

// 2. Create simple test program with intervals
let testProgram = """
{
    "name": "Manual Live Sync Test",
    "type": "walkRun",
    "intervals": [
        {
            "id": "\(UUID().uuidString)",
            "phase": "Rest",
            "duration": 180,
            "intensity": "Low"
        },
        {
            "id": "\(UUID().uuidString)",
            "phase": "Work",
            "duration": 60,
            "intensity": "Moderate"
        },
        {
            "id": "\(UUID().uuidString)",
            "phase": "Rest",
            "duration": 120,
            "intensity": "Low"
        },
        {
            "id": "\(UUID().uuidString)",
            "phase": "Work",
            "duration": 60,
            "intensity": "Moderate"
        },
        {
            "id": "\(UUID().uuidString)",
            "phase": "Rest",
            "duration": 180,
            "intensity": "Low"
        }
    ],
    "maxPulse": 175,
    "intervalCount": 5,
    "totalDuration": 600,
    "createdDate": \(Date().timeIntervalSinceReferenceDate),
    "lastModified": \(Date().timeIntervalSinceReferenceDate),
    "id": "\(UUID().uuidString)",
    "testMarker": "manual_live_sync_test_\(Date().timeIntervalSinceReferenceDate)"
}
"""

print("2. Created test program JSON with intervals")

// 3. Read existing programs
let programsURL = sharedContainer.appendingPathComponent("programs.json")
var existingPrograms: [String] = []

if let data = try? Data(contentsOf: programsURL),
   let jsonString = String(data: data, encoding: .utf8) {
    // Parse as JSON array
    if let jsonData = jsonString.data(using: .utf8),
       let jsonArray = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
        existingPrograms = jsonArray.compactMap { dict in
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
            return jsonString
        }
    }
}

print("3. Found \(existingPrograms.count) existing programs")

// 4. Add new test program
if let testProgramData = testProgram.data(using: .utf8),
   let testProgramDict = try? JSONSerialization.jsonObject(with: testProgramData, options: []) as? [String: Any] {
    
    var allPrograms: [[String: Any]] = existingPrograms.compactMap { programString in
        guard let data = programString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return nil }
        return dict
    }
    
    allPrograms.append(testProgramDict)
    
    // Write back to file
    if let jsonData = try? JSONSerialization.data(withJSONObject: allPrograms, options: [.prettyPrinted]),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        try? jsonString.write(to: programsURL, atomically: true, encoding: String.Encoding.utf8)
        print("✅ Added new test program to App Group container")
    }
}

print("4. MANUAL TESTING INSTRUCTIONS:")
print("============================================================")
print("📱 iOS App (iPhone 16 Simulator):")
print("   1. Open ShuttlX app")
print("   2. Look for 'Manual Live Sync Test' in program list")
print("   3. Verify it shows 5 intervals (3 rest, 2 work)")
print("   4. Total duration should be 10 minutes")
print("")
print("⌚ watchOS App (Apple Watch Series 10 Simulator):")
print("   1. Open ShuttlX watch app")
print("   2. If program doesn't appear, tap 'Sync from iPhone'")
print("   3. Verify 'Manual Live Sync Test' appears in program list")
print("   4. Check program details match iOS version")
print("")
print("🔍 Debug Information:")
print("   - Check DebugView on watchOS for sync status")
print("   - Look for connection status and last sync time")
print("   - Verify program count updates after sync")
print("")
print("✅ Expected Result:")
print("   - Both platforms show identical program")
print("   - Sync completes within 2-3 seconds")
print("   - No error messages in debug view")
print("   - Program structure matches on both devices")
print("")
print("🎯 SUCCESS CRITERIA:")
print("   - Program appears on both platforms")
print("   - Intervals are correctly structured")
print("   - Sync status shows successful completion")
print("   - No crashes or errors during sync")
print("============================================================")
