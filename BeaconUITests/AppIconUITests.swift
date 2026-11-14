import XCTest

/// Choosing the home-screen icon in Settings.
final class AppIconUITests: XCTestCase {
    func testPickingAnIconSelectsIt() {
        let app = XCUIApplication()
        app.launchArguments = ["-serverURL", ""]
        app.launch()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 10))
        app.buttons["Open Settings"].tap()

        let automatic = app.buttons["appIcon.automatic"]
        let dark = app.buttons["appIcon.dark"]
        XCTAssertTrue(automatic.waitForExistence(timeout: 5))
        XCTAssertTrue(automatic.isSelected, "the default icon follows the iPhone theme")
        XCTAssertFalse(dark.isSelected)

        dark.tap()
        // iOS confirms an icon change with a system alert.
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }

        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        XCTAssertTrue(dark.isSelected)
        XCTAssertFalse(automatic.isSelected)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)

        // Put the default back so the simulator isn't left with a changed icon.
        automatic.tap()
        if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }
    }
}
