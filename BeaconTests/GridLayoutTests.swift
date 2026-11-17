import XCTest
@testable import Beacon

final class GridLayoutTests: XCTestCase {
    func testCompactWidthIsOneColumn() {
        XCTAssertEqual(GridLayout(isRegular: false, width: 400).columns, 1)
        XCTAssertEqual(GridLayout(isRegular: false, width: 400).spacing, 16)
        XCTAssertEqual(GridLayout(isRegular: false, width: 900).columns, 1) // iPhone landscape
    }

    func testRegularNarrowIsTwoColumns() {
        XCTAssertEqual(GridLayout(isRegular: true, width: 744).columns, 2)
        XCTAssertEqual(GridLayout(isRegular: true, width: 744).spacing, 24)
        XCTAssertEqual(GridLayout(isRegular: true, width: 999).columns, 2)
    }

    func testRegularWideIsThreeColumns() {
        XCTAssertEqual(GridLayout(isRegular: true, width: 1000).columns, 3)
        XCTAssertEqual(GridLayout(isRegular: true, width: 1376).columns, 3)
    }
}
