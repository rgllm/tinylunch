import XCTest

final class TinyLunchUITests: XCTestCase {
    @MainActor func testExplicitSavePartialHistoryAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Incomplete estimate"].firstMatch.waitForExistence(timeout: 10))
        let save = app.buttons["saveMeal"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Rice, Unidentified sauce"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Rice, Unidentified sauce"].waitForExistence(timeout: 5))
    }

    @MainActor func testNormalBuildDoesNotShowFixtureMeal() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history"]
        app.launch()
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["saveMeal"].exists)
        XCTAssertFalse(app.buttons["editFood-Rice"].exists)
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No saved meals"].waitForExistence(timeout: 5))
    }

    @MainActor func testPortionCorrectionBeforeSaving() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal"]
        app.launch()
        let rice = app.buttons["editFood-Rice"]
        XCTAssertTrue(rice.waitForExistence(timeout: 10))
        rice.tap()
        app.buttons["Double"].tap()
        app.buttons["Apply"].tap()
        XCTAssertTrue(app.staticTexts["mealCalories"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["mealCalories"].label, "390 kcal")
        app.buttons["saveMeal"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["390 kcal"].waitForExistence(timeout: 5))
    }

    @MainActor func testHiddenPlateAndWordmarkSurprises() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history"]
        app.launch()
        let plate = app.buttons["emojiPlate"]
        XCTAssertTrue(plate.waitForExistence(timeout: 10))
        for _ in 0..<5 { plate.tap() }
        XCTAssertTrue(app.staticTexts["The chef’s table"].waitForExistence(timeout: 5))
        app.buttons["Surprise me"].tap()
        XCTAssertTrue(app.staticTexts["On the house."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.staticTexts["tinyLunchWordmark"].press(forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["A little toast."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(plate.exists)
    }


    @MainActor func testLargestTextKeepsCaptureReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let capture = app.buttons["Take photo"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for title in ["Don’t Allow", "Don't Allow", "Cancel"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        capture.tap()
        dismissCameraPath(in: app)
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No saved meals"].waitForExistence(timeout: 5))
    }

    /// iOS 27 Simulator can present a camera permission alert or the picker instead of the older "camera unavailable" alert.
    @MainActor private func dismissCameraPath(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let dontAllow = springboard.alerts.buttons["Don’t Allow"].firstMatch
        let dontAllowPlain = springboard.alerts.buttons["Don't Allow"].firstMatch
        if dontAllow.waitForExistence(timeout: 3) {
            dontAllow.tap()
        } else if dontAllowPlain.waitForExistence(timeout: 1) {
            dontAllowPlain.tap()
        }
        if app.alerts["Something needs attention"].waitForExistence(timeout: 2) {
            app.alerts.buttons["OK"].tap()
            return
        }
        if app.alerts["Camera access is off"].waitForExistence(timeout: 2) {
            app.alerts.buttons["Cancel"].tap()
            return
        }
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 8), "Expected a recoverable camera path at the largest text size.")
        cancel.tap()
    }

}
