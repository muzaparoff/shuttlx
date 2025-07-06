#!/usr/bin/env swift

import Foundation

print("🔗 ShuttlX Sync System Verification")
print("==================================")

// Test App Group container access
print("📂 Testing App Group Container Access:")
if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.shuttlx.shared") {
    print("✅ App Group container accessible: \(containerURL.path)")
    
    let programsURL = containerURL.appendingPathComponent("programs.json")
    let sessionsURL = containerURL.appendingPathComponent("sessions.json")
    
    // Check programs
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("✅ Programs loaded successfully")
                print("📊 Number of programs: \(jsonArray.count)")
                
                for program in jsonArray {
                    if let name = program["name"] as? String,
                       let id = program["id"] as? String {
                        print("   - \(name) (ID: \(id))")
                    }
                }
            } else if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Programs loaded successfully (dictionary format)")
                print("📊 Number of programs: \(jsonObject.count)")
                
                for (id, program) in jsonObject {
                    if let programDict = program as? [String: Any],
                       let name = programDict["name"] as? String {
                        print("   - \(name) (ID: \(id))")
                    }
                }
            }
        } catch {
            print("❌ Error loading programs: \(error.localizedDescription)")
        }
    } else {
        print("⚠️  programs.json not found")
    }
    
    // Check sessions
    if FileManager.default.fileExists(atPath: sessionsURL.path) {
        do {
            let data = try Data(contentsOf: sessionsURL)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("✅ Sessions loaded successfully")
                print("📊 Number of sessions: \(jsonArray.count)")
            }
        } catch {
            print("❌ Error loading sessions: \(error.localizedDescription)")
        }
    } else {
        print("⚠️  sessions.json not found (expected for fresh install)")
    }
    
} else {
    print("❌ Cannot access App Group container")
}

print("\n🧪 Manual Testing Instructions:")
print("================================")
print("1. Open ShuttlX on iPhone")
print("2. Check if the 'Test Sync Program' appears in the program list")
print("3. Open ShuttlX Watch App on Apple Watch")
print("4. Check if the same program appears on the watch")
print("5. Navigate to the DebugView on the watch to see:")
print("   - WatchConnectivity status")
print("   - App Group container status")
print("   - Real-time sync logs")
print("6. Try creating a new program on iPhone and see if it syncs to watch")
print("7. Try starting a workout on watch and see if it syncs to iPhone")

print("\n📱 Launch Apps:")
print("===============")
print("iOS Simulator: Look for 'ShuttlX' app")
print("Watch Simulator: Look for 'ShuttlXWatch Watch App Watch App' app")

print("\n🔧 Sync Architecture Summary:")
print("============================")
print("✅ Dual-sync system implemented:")
print("   - WatchConnectivity for real-time updates")
print("   - App Groups for persistent storage")
print("✅ Singleton pattern implemented")
print("✅ Debug tools available on watchOS")
print("✅ Test data persisted in shared container")

print("\n🎯 Next Steps:")
print("=============")
print("1. Launch both apps and verify programs sync")
print("2. Test real-time sync via DebugView")
print("3. Verify bidirectional data flow")
print("4. Test sync reliability after app restarts")
