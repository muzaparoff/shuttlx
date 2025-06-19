//
//  ShuttlXUITests.swift
//  ShuttlXUITests
//
//  Automated UI Tests for ShuttlX iOS App
//  Created by ShuttlX on 6/15/25.
//

import XCTest

final class ShuttlXUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - CRITICAL TEST: Create "tests123" Custom Workout
    
    func testCreateTests123CustomWorkout() throws {
        print("🧪 [UI-TEST] Starting REAL automated creation of 'tests123' custom workout...")
        
        // Wait for app to fully load
        sleep(3)
        
        // Step 1: Navigate to Programs tab
        let programsTab = app.tabBars.buttons["Programs"] 
        if programsTab.exists {
            programsTab.tap()
            sleep(2) // Wait for tab to load
        } else {
            print("❌ [UI-TEST] Programs tab not found")
            XCTFail("Cannot navigate to Programs tab")
            return
        }
        
        // Step 2: Look for "Add" or "+" button to create new program
        var createButtonFound = false
        
        // Try multiple selectors for the create button
        let possibleButtons = [
            app.navigationBars.buttons["plus"],
            app.navigationBars.buttons["Add"],
            app.buttons["Add"],
            app.buttons["Create"],
            app.buttons["New Program"],
            app.buttons["+"]
        ]
        
        for button in possibleButtons {
            if button.exists {
                print("🧪 [UI-TEST] Found create button: \(button.label)")
                button.tap()
                createButtonFound = true
                break
            }
        }
        
        if !createButtonFound {
            print("❌ [UI-TEST] Could not find create workout button")
            // Take screenshot for debugging
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Programs_Screen_No_Create_Button"
            add(attachment)
            XCTFail("Could not find create workout button")
            return
        }
        
        // Wait for form to appear
        sleep(3)
        
        // Step 3: Fill in workout name "tests123"
        print("🧪 [UI-TEST] Filling workout form with tests123 details...")
        
        // Try multiple selectors for name field
        var nameFieldSet = false
        let possibleNameFields = [
            app.textFields["My Custom Training"],
            app.textFields.element(boundBy: 0),
            app.textFields["Program Name"],
            app.textFields["Name"]
        ]
        
        for field in possibleNameFields {
            if field.exists {
                print("🧪 [UI-TEST] Found name field: \(field.label)")
                field.tap()
                field.clearAndEnterText("tests123")
                nameFieldSet = true
                break
            }
        }
        
        if !nameFieldSet {
            print("❌ [UI-TEST] Could not find name field")
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Workout_Form_No_Name_Field"
            add(attachment)
        }
        
        // Step 4: Set minimal values for quick testing
        // Set distance to minimum (try sliders)
        let sliders = app.sliders
        if sliders.count >= 3 {
            // First slider: distance (set very low)
            sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 0.01)
            sleep(1)
            
            // Second slider: run interval (set to ~10 seconds)
            sliders.element(boundBy: 1).adjust(toNormalizedSliderPosition: 0.01)
            sleep(1)
            
            // Third slider: walk interval (set to ~10 seconds)
            sliders.element(boundBy: 2).adjust(toNormalizedSliderPosition: 0.01)
            sleep(1)
        }
        
        // Step 5: Save the workout
        print("🧪 [UI-TEST] Saving tests123 workout...")
        var saveButtonFound = false
        
        let possibleSaveButtons = [
            app.navigationBars.buttons["Save"],
            app.buttons["Save"],
            app.buttons["Create"],
            app.buttons["Done"],
            app.navigationBars.buttons["Done"]
        ]
        
        for button in possibleSaveButtons {
            if button.exists {
                print("🧪 [UI-TEST] Found save button: \(button.label)")
                button.tap()
                saveButtonFound = true
                break
            }
        }
        
        if !saveButtonFound {
            print("❌ [UI-TEST] Could not find save button")
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Workout_Form_No_Save_Button"
            add(attachment)
        }
        
        // Step 6: Verify workout was created and is visible
        print("🧪 [UI-TEST] Verifying tests123 workout is visible...")
        sleep(5) // Wait for navigation back and data to load
        
        // Look for the tests123 workout in the list
        let tests123Exists = app.staticTexts["tests123"].waitForExistence(timeout: 10)
        
        if tests123Exists {
            print("✅ [UI-TEST] SUCCESS: tests123 workout is VISIBLE in the app!")
            
            // Try to tap it to confirm it's interactive
            app.staticTexts["tests123"].tap()
            sleep(2)
            
            // Verify we can see workout details
            let workoutDetailVisible = app.staticTexts["tests123"].exists
            XCTAssertTrue(workoutDetailVisible, "Should be able to see workout details")
            
            print("✅ [UI-TEST] tests123 custom workout created and VERIFIED VISIBLE!")
        } else {
            print("❌ [UI-TEST] FAILED: tests123 workout is NOT VISIBLE in the app")
            
            // Take screenshot for debugging
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Programs_List_No_Tests123"
            add(attachment)
            
            XCTFail("tests123 workout was not created or is not visible")
        }
        
        // Store result for verification
        UserDefaults.standard.set(true, forKey: "tests123_workout_created")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "tests123_creation_timestamp")
        
        print("✅ [UI-TEST] Custom workout creation test completed!")
    }
    
    // MARK: - UI Test Helper Methods
    
    func testNavigateToPrograms() throws {
        print("🧪 [UI-TEST] Testing navigation to programs...")
        
        let programsTab = app.tabBars.buttons["Programs"]
        if programsTab.exists {
            programsTab.tap()
            XCTAssertTrue(app.navigationBars["Programs"].exists, "Should navigate to Programs tab")
        }
    }
    
    func testWorkoutListDisplay() throws {
        print("🧪 [UI-TEST] Testing workout list display...")
        
        // Navigate to programs first
        let programsTab = app.tabBars.buttons["Programs"]
        if programsTab.exists {
            programsTab.tap()
        }
        
        // Check if default programs are displayed
        let beginnerProgram = app.cells.containing(.staticText, identifier: "Beginner").firstMatch
        XCTAssertTrue(beginnerProgram.exists, "Default programs should be displayed")
    }
    
    func testCustomWorkoutFormValidation() throws {
        print("🧪 [UI-TEST] Testing custom workout form validation...")
        
        // Navigate to create workout
        let createButton = app.buttons["Create Custom Program"]
        if createButton.exists {
            createButton.tap()
            
            // Try to save without filling required fields
            let saveButton = app.buttons["Save Program"]
            if saveButton.exists {
                saveButton.tap()
                
                // Should show validation error
                let errorAlert = app.alerts.firstMatch
                XCTAssertTrue(errorAlert.exists, "Should show validation error for empty fields")
            }
        }
    }
}

// MARK: - XCUIElement Extensions for Better Testing

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        self.tap()
        self.press(forDuration: 1.0)
        let selectAllMenuItem = XCUIApplication().menuItems["Select All"]
        if selectAllMenuItem.exists {
            selectAllMenuItem.tap()
        }
        self.typeText(text)
    }
    
    func waitForExistenceAndTap(timeout: TimeInterval = 5) -> Bool {
        if self.waitForExistence(timeout: timeout) {
            self.tap()
            return true
        }
        return false
    }
}
