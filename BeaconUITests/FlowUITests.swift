import XCTest

/// End-to-end flows against the mock server (`python3 tools/mock-frigate/server.py`).
/// Run with: xcodebuild test -scheme BeaconUI ... (mock must be running on 127.0.0.1:5000).
/// Set TEST_RUNNER_SCREENSHOT_DIR to also save screenshots there.
final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-serverURL", "http://127.0.0.1:5000"]
        app.launch()
    }

    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func snap(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func testHideAndShowCameraViaManageCameras() {
        XCTAssertTrue(card("driveway").waitForExistence(timeout: 10))
        snap("list")
        app.buttons["Settings"].tap()
        app.buttons["Manage Cameras"].tap()
        snap("manage")
        app.buttons["Hide driveway"].tap()
        XCTAssertTrue(app.buttons["Show driveway"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(card("driveway").waitForExistence(timeout: 2))
        snap("list-hidden")

        app.buttons["Settings"].tap()
        app.buttons["Manage Cameras"].tap()
        app.buttons["Show driveway"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(card("driveway").waitForExistence(timeout: 5))
    }
}
