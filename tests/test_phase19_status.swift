#!/usr/bin/env swift

import Foundation

// Phase 19 Live Testing - Sync Status Verification
// This script monitors the App Group container and checks sync status

func checkAppGroupContainer() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        print("❌ Failed to access App Group container")
        return
    }
    
    print("🔍 App Group Container Analysis")
    print("================================")
    print("Container URL: \(containerURL.path)")
    
    let programsURL = containerURL.appendingPathComponent("programs")
    let sessionsURL = containerURL.appendingPathComponent("sessions")
    
    // Check programs directory
    print("\n📁 Programs Directory:")
    do {
        let programFiles = try FileManager.default.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
        if programFiles.isEmpty {
            print("   (No program files found)")
        } else {
            for file in programFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if file.pathExtension == "json" {
                    let attributes = try file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    let createdAt = attributes.creationDate?.description ?? "Unknown"
                    let size = attributes.fileSize ?? 0
                    print("   ✅ \(file.lastPathComponent) (\(size) bytes, created: \(createdAt))")
                }
            }
        }
    } catch {
        print("   ❌ Error accessing programs: \(error)")
    }
    
    // Check sessions directory
    print("\n📁 Sessions Directory:")
    do {
        let sessionFiles = try FileManager.default.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: [.creationDateKey])
        if sessionFiles.isEmpty {
            print("   (No session files found)")
        } else {
            for file in sessionFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if file.pathExtension == "json" {
                    print("   ✅ \(file.lastPathComponent)")
                }
            }
        }
    } catch {
        print("   ❌ Error accessing sessions: \(error)")
    }
    
    // Check root directory contents
    print("\n📁 Container Root Contents:")
    do {
        let rootFiles = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil)
        for file in rootFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let prefix = isDirectory ? "📁" : "📄"
            print("   \(prefix) \(file.lastPathComponent)")
        }
    } catch {
        print("   ❌ Error accessing root: \(error)")
    }
}

func analyzeTestProgram() {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        return
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    do {
        let files = try FileManager.default.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: nil)
        let testFiles = files.filter { $0.lastPathComponent.contains("PHASE19_TEST") }
        
        print("\n🧪 Phase 19 Test Programs:")
        for file in testFiles {
            do {
                let data = try Data(contentsOf: file)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let name = json["name"] as? String ?? "Unknown"
                    let id = json["id"] as? String ?? "Unknown"
                    let type = json["programType"] as? String ?? "Unknown"
                    let createdAt = json["createdAt"] as? String ?? "Unknown"
                    
                    print("   🎯 Program: \(name)")
                    print("      ID: \(id)")
                    print("      Type: \(type)")
                    print("      Created: \(createdAt)")
                    print("      File: \(file.lastPathComponent)")
                }
            } catch {
                print("   ❌ Error reading \(file.lastPathComponent): \(error)")
            }
        }
    } catch {
        print("   ❌ Error analyzing test programs: \(error)")
    }
}

func checkSyncStatus() {
    print("\n🔄 Sync Status Check")
    print("====================")
    
    // Check if apps are running
    let task = Process()
    task.launchPath = "/usr/bin/xcrun"
    task.arguments = ["simctl", "list", "devices", "booted"]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        print("📱 Active Simulators:")
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("iPhone") || line.contains("Apple Watch") {
                print("   \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    } catch {
        print("❌ Error checking simulators: \(error)")
    }
}

// Main execution
print("🔍 Phase 19 Live Testing - Sync Status Verification")
print("===================================================")

checkAppGroupContainer()
analyzeTestProgram()
checkSyncStatus()

print("\n📋 Testing Instructions:")
print("1. ✅ Test program created in App Group container")
print("2. 📱 Open iOS ShuttlX app - check if program appears in list")
print("3. ⌚ Open watchOS ShuttlX app - go to DebugView")
print("4. 🔍 Check DebugView for:")
print("   - App Group container status")
print("   - WatchConnectivity session status")
print("   - Program count and sync logs")
print("5. ⏱️ Wait 30 seconds for auto-sync to trigger")
print("6. ✅ Verify program appears on watchOS app")

print("\n🎯 Expected Results:")
print("- iOS app should load the program immediately")
print("- watchOS app should show program after sync")
print("- DebugView should show successful sync status")
print("- Both apps should display the same program data")
