import XCTest

final class ScreenshotTests: XCTestCase {
    private var output: URL {
        get throws {
            let env = ProcessInfo.processInfo.environment
            let path = env["SCREENSHOT_DIR"] ?? env["TEST_RUNNER_SCREENSHOT_DIR"]
            let enabled = env["CAPTURE_APP_STORE_SCREENSHOTS"] == "1"
            guard enabled || (path?.isEmpty == false) else {
                throw XCTSkip("Set CAPTURE_APP_STORE_SCREENSHOTS=1 to capture App Store screenshots.")
            }
            let url: URL
            if let path, !path.isEmpty {
                url = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                url = URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                    .appendingPathComponent("docs/screenshots", isDirectory: true)
            }
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    @MainActor func testHomeLight() throws {
        let directory = try output
        let app = launch(arguments: ["--ui-testing", "--reset-history", "--marketing-screenshots"])
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Photo analysis unavailable"].exists)
        save(app.screenshot(), as: "01-home-light.png", in: directory)
    }

    @MainActor func testReview() throws {
        let directory = try output
        let app = launch(arguments: ["--ui-testing", "--reset-history", "--marketing-screenshots", "--marketing-review"])
        XCTAssertTrue(app.staticTexts["Let’s take a look."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["editFood-Grilled salmon"].waitForExistence(timeout: 5))
        save(app.screenshot(), as: "02-review.png", in: directory)
    }

    @MainActor func testHistory() throws {
        let directory = try output
        let app = launch(arguments: ["--ui-testing", "--reset-history", "--marketing-screenshots", "--marketing-history"])
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["historyMeal-Grilled salmon, Jasmine rice, Broccoli"].waitForExistence(timeout: 10))
        save(app.screenshot(), as: "03-history.png", in: directory)
    }

    @MainActor func testHomeDark() throws {
        let directory = try output
        let app = launch(arguments: ["--ui-testing", "--reset-history", "--marketing-screenshots", "--marketing-dark"])
        XCTAssertTrue(app.buttons["Take photo"].waitForExistence(timeout: 10))
        save(app.screenshot(), as: "04-home-dark.png", in: directory)
    }

    @MainActor private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor private func save(_ screenshot: XCUIScreenshot, as name: String, in directory: URL) {
        let url = directory.appendingPathComponent(name)
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Could not write \(name): \(error)")
        }
    }
}
