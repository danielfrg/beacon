import XCTest

/// First-run experience: no server configured.
final class EmptyStateUITests: XCTestCase {
    private func launchWithoutServer() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-serverURL", ""] // an empty address means "not configured"
        app.launch()
        return app
    }

    func testNoServerScreenHasNoCamerasTitle() {
        let app = launchWithoutServer()
        XCTAssertTrue(app.staticTexts["Add your Frigate server"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Cameras"].exists, "the main screen has no title")
    }

    func testSettingsPlaceholderShowsExampleAddress() {
        let app = launchWithoutServer()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 10))
        app.buttons["Open Settings"].tap()
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "https://frigate.example.com")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
    }
}
