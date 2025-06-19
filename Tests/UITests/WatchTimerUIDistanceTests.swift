//
//  WatchTimerUIDistanceTests.swift
//  ShuttlXUITests
//
//  Created by ShuttlX on 6/15/25.
//

import XCTest

final class WatchTimerUIDistanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testWatchOSTimerCountdownDisplay() throws {
        // This test verifies the timer displays and counts down properly
        
        // Wait for app to load
        XCTAssertTrue(app.waitForExistence(timeout: 5.0))
        
        // Look for training program selection
        let selectProgramButton = app.buttons.matching(identifier: "trainingProgram").firstMatch
        if selectProgramButton.exists {
            selectProgramButton.tap()
        }
        
        // Look for start training button
        let startButton = app.buttons["Start Training"]
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Wait a moment for workout to initialize
            Thread.sleep(forTimeInterval: 2.0)
            
            // Check that timer is not stuck at 00:00
            let timerText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':'")).firstMatch
            if timerText.waitForExistence(timeout: 5.0) {
                let initialTime = timerText.label
                print("Initial timer display: \(initialTime)")
                
                // Verify it's not stuck at 00:00
                XCTAssertNotEqual(initialTime, "00:00", "Timer should not be stuck at 00:00")
                
                // Wait a few seconds and verify countdown
                Thread.sleep(forTimeInterval: 3.0)
                let updatedTime = timerText.label
                print("Updated timer display: \(updatedTime)")
                
                // Timer should have changed (countdown or different value)
                if initialTime != "00:00" && updatedTime != "00:00" {
                    // Should see countdown happening
                    XCTAssertNotEqual(initialTime, updatedTime, "Timer should be counting down")
                }
            }
        }
    }
    
    func testDistanceProgressDisplay() throws {
        // This test verifies distance progress is shown in the UI
        
        XCTAssertTrue(app.waitForExistence(timeout: 5.0))
        
        // Start a workout
        let selectProgramButton = app.buttons.matching(identifier: "trainingProgram").firstMatch
        if selectProgramButton.exists {
            selectProgramButton.tap()
        }
        
        let startButton = app.buttons["Start Training"]
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Look for distance display
            let distanceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'km'")).firstMatch
            
            if distanceText.waitForExistence(timeout: 5.0) {
                let distanceLabel = distanceText.label
                print("Distance display found: \(distanceLabel)")
                
                // Should show distance format like "0.00 / 5.0 km"
                XCTAssertTrue(distanceLabel.contains("km"), "Should display km units")
                XCTAssertTrue(distanceLabel.contains("/"), "Should show progress format")
            }
        }
    }
    
    func testCurrentActivityDisplay() throws {
        // This test verifies current activity (Walk/Run) is displayed
        
        XCTAssertTrue(app.waitForExistence(timeout: 5.0))
        
        // Start a workout
        let selectProgramButton = app.buttons.matching(identifier: "trainingProgram").firstMatch
        if selectProgramButton.exists {
            selectProgramButton.tap()
        }
        
        let startButton = app.buttons["Start Training"]
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Look for activity display (WALK or RUN)
            let walkText = app.staticTexts["WALK"]
            let runText = app.staticTexts["RUN"]
            let restText = app.staticTexts["REST"]
            let workText = app.staticTexts["WORK"]
            
            // Should show one of these activity indicators
            let foundActivity = walkText.waitForExistence(timeout: 5.0) ||
                               runText.waitForExistence(timeout: 2.0) ||
                               restText.waitForExistence(timeout: 2.0) ||
                               workText.waitForExistence(timeout: 2.0)
            
            XCTAssertTrue(foundActivity, "Should display current activity (Walk/Run/Rest/Work)")
            
            if walkText.exists {
                print("Current activity: WALK")
            } else if runText.exists {
                print("Current activity: RUN")
            } else if restText.exists {
                print("Current activity: REST")
            } else if workText.exists {
                print("Current activity: WORK")
            }
        }
    }
    
    func testTimerNotStuckAtZero() throws {
        // Primary test - ensure timer is not stuck at 00:00
        
        XCTAssertTrue(app.waitForExistence(timeout: 5.0))
        
        // Start workout
        let selectProgramButton = app.buttons.matching(identifier: "trainingProgram").firstMatch
        if selectProgramButton.exists {
            selectProgramButton.tap()
        }
        
        let startButton = app.buttons["Start Training"]
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Give timer time to initialize
            Thread.sleep(forTimeInterval: 2.0)
            
            // Check for timer display
            let allTexts = app.staticTexts.allElementsBoundByIndex
            var timerFound = false
            var timerValue = ""
            
            for text in allTexts {
                let label = text.label
                if label.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
                    timerFound = true
                    timerValue = label
                    print("Found timer display: \(timerValue)")
                    break
                }
            }
            
            if timerFound {
                // Critical assertion - timer should NOT be stuck at 00:00
                XCTAssertNotEqual(timerValue, "00:00", "CRITICAL: Timer is stuck at 00:00 - this is the main bug!")
                
                // If timer shows valid time, verify it's counting down
                if timerValue != "00:00" {
                    Thread.sleep(forTimeInterval: 3.0)
                    
                    // Check if it changed
                    for text in app.staticTexts.allElementsBoundByIndex {
                        let newLabel = text.label
                        if newLabel.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
                            print("Timer after 3s: \(newLabel)")
                            // Timer should either be counting down or showing different value
                            XCTAssertTrue(newLabel != timerValue || newLabel == "00:00", "Timer should be counting down")
                            break
                        }
                    }
                }
            } else {
                XCTFail("No timer display found in format MM:SS")
            }
        }
    }
    
    func testWorkoutFlow() throws {
        // Test complete workout flow
        
        XCTAssertTrue(app.waitForExistence(timeout: 5.0))
        
        // Navigate to workout start
        let selectProgramButton = app.buttons.matching(identifier: "trainingProgram").firstMatch
        if selectProgramButton.exists {
            selectProgramButton.tap()
        }
        
        let startButton = app.buttons["Start Training"]
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Verify workout screen elements
            Thread.sleep(forTimeInterval: 2.0)
            
            // Should see timer
            let timerExists = app.staticTexts.matching(NSPredicate(format: "label MATCHES '^\\\\d{2}:\\\\d{2}$'")).firstMatch.exists
            XCTAssertTrue(timerExists, "Timer should be visible")
            
            // Should see pause/stop buttons
            let pauseButton = app.buttons["Pause"]
            let stopButton = app.buttons["End Workout"]
            
            XCTAssertTrue(pauseButton.waitForExistence(timeout: 3.0) || stopButton.waitForExistence(timeout: 3.0),
                         "Should have workout control buttons")
            
            print("✅ Workout flow test complete")
        }
    }
}
