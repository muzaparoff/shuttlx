#!/usr/bin/env swift

import Foundation

// Test App Group container accessibility and sync data integrity
func diagnoseSyncIssues() {
    print("🔍 ShuttlX Sync Diagnosis Tool")
    print(String(repeating: "=", count: 50))
    
    let appGroupID = "group.com.shuttlx.shared"
    let fileManager = FileManager.default
    
    // Test App Group container access
    print("\n📂 Testing App Group Container Access:")
    if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
        print("✅ App Group container accessible: \(containerURL.path)")
        
        // Check if directory exists
        if fileManager.fileExists(atPath: containerURL.path) {
            print("✅ Container directory exists")
            
            // List contents
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: containerURL.path)
                print("📁 Container contents: \(contents)")
                
                // Check for programs.json
                let programsPath = containerURL.appendingPathComponent("programs.json").path
                if fileManager.fileExists(atPath: programsPath) {
                    print("✅ programs.json exists")
                    
                    // Try to read and parse programs
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: programsPath))
                        let programs = try JSONDecoder().decode([TrainingProgram].self, from: data)
                        print("✅ Successfully decoded \(programs.count) programs:")
                        for (index, program) in programs.enumerated() {
                            print("   \(index + 1). \(program.name) - \(program.intervals.count) intervals")
                        }
                    } catch {
                        print("❌ Failed to decode programs: \(error)")
                    }
                } else {
                    print("⚠️  programs.json does not exist")
                }
                
                // Check for sessions.json
                let sessionsPath = containerURL.appendingPathComponent("sessions.json").path
                if fileManager.fileExists(atPath: sessionsPath) {
                    print("✅ sessions.json exists")
                } else {
                    print("⚠️  sessions.json does not exist")
                }
                
            } catch {
                print("❌ Failed to list container contents: \(error)")
            }
        } else {
            print("⚠️  Container directory does not exist")
        }
    } else {
        print("❌ App Group container not accessible")
    }
    
    // Test fallback container
    print("\n📂 Testing Fallback Container:")
    let fallbackURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SharedData")
    print("📍 Fallback path: \(fallbackURL.path)")
    
    if fileManager.fileExists(atPath: fallbackURL.path) {
        print("✅ Fallback directory exists")
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: fallbackURL.path)
            print("📁 Fallback contents: \(contents)")
        } catch {
            print("❌ Failed to list fallback contents: \(error)")
        }
    } else {
        print("⚠️  Fallback directory does not exist")
    }
    
    print("\n🔧 Sync Diagnosis Complete")
}

// Minimal TrainingProgram structure for testing
struct TrainingProgram: Codable {
    let id: UUID
    let name: String
    let intervals: [TrainingInterval]
    
    init(name: String, intervals: [TrainingInterval]) {
        self.id = UUID()
        self.name = name
        self.intervals = intervals
    }
}

struct TrainingInterval: Codable {
    let id: UUID
    let phase: String
    let duration: TimeInterval
    
    init(phase: String, duration: TimeInterval) {
        self.id = UUID()
        self.phase = phase
        self.duration = duration
    }
}

// Run diagnosis
diagnoseSyncIssues()
