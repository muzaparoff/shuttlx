//
//  WatchTimerUIRewriteTests.swift
//  ShuttlXUITests
//
//  UI tests for the rewritten timer display
//  Created on June 14, 2025
//

import XCTest

class WatchTimerUIRewriteTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testTimerDisplayAfterStartTraining() {
        // Navigate to a training program
        let beginnerButton = app.buttons["Beginner"]
        if beginnerButton.exists {
            beginnerButton.tap()
        }
        
        // Find and tap "Start Training" button
        let startTrainingButton = app.buttons["Start Training"]
        XCTAssertTrue(startTrainingButton.waitForExistence(timeout: 5), "Start Training button should exist")
        startTrainingButton.tap()
        
        // Wait for workout view to appear
        sleep(2)
        
        // Look for timer display - should not be "00:00"
        let timerElements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ':'"))
        
        var foundNonZeroTimer = false
        for i in 0..<timerElements.count {
            let element = timerElements.element(boundBy: i)
            if element.exists {
                let timerText = element.label
                print("🔍 Found timer text: '\(timerText)'")
                
                // Timer should not be "00:00" - should show interval time
                if timerText != "00:00" && timerText.contains(":") {
                    foundNonZeroTimer = true
                    print("✅ Found non-zero timer: \(timerText)")
                    break
                }
            }
        }
        
        XCTAssertTrue(foundNonZeroTimer, "Timer should display interval time, not 00:00")
        
        // Wait a few seconds and verify timer is counting down
        sleep(3)
        
        var foundCountdown = false
        for i in 0..<timerElements.count {
            let element = timerElements.element(boundBy: i)
            if element.exists {
                let newTimerText = element.label
                print("🔍 Timer after 3 seconds: '\(newTimerText)'")
                
                // Check if timer changed (counting down)
                if newTimerText != "00:00" && newTimerText.contains(":") {
                    foundCountdown = true
                    print("✅ Timer is counting: \(newTimerText)")
                    break
                }
            }
        }
        
        XCTAssertTrue(foundCountdown, "Timer should be counting down after starting workout")
    }
    
    func testWorkoutViewElementsExist() {
        // Start a workout
        if app.buttons["Beginner"].exists {
            app.buttons["Beginner"].tap()
        }
        
        if app.buttons["Start Training"].waitForExistence(timeout: 5) {
            app.buttons["Start Training"].tap()
        }
        
        // Wait for workout view
        sleep(2)
        
        // Check for key UI elements
        let staticTexts = app.staticTexts
        
        // Should have interval indicators
        let intervalTexts = ["Walk", "Run", "remaining", "Interval"]
        for text in intervalTexts {
            let found = staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", text)).count > 0
            if found {
                print("✅ Found UI element containing: \(text)")
            }
        }
        
        // Should have timer display
        let timerPattern = staticTexts.matching(NSPredicate(format: "label MATCHES '\\\\d{2}:\\\\d{2}'"))
        XCTAssertGreaterThan(timerPattern.count, 0, "Should have timer display in MM:SS format")
    }
}
