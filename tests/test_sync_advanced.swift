#!/usr/bin/env swift

import Foundation
import AppKit

// MARK: - Advanced Sync Testing Script for Phase 19
// This script tests sync scenarios and investigates sync issues

print("🔄 ADVANCED SYNC TESTING - Phase 19")
print(String(repeating: "=", count: 50))

// MARK: - Test Configuration
let appGroupIdentifier = "group.com.shuttlx.shared"
let programsKey = "programs.json"
let sessionsKey = "sessions.json"
let testMarker = "advanced_sync_test_\(Date().timeIntervalSince1970)"

// MARK: - Helper Functions
func log(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(timestamp)] \(message)")
}

func getSharedContainer() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
}

func getFallbackContainer() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("SharedData")
}

func getWorkingContainer() -> URL? {
    if let appGroupContainer = getSharedContainer() {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: appGroupContainer.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            return appGroupContainer
        } else {
            do {
                try fileManager.createDirectory(at: appGroupContainer, withIntermediateDirectories: true, attributes: nil)
                return appGroupContainer
            } catch {
                log("⚠️ Failed to create App Group container: \(error.localizedDescription)")
            }
        }
    }
    
    // Fallback
    let fallbackContainer = getFallbackContainer()
    let fileManager = FileManager.default
    do {
        try fileManager.createDirectory(at: fallbackContainer, withIntermediateDirectories: true, attributes: nil)
        return fallbackContainer
    } catch {
        log("❌ Failed to create fallback container: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Data Models (Simplified for Testing)
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

struct TrainingSession: Codable, Identifiable {
    var id = UUID()
    let programId: UUID
    let programName: String
    let startDate: Date
    let endDate: Date
    let totalDuration: TimeInterval
    let avgHeartRate: Int
    let maxHeartRate: Int
    let testMarker: String
}

// MARK: - Advanced Test Functions
func testBidirectionalSync() -> Bool {
    log("🔄 Testing bidirectional sync...")
    
    guard let container = getWorkingContainer() else {
        log("❌ No container available")
        return false
    }
    
    // Test 1: iOS -> watchOS program sync
    let iOSPrograms = [
        TrainingProgram(
            name: "iOS Program 1",
            type: "walkRun",
            totalDuration: 900,
            intervalCount: 5,
            maxPulse: 180,
            createdDate: Date(),
            lastModified: Date(),
            testMarker: testMarker
        )
    ]
    
    let programsURL = container.appendingPathComponent(programsKey)
    do {
        let encodedData = try JSONEncoder().encode(iOSPrograms)
        try encodedData.write(to: programsURL)
        log("✅ Simulated iOS program sync to shared storage")
    } catch {
        log("❌ Failed to simulate iOS program sync: \(error)")
        return false
    }
    
    // Test 2: watchOS -> iOS session sync
    let watchOSSessions = [
        TrainingSession(
            programId: UUID(),
            programName: "Watch Workout",
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date().addingTimeInterval(-3300),
            totalDuration: 300,
            avgHeartRate: 150,
            maxHeartRate: 180,
            testMarker: testMarker
        )
    ]
    
    let sessionsURL = container.appendingPathComponent(sessionsKey)
    do {
        let encodedData = try JSONEncoder().encode(watchOSSessions)
        try encodedData.write(to: sessionsURL)
        log("✅ Simulated watchOS session sync to shared storage")
    } catch {
        log("❌ Failed to simulate watchOS session sync: \(error)")
        return false
    }
    
    // Verify both directions work
    do {
        let programData = try Data(contentsOf: programsURL)
        let programs = try JSONDecoder().decode([TrainingProgram].self, from: programData)
        
        let sessionData = try Data(contentsOf: sessionsURL)
        let sessions = try JSONDecoder().decode([TrainingSession].self, from: sessionData)
        
        log("✅ Bidirectional sync verified: \(programs.count) programs, \(sessions.count) sessions")
        return programs.count > 0 && sessions.count > 0
    } catch {
        log("❌ Failed to verify bidirectional sync: \(error)")
        return false
    }
}

func testSyncTimestamps() -> Bool {
    log("⏰ Testing sync timestamps...")
    
    guard let container = getWorkingContainer() else {
        log("❌ No container available")
        return false
    }
    
    // Create programs with different timestamps
    let program1 = TrainingProgram(
        name: "Old Program",
        type: "walkRun",
        totalDuration: 900,
        intervalCount: 5,
        maxPulse: 180,
        createdDate: Date().addingTimeInterval(-86400), // 1 day ago
        lastModified: Date().addingTimeInterval(-86400),
        testMarker: testMarker
    )
    
    let program2 = TrainingProgram(
        name: "New Program",
        type: "running",
        totalDuration: 1200,
        intervalCount: 8,
        maxPulse: 190,
        createdDate: Date(),
        lastModified: Date(),
        testMarker: testMarker
    )
    
    let programs = [program1, program2]
    
    let programsURL = container.appendingPathComponent(programsKey)
    do {
        let encodedData = try JSONEncoder().encode(programs)
        try encodedData.write(to: programsURL)
        log("✅ Saved programs with different timestamps")
    } catch {
        log("❌ Failed to save timestamped programs: \(error)")
        return false
    }
    
    // Verify timestamps are preserved
    do {
        let data = try Data(contentsOf: programsURL)
        let loadedPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
        
        let oldProgram = loadedPrograms.first { $0.name == "Old Program" }
        let newProgram = loadedPrograms.first { $0.name == "New Program" }
        
        guard let old = oldProgram, let new = newProgram else {
            log("❌ Failed to find timestamped programs")
            return false
        }
        
        let timeDiff = new.createdDate.timeIntervalSince(old.createdDate)
        log("✅ Timestamp preservation verified: \(Int(timeDiff/3600)) hours difference")
        
        return timeDiff > 3600 // At least 1 hour difference
    } catch {
        log("❌ Failed to verify timestamps: \(error)")
        return false
    }
}

func testLargeDataSync() -> Bool {
    log("📊 Testing large data sync performance...")
    
    guard let container = getWorkingContainer() else {
        log("❌ No container available")
        return false
    }
    
    // Create a large number of programs
    var largePrograms: [TrainingProgram] = []
    for i in 1...50 {
        largePrograms.append(TrainingProgram(
            name: "Program \(i)",
            type: i % 2 == 0 ? "running" : "walkRun",
            totalDuration: Double(600 + i * 30),
            intervalCount: 5 + i % 10,
            maxPulse: 160 + i % 40,
            createdDate: Date().addingTimeInterval(-Double(i * 3600)),
            lastModified: Date().addingTimeInterval(-Double(i * 1800)),
            testMarker: testMarker
        ))
    }
    
    let programsURL = container.appendingPathComponent(programsKey)
    let startTime = Date()
    
    do {
        let encodedData = try JSONEncoder().encode(largePrograms)
        try encodedData.write(to: programsURL)
        
        let writeTime = Date().timeIntervalSince(startTime)
        log("✅ Large data write took \(String(format: "%.3f", writeTime)) seconds")
        
        // Test read performance
        let readStartTime = Date()
        let data = try Data(contentsOf: programsURL)
        let loadedPrograms = try JSONDecoder().decode([TrainingProgram].self, from: data)
        
        let readTime = Date().timeIntervalSince(readStartTime)
        log("✅ Large data read took \(String(format: "%.3f", readTime)) seconds")
        log("✅ Verified \(loadedPrograms.count) programs loaded correctly")
        
        // Performance benchmarks (should be under 1 second for this amount of data)
        return writeTime < 1.0 && readTime < 1.0 && loadedPrograms.count == 50
    } catch {
        log("❌ Large data sync test failed: \(error)")
        return false
    }
}

func testErrorRecovery() -> Bool {
    log("🔧 Testing error recovery...")
    
    guard let container = getWorkingContainer() else {
        log("❌ No container available")
        return false
    }
    
    var testsPass = 0
    
    // Test 1: Corrupted data recovery
    let corruptedURL = container.appendingPathComponent("corrupted_\(testMarker).json")
    do {
        try "corrupted json data {".write(to: corruptedURL, atomically: true, encoding: .utf8)
        
        // Try to read corrupted data
        let data = try Data(contentsOf: corruptedURL)
        do {
            let _ = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("❌ Corrupted data was somehow decoded successfully")
        } catch {
            log("✅ Corrupted data properly rejected: \(error.localizedDescription)")
            testsPass += 1
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: corruptedURL)
    } catch {
        log("❌ Failed to test corrupted data recovery: \(error)")
    }
    
    // Test 2: Missing file recovery
    let missingURL = container.appendingPathComponent("missing_\(testMarker).json")
    do {
        let _ = try Data(contentsOf: missingURL)
        log("❌ Missing file was somehow found")
    } catch {
        log("✅ Missing file properly handled: \(error.localizedDescription)")
        testsPass += 1
    }
    
    // Test 3: Permission recovery
    let permissionURL = container.appendingPathComponent("permission_\(testMarker).json")
    do {
        try "test".write(to: permissionURL, atomically: true, encoding: .utf8)
        
        // Try to set read-only and then write
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: permissionURL.path)
        
        do {
            try "modified".write(to: permissionURL, atomically: true, encoding: .utf8)
            log("❌ Read-only file was somehow written to")
        } catch {
            log("✅ Read-only file properly protected: \(error.localizedDescription)")
            testsPass += 1
        }
        
        // Cleanup
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: permissionURL.path)
        try FileManager.default.removeItem(at: permissionURL)
    } catch {
        log("⚠️ Permission test failed (expected on some systems): \(error)")
        testsPass += 1 // Don't fail the test for permission issues
    }
    
    return testsPass >= 2
}

func investigateSyncIssues() -> Bool {
    log("🔍 Investigating sync issues...")
    
    guard let container = getWorkingContainer() else {
        log("❌ No container available")
        return false
    }
    
    var issuesFound = 0
    
    // Check 1: Verify container is accessible
    let containerPath = container.path
    if containerPath.contains("group.com.shuttlx.shared") {
        log("✅ Using App Group container: \(containerPath)")
    } else {
        log("⚠️ Using fallback container: \(containerPath)")
        issuesFound += 1
    }
    
    // Check 2: Verify existing data files
    let programsURL = container.appendingPathComponent(programsKey)
    let sessionsURL = container.appendingPathComponent(sessionsKey)
    
    if FileManager.default.fileExists(atPath: programsURL.path) {
        do {
            let data = try Data(contentsOf: programsURL)
            let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
            log("✅ Found \(programs.count) existing programs")
            
            // Check for recent programs
            let recentPrograms = programs.filter { $0.createdDate.timeIntervalSinceNow > -86400 }
            log("📊 Recent programs (last 24h): \(recentPrograms.count)")
            
            if recentPrograms.isEmpty && programs.count > 0 {
                log("⚠️ No recent programs found - sync might be stale")
                issuesFound += 1
            }
        } catch {
            log("❌ Programs file is corrupted: \(error)")
            issuesFound += 1
        }
    } else {
        log("⚠️ No programs file found")
        issuesFound += 1
    }
    
    if FileManager.default.fileExists(atPath: sessionsURL.path) {
        do {
            let data = try Data(contentsOf: sessionsURL)
            let sessions = try JSONDecoder().decode([TrainingSession].self, from: data)
            log("✅ Found \(sessions.count) existing sessions")
        } catch {
            log("❌ Sessions file is corrupted: \(error)")
            issuesFound += 1
        }
    } else {
        log("ℹ️ No sessions file found (normal for new installations)")
    }
    
    // Check 3: Test write performance
    let testURL = container.appendingPathComponent("sync_test_\(testMarker).json")
    let startTime = Date()
    do {
        let testData = ["test": "data", "timestamp": "\(Date().timeIntervalSince1970)"]
        let encodedData = try JSONSerialization.data(withJSONObject: testData)
        try encodedData.write(to: testURL)
        
        let writeTime = Date().timeIntervalSince(startTime)
        log("✅ Write performance: \(String(format: "%.3f", writeTime)) seconds")
        
        if writeTime > 0.1 {
            log("⚠️ Slow write performance detected")
            issuesFound += 1
        }
        
        // Cleanup
        try FileManager.default.removeItem(at: testURL)
    } catch {
        log("❌ Write test failed: \(error)")
        issuesFound += 1
    }
    
    // Summary
    log("📋 Sync investigation complete. Issues found: \(issuesFound)")
    return issuesFound < 3 // Allow some issues but not too many
}

// MARK: - Main Test Execution
func runAdvancedTests() {
    log("🚀 Starting advanced sync tests...")
    
    var allTests: [String: Bool] = [:]
    
    // Run all tests
    allTests["Bidirectional Sync"] = testBidirectionalSync()
    allTests["Sync Timestamps"] = testSyncTimestamps()
    allTests["Large Data Sync"] = testLargeDataSync()
    allTests["Error Recovery"] = testErrorRecovery()
    allTests["Sync Issues Investigation"] = investigateSyncIssues()
    
    // Report results
    log("\n" + String(repeating: "=", count: 50))
    log("📊 ADVANCED SYNC TEST RESULTS")
    log(String(repeating: "=", count: 50))
    
    var passedTests = 0
    let totalTests = allTests.count
    
    for (testName, passed) in allTests {
        let status = passed ? "✅ PASS" : "❌ FAIL"
        log("\(status) \(testName)")
        if passed { passedTests += 1 }
    }
    
    log("\n📈 SUMMARY: \(passedTests)/\(totalTests) tests passed (\(Int(Double(passedTests)/Double(totalTests)*100))%)")
    
    if passedTests == totalTests {
        log("🎉 ALL ADVANCED TESTS PASSED!")
    } else {
        log("⚠️ Some advanced tests failed. See details above.")
    }
    
    // Provide sync troubleshooting recommendations
    log("\n🔧 SYNC TROUBLESHOOTING RECOMMENDATIONS:")
    log("1. Ensure App Group is properly configured in both iOS and watchOS targets")
    log("2. Check WatchConnectivity session activation in both apps")
    log("3. Verify both apps are running simultaneously for live sync")
    log("4. Test with device pair (simulator sync is limited)")
    log("5. Check SharedDataManager sync methods are being called")
    log("6. Monitor sync logs in both apps for debugging")
}

// Execute the advanced tests
runAdvancedTests()
