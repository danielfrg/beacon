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

    func testCameraDetailsShowsToggles() {
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 10))
        card("front_door").press(forDuration: 1)
        app.buttons["Details"].tap()
        XCTAssertTrue(app.switches["Detect"].waitForExistence(timeout: 5))
        snap("details")
        // The switch element spans the whole row; tap where the control is.
        app.switches["Detect"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let detect = app.switches["Detect"]
        let off = NSPredicate(format: "value == '0'")
        expectation(for: off, evaluatedWith: detect)
        waitForExpectations(timeout: 5)
        snap("details-toggled")
    }

    func testLiveViewFallsBackToSnapshotsWhenWebRTCUnavailable() {
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 10))
        card("front_door").tap()
        let banner = app.staticTexts["Live video unavailable"]
        _ = banner.waitForExistence(timeout: 15)
        snap("live-state")
        if !banner.exists { print("UI TREE:\n" + app.debugDescription) }
        XCTAssertTrue(banner.exists)
        XCTAssertTrue(app.buttons["Try Again"].exists)
        snap("live-fallback")
        app.buttons["Close"].tap()
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 5))
    }

    func testSwipeBackFromLiveViewReturnsToList() {
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 10))
        card("front_door").tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 5), "edge swipe should go back to the list")
    }

    func testSettingsKeepsUnsavedAddressWhenReturningFromManageCameras() {
        XCTAssertTrue(card("front_door").waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("x")
        let typed = field.value as? String ?? ""
        XCTAssertTrue(typed.hasSuffix("x"))
        app.buttons["Manage Cameras"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.textFields.firstMatch.value as? String, typed, "unsaved text must survive")
    }
}
