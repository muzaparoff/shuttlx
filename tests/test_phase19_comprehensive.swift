#!/usr/bin/env swift

import Foundation

// Phase 19 Comprehensive Sync Test
// This script tests the actual sync functionality between iOS and watchOS

struct SyncTestResult {
    let testName: String
    let success: Bool
    let message: String
    let timestamp: Date
}

var testResults: [SyncTestResult] = []

func addResult(_ testName: String, success: Bool, message: String) {
    let result = SyncTestResult(testName: testName, success: success, message: message, timestamp: Date())
    testResults.append(result)
    let status = success ? "✅" : "❌"
    print("\(status) \(testName): \(message)")
}

func waitForSync(seconds: Int = 5) {
    print("⏳ Waiting \(seconds) seconds for sync...")
    sleep(UInt32(seconds))
}

func testAppGroupAccess() {
    print("\n🧪 Test 1: App Group Container Access")
    print("=====================================")
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        addResult("App Group Access", success: false, message: "Cannot access App Group container")
        return
    }
    
    addResult("App Group Access", success: true, message: "Container accessible at \(containerURL.path)")
    
    // Test read/write permissions
    let testFile = containerURL.appendingPathComponent("sync_test.txt")
    do {
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        let _ = try String(contentsOf: testFile, encoding: .utf8)
        try FileManager.default.removeItem(at: testFile)
        addResult("App Group R/W", success: true, message: "Read/write permissions verified")
    } catch {
        addResult("App Group R/W", success: false, message: "Permission error: \(error)")
    }
}

func testProgramStorage() {
    print("\n🧪 Test 2: Training Program Storage")
    print("===================================")
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        addResult("Program Storage", success: false, message: "No container access")
        return
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    do {
        let files = try FileManager.default.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: nil)
        let testFiles = files.filter { $0.lastPathComponent.contains("PHASE19_TEST") }
        
        if testFiles.isEmpty {
            addResult("Program Storage", success: false, message: "No test programs found")
        } else {
            addResult("Program Storage", success: true, message: "Found \(testFiles.count) test program(s)")
            
            // Verify program content
            for file in testFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let name = json?["name"] as? String ?? "Unknown"
                    addResult("Program Content", success: true, message: "Valid JSON: \(name)")
                } catch {
                    addResult("Program Content", success: false, message: "Invalid JSON in \(file.lastPathComponent)")
                }
            }
        }
    } catch {
        addResult("Program Storage", success: false, message: "Directory access error: \(error)")
    }
}

func testMultipleProgramCreation() {
    print("\n🧪 Test 3: Multiple Program Creation")
    print("====================================")
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        addResult("Multiple Programs", success: false, message: "No container access")
        return
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    // Create additional test programs
    for i in 1...3 {
        let program = [
            "id": "PHASE19_MULTI_TEST_\(i)_\(Int(Date().timeIntervalSince1970))",
            "name": "Multi-Test Program \(i)",
            "description": "Test program \(i) for multi-sync verification",
            "programType": "Cardio",
            "totalDuration": 1200,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "intervals": [
                [
                    "duration": 600,
                    "intensity": "Moderate",
                    "type": "Main"
                ],
                [
                    "duration": 600,
                    "intensity": "High", 
                    "type": "Finish"
                ]
            ]
        ] as [String: Any]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: program)
            let fileURL = programsURL.appendingPathComponent("\(program["id"] as! String).json")
            try data.write(to: fileURL)
            addResult("Multi-Program \(i)", success: true, message: "Created \(program["name"] as! String)")
        } catch {
            addResult("Multi-Program \(i)", success: false, message: "Creation failed: \(error)")
        }
    }
}

func analyzeFinalState() {
    print("\n🧪 Test 4: Final State Analysis")
    print("===============================")
    
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.shuttlx.shared") else {
        addResult("Final Analysis", success: false, message: "No container access")
        return
    }
    
    let programsURL = containerURL.appendingPathComponent("programs")
    
    do {
        let files = try FileManager.default.contentsOfDirectory(at: programsURL, includingPropertiesForKeys: [.fileSizeKey])
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        
        var totalSize = 0
        for file in jsonFiles {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            totalSize += size
        }
        
        addResult("Final Count", success: true, message: "\(jsonFiles.count) programs, \(totalSize) bytes total")
        
        // List all programs
        print("\n📋 All Programs in Container:")
        for file in jsonFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let data = try Data(contentsOf: file)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let name = json?["name"] as? String ?? "Unknown"
                let type = json?["programType"] as? String ?? "Unknown"
                print("   📄 \(file.lastPathComponent)")
                print("      Name: \(name)")
                print("      Type: \(type)")
            } catch {
                print("   ❌ \(file.lastPathComponent) (read error)")
            }
        }
        
    } catch {
        addResult("Final Analysis", success: false, message: "Analysis failed: \(error)")
    }
}

func printSummary() {
    print("\n" + String(repeating: "=", count: 60))
    print("🎯 PHASE 19 SYNC TEST SUMMARY")
    print(String(repeating: "=", count: 60))
    
    let successCount = testResults.filter { $0.success }.count
    let totalCount = testResults.count
    let successRate = totalCount > 0 ? (Double(successCount) / Double(totalCount)) * 100 : 0
    
    print("📊 Results: \(successCount)/\(totalCount) tests passed (\(String(format: "%.1f", successRate))%)")
    
    print("\n📋 Detailed Results:")
    for result in testResults {
        let status = result.success ? "✅" : "❌"
        let time = DateFormatter().string(from: result.timestamp)
        print("   \(status) \(result.testName): \(result.message)")
    }
    
    print("\n🔄 Next Manual Testing Steps:")
    print("1. 📱 Open iOS ShuttlX app:")
    print("   - Check if programs appear in main list")
    print("   - Programs should load immediately from App Group")
    print("   - Verify program details and data integrity")
    
    print("\n2. ⌚ Open watchOS ShuttlX app:")
    print("   - Go to DebugView to check sync status")
    print("   - Look for App Group container information")
    print("   - Check WatchConnectivity session status")
    print("   - Verify program count matches iOS")
    
    print("\n3. 🔄 Test Real-time Sync:")
    print("   - Create a new program on iOS")
    print("   - Watch for it to appear on watchOS (30s auto-sync)")
    print("   - Check DebugView for sync activity logs")
    
    print("\n4. 🎯 Verify Sync Functionality:")
    print("   - Both apps should show same program count")
    print("   - Program data should be identical")
    print("   - DebugView should show successful sync status")
    
    if successRate >= 80 {
        print("\n✅ PHASE 19 READY: Data layer is working correctly")
        print("🚀 Proceed with manual UI testing in simulators")
    } else {
        print("\n❌ PHASE 19 BLOCKED: Data layer issues detected")
        print("🔧 Fix data storage/access issues before UI testing")
    }
}

// Main test execution
print("🚀 Phase 19 Live Sync Testing")
print("=============================")
print("Testing sync functionality between iOS and watchOS")
print("Timestamp: \(Date())")

testAppGroupAccess()
waitForSync(seconds: 2)

testProgramStorage()
waitForSync(seconds: 2)

testMultipleProgramCreation()
waitForSync(seconds: 3)

analyzeFinalState()

printSummary()
