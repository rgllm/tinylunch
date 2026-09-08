import XCTest

final class NoshUITests: XCTestCase {
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

    @MainActor func testNormalBuildShowsUnavailableWithoutFakeMeal() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Photo analysis unavailable"].waitForExistence(timeout: 10))
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
        app.staticTexts["noshWordmark"].press(forDuration: 1.2)
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
        capture.tap()
        XCTAssertTrue(app.alerts["Something needs attention"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No saved meals"].waitForExistence(timeout: 5))
    }

}
