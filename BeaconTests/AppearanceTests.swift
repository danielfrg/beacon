import XCTest
import SwiftUI
@testable import Beacon

final class AppearanceTests: XCTestCase {
    func testDarkIsTheDefault() {
        XCTAssertEqual(Appearance.default, .dark)
        XCTAssertEqual(Appearance.default.colorScheme, .dark)
    }

    func testMapping() {
        XCTAssertEqual(Appearance.light.colorScheme, .light)
        XCTAssertNil(Appearance.system.colorScheme, "system follows the device")
    }

    func testUnknownStoredValueFallsBackToDefault() {
        XCTAssertEqual(Appearance(storedValue: "nonsense"), .dark)
        XCTAssertEqual(Appearance(storedValue: "light"), .light)
    }
}
