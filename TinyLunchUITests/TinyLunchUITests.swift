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
        tapVisible(rice, in: app)
        let doubled = app.buttons["Double"]
        scrollUntilExists(doubled, in: app)
        doubled.tap()
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


    @MainActor func testWordmarkStaysOneLineBelowTheStatusBar() {
        assertWordmarkLayout(sizeCategory: "UICTContentSizeCategoryLarge")
        assertWordmarkLayout(sizeCategory: "UICTContentSizeCategoryAccessibilityXL")
    }

    @MainActor private func assertWordmarkLayout(sizeCategory: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "-UIPreferredContentSizeCategoryName", sizeCategory]
        app.launch()
        let title = app.staticTexts["tinyLunchWordmark"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Missing TinyLunch title at \(sizeCategory)")
        XCTAssertEqual(title.label, "TinyLunch")
        let frame = title.frame
        XCTAssertFalse(frame.isEmpty)
        XCTAssertGreaterThan(frame.width, frame.height * 1.5, "TinyLunch title wrapped at \(sizeCategory)")
        let statusBar = app.statusBars.firstMatch
        XCTAssertTrue(statusBar.waitForExistence(timeout: 2))
        XCTAssertGreaterThanOrEqual(
            frame.minY,
            statusBar.frame.maxY - 1,
            "TinyLunch title overlaps the status bar at \(sizeCategory)"
        )
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1)
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

    @MainActor func testMedicalDisclaimerOnReviewAboutAndSavedMeal() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal"]
        app.launch()
        assertVisibleDisclaimer(in: app)

        app.terminate()
        app.launchArguments = ["--ui-testing", "--reset-history"]
        app.launch()
        let aboutButton = app.buttons["aboutPrivacy"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 10))
        aboutButton.tap()
        XCTAssertTrue(app.staticTexts["Not a medical device"].waitForExistence(timeout: 5))
        assertVisibleDisclaimer(in: app)
        app.buttons["Done"].tap()

        app.terminate()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal"]
        app.launch()
        XCTAssertTrue(app.buttons["saveMeal"].waitForExistence(timeout: 10))
        app.buttons["saveMeal"].tap()
        app.tabBars.buttons["History"].tap()
        let saved = app.staticTexts["Rice, Unidentified sauce"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        assertVisibleDisclaimer(in: app)
        XCTAssertTrue(app.buttons["deleteSavedMeal"].waitForExistence(timeout: 5))
    }

    @MainActor func testAccessibilityAuditMainFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history"]
        app.launch()
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        try audit(app)
        app.buttons["aboutPrivacy"].tap()
        XCTAssertTrue(app.staticTexts["Not a medical device"].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons["Done"].tap()

        app.terminate()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal"]
        app.launch()
        XCTAssertTrue(app.buttons["saveMeal"].waitForExistence(timeout: 10))
        let preparation = app.staticTexts["Cooked; example data"]
        reveal(preparation, in: app)
        try audit(app)
        let rice = app.buttons["editFood-Rice"]
        XCTAssertTrue(rice.waitForExistence(timeout: 5))
        tapVisible(rice, in: app)
        XCTAssertTrue(app.buttons["Apply"].waitForExistence(timeout: 5))
        try audit(app)
        app.buttons["Cancel"].tap()
        app.buttons["saveMeal"].tap()
        app.tabBars.buttons["History"].tap()
        let saved = app.staticTexts["Rice, Unidentified sauce"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        try audit(app)
        saved.tap()
        XCTAssertTrue(app.buttons["deleteSavedMeal"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["Cooked; example data"], in: app)
        try audit(app)
    }

    @MainActor func testDynamicTypeReviewEditSaveAndHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-history", "--example-meal", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let disclaimer = visibleDisclaimer(in: app)
        scrollUntilOnScreen(disclaimer, in: app)
        assertHorizontallyInside(disclaimer, of: app)
        assertIntersectsWindow(disclaimer, of: app)
        let save = app.buttons["saveMeal"]
        reveal(save, in: app)
        XCTAssertTrue(save.isHittable)
        assertHorizontallyInside(save, of: app)
        let rice = app.buttons["editFood-Rice"]
        XCTAssertTrue(rice.waitForExistence(timeout: 5))
        tapVisible(rice, in: app)
        let grams = app.textFields["portionGrams"]
        scrollUntilExists(grams, in: app)
        XCTAssertTrue(grams.exists || app.textFields["Portion in grams"].exists)
        let half = app.buttons["Half"]
        scrollUntilExists(half, in: app)
        XCTAssertTrue(half.exists)
        let doubled = app.buttons["Double"]
        scrollUntilExists(doubled, in: app)
        XCTAssertTrue(doubled.exists)
        let apply = app.buttons["Apply"]
        reveal(apply, in: app)
        XCTAssertTrue(apply.isHittable)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Apply"].waitForNonExistence(timeout: 5))
        reveal(save, in: app)
        save.tap()
        app.tabBars.buttons["History"].tap()
        let title = app.staticTexts["Rice, Unidentified sauce"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        tapVisible(title, in: app)
        XCTAssertTrue(visibleDisclaimer(in: app).exists)
        let delete = app.buttons["deleteSavedMeal"]
        reveal(delete, in: app)
        XCTAssertTrue(delete.isHittable)
    }

    /// Decorative plate glyphs stay in the interface and are hidden from VoiceOver.
    /// Their multicolor pixels cannot meet a text-contrast ratio, so only those issues are ignored.
    /// Hidden decorations are still drawn, and the audit often reports them with no accessibility element.
    @MainActor private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            let label = issue.element?.label ?? ""
            let identifier = issue.element?.identifier ?? ""
            let type = issue.auditType
            let visualOnly = type.contains(.contrast) || type.contains(.textClipped) || type.contains(.dynamicType)
            if identifier == "decorativeGlyph" { return true }
            let decorativeLabel = !label.isEmpty && label.rangeOfCharacter(from: .letters) == nil
            if decorativeLabel && visualOnly { return true }
            if issue.element == nil && visualOnly { return true }
            // Form text fields report mixed font support even when the field uses a text style.
            if type.contains(.dynamicType), issue.element?.elementType == .textField {
                return true
            }
            return false
        }
    }

    @MainActor private func assertVisibleDisclaimer(in app: XCUIApplication) {
        let element = visibleDisclaimer(in: app)
        XCTAssertTrue(element.label.localizedCaseInsensitiveContains("not a medical device"))
        XCTAssertTrue(element.label.contains("estimates only"))
        XCTAssertTrue(element.label.contains("not medical or dietary advice"))
        XCTAssertTrue(element.label.contains("Consult a qualified professional"))
    }

    @MainActor private func visibleDisclaimer(in app: XCUIApplication) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(identifier: "medicalDisclaimer")
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10))
        for index in 0..<query.count {
            let candidate = query.element(boundBy: index)
            if candidate.isHittable { return candidate }
        }
        return query.element(boundBy: 0)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 16 {
            scrollContent(in: app)
            attempts += 1
        }
    }

    @MainActor private func scrollUntilOnScreen(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while attempts < 12 && !intersectsWindow(element, of: app) {
            scrollContent(in: app)
            attempts += 1
        }
    }

    @MainActor private func intersectsWindow(_ element: XCUIElement, of app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        guard !frame.isEmpty else { return false }
        return frame.minY < window.maxY && frame.maxY > window.minY
    }

    @MainActor private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.exists && attempts < 6 {
            scrollContent(in: app)
            attempts += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 2))
    }

    /// Scroll the frontmost scroller. A coordinate drag stays above the save bar when no scroller is hittable.
    @MainActor private func scrollContent(in app: XCUIApplication) {
        for query in [app.scrollViews, app.collectionViews, app.tables] {
            let matches = query.allElementsBoundByIndex
            if let front = matches.last(where: { $0.isHittable && $0.frame.height > 120 }) {
                front.swipeUp()
                return
            }
        }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.16))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    @MainActor private func tapVisible(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        reveal(element, in: app)
        element.tap()
    }

    @MainActor private func assertHorizontallyInside(_ element: XCUIElement, of app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1)
    }

    @MainActor private func assertIntersectsWindow(_ element: XCUIElement, of app: XCUIApplication) {
        XCTAssertTrue(intersectsWindow(element, of: app))
    }

}
