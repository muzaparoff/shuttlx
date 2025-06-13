#!/usr/bin/env swift

import Foundation

// Comprehensive test of the Recovery Run program interval generation
print("🔍 COMPREHENSIVE RECOVERY RUN ANALYSIS")
print("=====================================")

// Recovery Run program parameters (from ContentView.swift)
struct RecoveryRunProgram {
    let name = "Recovery Run"
    let distance = 3.0
    let runInterval = 4.0 // FIXED: Changed from 2.0 to match iOS version
    let walkInterval = 2.0 // FIXED: Changed from 3.0 to match iOS version  
    let totalDuration = 25.0 // FIXED: Changed from 30.0 to match iOS version
}

// Simulate the generateIntervals function
func generateIntervals(for program: RecoveryRunProgram) -> [(String, String, Int)] {
    var intervals: [(String, String, Int)] = []
    
    print("🔧 [INTERVAL-GEN] Generating intervals for '\(program.name)'")
    print("🔧 [INTERVAL-GEN] Program: run=\(program.runInterval)min, walk=\(program.walkInterval)min, total=\(program.totalDuration)min")
    
    // Add short warmup (1 minute instead of 5)
    intervals.append(("Warm Up", "warmup", 60)) // 1 minute warmup - FIXED: was 300s (5min)
    
    // Calculate number of run/walk cycles based on total duration
    let totalWorkoutTime = program.totalDuration * 60 // convert to seconds
    let warmupCooldownTime: TimeInterval = 120 // 2 minutes total (1min warmup + 1min cooldown)
    let availableTime = totalWorkoutTime - warmupCooldownTime
    let cycleTime = (program.runInterval + program.walkInterval) * 60 // convert to seconds
    let numberOfCycles = Int(availableTime / cycleTime)
    
    print("🔧 [INTERVAL-GEN] Available time: \(availableTime)s, cycle time: \(cycleTime)s, cycles: \(numberOfCycles)")
    
    // Add run/walk intervals
    for i in 0..<numberOfCycles {
        // Run interval
        let runDuration = Int(program.runInterval * 60)
        intervals.append(("Run \(i + 1)", "work", runDuration))
        print("🔧 [INTERVAL-GEN] Added Run \(i + 1): \(runDuration)s (\(program.runInterval)min)")
        
        // Walk interval (except after the last run)
        if i < numberOfCycles - 1 {
            let walkDuration = Int(program.walkInterval * 60)
            intervals.append(("Walk \(i + 1)", "rest", walkDuration))
            print("🔧 [INTERVAL-GEN] Added Walk \(i + 1): \(walkDuration)s (\(program.walkInterval)min)")
        }
    }
    
    // Add short cooldown (1 minute instead of 5)
    intervals.append(("Cool Down", "cooldown", 60)) // 1 minute cooldown - FIXED: was 300s (5min)
    
    return intervals
}

// Test the Recovery Run program
let program = RecoveryRunProgram()
let intervals = generateIntervals(for: program)

print("\n📋 GENERATED INTERVALS:")
for (index, interval) in intervals.enumerated() {
    let minutes = interval.2 / 60
    let seconds = interval.2 % 60
    let formattedTime = String(format: "%02d:%02d", minutes, seconds)
    print("   \(index + 1). \(interval.0) (\(interval.1)) - \(formattedTime) (\(interval.2)s)")
}

print("\n🎯 ANALYSIS:")
print("- First interval: \(intervals[0].0) - \(intervals[0].2)s")
print("- Formatted first interval: \(String(format: "%02d:%02d", intervals[0].2 / 60, intervals[0].2 % 60))")

if intervals[0].2 == 300 {
    print("❌ ERROR: First interval is 05:00 (300s) - this is the OLD warmup duration!")
} else if intervals[0].2 == 60 {
    print("✅ CORRECT: First interval is 01:00 (60s) - this is the FIXED warmup duration!")
} else {
    print("❓ UNEXPECTED: First interval is \(intervals[0].2)s")
}

print("\n🔍 EXPECTED TIMER BEHAVIOR:")
print("When workout starts, timer should show: \(String(format: "%02d:%02d", intervals[0].2 / 60, intervals[0].2 % 60))")
print("If showing 05:00, there's either:")
print("1. A caching issue with old interval data")  
print("2. Timer displaying wrong interval")
print("3. Different interval generation function being used")

print("\n📊 TOTAL WORKOUT ANALYSIS:")
let totalTime = intervals.reduce(0) { $0 + $1.2 }
print("- Total intervals: \(intervals.count)")
print("- Total time: \(totalTime)s (\(totalTime / 60) minutes)")
print("- Expected total: \(Int(program.totalDuration * 60))s (\(program.totalDuration) minutes)")

// Test if there's a difference
let difference = abs(totalTime - Int(program.totalDuration * 60))
if difference > 60 { // More than 1 minute difference
    print("⚠️  WARNING: Significant time difference of \(difference)s")
} else {
    print("✅ Time calculation looks correct (difference: \(difference)s)")
}
