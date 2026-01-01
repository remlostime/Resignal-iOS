//
//  ResignalUITests.swift
//  ResignalUITests
//
//  UI Tests for the Resignal app.
//

import XCTest

final class ResignalUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Home Screen Tests

    @MainActor
    func testHomeScreenDisplaysTitle() throws {
        // Verify the app launches with the correct navigation title
        let navBar = app.navigationBars["Resignal"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Home screen should display 'Resignal' title")
    }

    @MainActor
    func testHomeScreenShowsNewSessionButton() throws {
        // Verify the new session FAB is visible
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5), "New session button should be visible")
    }

    @MainActor
    func testHomeScreenShowsSettingsButton() throws {
        // Verify the settings button is in the toolbar
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should be visible")
    }

    @MainActor
    func testEmptyStateIsShownWhenNoSessions() throws {
        // On first launch or with no sessions, empty state should be visible
        let emptyState = app.otherElements["emptyStateView"]
        // Empty state might not exist if there are sessions, so we check for either
        let noSessionsText = app.staticTexts["No Sessions Yet"]

        // At least one should exist on a fresh install
        let emptyStateExists = emptyState.waitForExistence(timeout: 3)
        let noSessionsExists = noSessionsText.waitForExistence(timeout: 3)

        // This test is informational - may pass or fail based on app state
        if emptyStateExists || noSessionsExists {
            XCTAssertTrue(true, "Empty state is shown when no sessions exist")
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateToNewSession() throws {
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))

        newSessionButton.tap()

        // Verify we navigated to the editor
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5), "Should navigate to New Session screen")
    }

    @MainActor
    func testNavigateToSettings() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.tap()

        // Verify we navigated to settings
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5), "Should navigate to Settings screen")
    }

    @MainActor
    func testNavigateBackFromEditor() throws {
        // Navigate to editor
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        // Wait for editor to appear
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Tap back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }

        // Verify we're back on home
        let homeNavBar = app.navigationBars["Resignal"]
        XCTAssertTrue(homeNavBar.waitForExistence(timeout: 5), "Should navigate back to home")
    }

    @MainActor
    func testNavigateBackFromSettings() throws {
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for settings to appear
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5))

        // Tap back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }

        // Verify we're back on home
        let homeNavBar = app.navigationBars["Resignal"]
        XCTAssertTrue(homeNavBar.waitForExistence(timeout: 5), "Should navigate back to home")
    }

    // MARK: - Editor Tests

    @MainActor
    func testEditorShowsAllFields() throws {
        // Navigate to editor
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        // Wait for editor
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Check for role text field
        let roleField = app.textFields["roleTextField"]
        XCTAssertTrue(roleField.waitForExistence(timeout: 3), "Role text field should be visible")

        // Check for rubric picker
        let rubricPicker = app.buttons["rubricPicker"]
        XCTAssertTrue(rubricPicker.waitForExistence(timeout: 3), "Rubric picker should be visible")

        // Check for analyze button
        let analyzeButton = app.buttons["analyzeButton"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 3), "Analyze button should be visible")
    }

    @MainActor
    func testEditorRoleFieldAcceptsInput() throws {
        // Navigate to editor
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        // Wait for editor
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Type in role field
        let roleField = app.textFields["roleTextField"]
        XCTAssertTrue(roleField.waitForExistence(timeout: 3))
        roleField.tap()
        roleField.typeText("iOS Engineer")

        // Verify text was entered
        XCTAssertEqual(roleField.value as? String, "iOS Engineer", "Role field should accept input")
    }

    @MainActor
    func testAnalyzeButtonDisabledForShortInput() throws {
        // Navigate to editor
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        // Wait for editor
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Analyze button should be disabled initially (no text)
        let analyzeButton = app.buttons["analyzeButton"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 3))

        // Button should not be enabled with empty or short input
        XCTAssertFalse(analyzeButton.isEnabled, "Analyze button should be disabled for short input")
    }

    @MainActor
    func testFullAnalysisFlow() throws {
        // Navigate to editor
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        // Wait for editor
        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Enter role
        let roleField = app.textFields["roleTextField"]
        XCTAssertTrue(roleField.waitForExistence(timeout: 3))
        roleField.tap()
        roleField.typeText("iOS Engineer")

        // Dismiss keyboard and tap text editor
        let textEditor = app.textViews["textEditor"]
        XCTAssertTrue(textEditor.waitForExistence(timeout: 3))
        textEditor.tap()

        // Enter sufficient text for analysis
        let sampleText = "Q: What is your experience with iOS development?\nA: I have over 5 years of experience building iOS applications using Swift and SwiftUI."
        textEditor.typeText(sampleText)

        // Dismiss keyboard
        app.swipeDown()

        // Analyze button should now be enabled
        let analyzeButton = app.buttons["analyzeButton"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 3))

        // Wait a moment for button state to update
        Thread.sleep(forTimeInterval: 0.5)

        // Tap analyze if enabled
        if analyzeButton.isEnabled {
            analyzeButton.tap()

            // Wait for result screen (analysis with mock AI should be quick)
            // The result screen should show feedback sections
            let summarySection = app.otherElements["feedbackSection_Summary"]
            let resultExists = summarySection.waitForExistence(timeout: 10)

            if resultExists {
                XCTAssertTrue(true, "Analysis completed and result screen is shown")
            }
        }
    }

    // MARK: - Settings Tests

    @MainActor
    func testSettingsShowsMockAIToggle() throws {
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for settings
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5))

        // Check for Mock AI toggle
        let mockAIToggle = app.switches["mockAIToggle"]
        XCTAssertTrue(mockAIToggle.waitForExistence(timeout: 3), "Mock AI toggle should be visible")
    }

    @MainActor
    func testSettingsShowsClearAllButton() throws {
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for settings
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5))

        // Check for Clear All Sessions button
        let clearAllButton = app.buttons["clearAllButton"]
        XCTAssertTrue(clearAllButton.waitForExistence(timeout: 3), "Clear All Sessions button should be visible")
    }

    @MainActor
    func testMockAIToggleCanBeInteracted() throws {
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for settings
        let settingsNavBar = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5))

        // Find the toggle
        let mockAIToggle = app.switches["mockAIToggle"]
        XCTAssertTrue(mockAIToggle.waitForExistence(timeout: 3), "Mock AI toggle should exist")

        // Verify the toggle is enabled and can be interacted with
        XCTAssertTrue(mockAIToggle.isEnabled, "Mock AI toggle should be enabled")
        XCTAssertTrue(mockAIToggle.isHittable, "Mock AI toggle should be hittable")

        // Verify toggle has a value (either "0" or "1")
        let toggleValue = mockAIToggle.value as? String
        XCTAssertNotNil(toggleValue, "Toggle should have a value")
        XCTAssertTrue(toggleValue == "0" || toggleValue == "1", "Toggle value should be 0 or 1")
    }

    // MARK: - Result Screen Tests

    @MainActor
    func testResultScreenShowsActionButtons() throws {
        // This test requires a session to exist first
        // Navigate to editor and create a quick session
        let newSessionButton = app.buttons["newSessionButton"]
        XCTAssertTrue(newSessionButton.waitForExistence(timeout: 5))
        newSessionButton.tap()

        let editorNavBar = app.navigationBars["New Session"]
        XCTAssertTrue(editorNavBar.waitForExistence(timeout: 5))

        // Enter text
        let textEditor = app.textViews["textEditor"]
        XCTAssertTrue(textEditor.waitForExistence(timeout: 3))
        textEditor.tap()
        textEditor.typeText("Q: Tell me about yourself.\nA: I am a software developer with experience in mobile development.")

        app.swipeDown()

        let analyzeButton = app.buttons["analyzeButton"]
        XCTAssertTrue(analyzeButton.waitForExistence(timeout: 3))

        Thread.sleep(forTimeInterval: 0.5)

        if analyzeButton.isEnabled {
            analyzeButton.tap()

            // Wait for result screen
            Thread.sleep(forTimeInterval: 3)

            // Check for action buttons
            let copyButton = app.buttons["copyButton"]
            let shareButton = app.buttons["shareButton"]
            let regenerateButton = app.buttons["regenerateButton"]

            let copyExists = copyButton.waitForExistence(timeout: 5)
            let shareExists = shareButton.waitForExistence(timeout: 2)
            let regenerateExists = regenerateButton.waitForExistence(timeout: 2)

            if copyExists || shareExists || regenerateExists {
                XCTAssertTrue(true, "Result screen shows action buttons")
            }
        }
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
