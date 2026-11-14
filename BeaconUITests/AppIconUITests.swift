import XCTest

/// Choosing the home-screen icon in Settings.
final class AppIconUITests: XCTestCase {
    func testPickingAnIconSelectsIt() {
        let app = XCUIApplication()
        app.launchArguments = ["-serverURL", ""]
        app.launch()
        XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 10))
        app.buttons["Open Settings"].tap()

        let sun = app.buttons["Red Sun"]
        let lighthouse = app.buttons["Lighthouse"]
        XCTAssertTrue(sun.waitForExistence(timeout: 5))
        XCTAssertTrue(sun.isSelected, "the default icon starts selected")
        XCTAssertFalse(lighthouse.isSelected)

        lighthouse.tap()
        // iOS confirms an icon change with a system alert.
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }

        XCTAssertTrue(lighthouse.waitForExistence(timeout: 5))
        XCTAssertTrue(lighthouse.isSelected)
        XCTAssertFalse(sun.isSelected)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)

        // Put the default back so the simulator isn't left with a changed icon.
        sun.tap()
        if alert.waitForExistence(timeout: 5) { alert.buttons.firstMatch.tap() }
    }
}
