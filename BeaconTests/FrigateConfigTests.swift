import XCTest
@testable import Beacon

final class FrigateConfigTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "config", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDecodesThreeCameras() throws {
        let cameras = try Camera.decodeCameras(from: fixture())
        XCTAssertEqual(cameras.map(\.name), ["driveway", "front_door", "garage"])
        let front = try XCTUnwrap(cameras.first { $0.name == "front_door" })
        XCTAssertTrue(front.detectEnabled)
        XCTAssertEqual(front.width, 1280)
        XCTAssertEqual(front.fps, 5)
    }

    func testMainStreamPreferred() throws {
        let cameras = try Camera.decodeCameras(from: fixture())
        XCTAssertEqual(cameras.first { $0.name == "front_door" }?.goStream, "front_door")
    }

    func testMissingLiveStreamsFallsBackToCameraName() throws {
        let cameras = try Camera.decodeCameras(from: fixture())
        XCTAssertEqual(cameras.first { $0.name == "garage" }?.goStream, "garage")
    }

    func testDisabledCameraDecodes() throws {
        let cameras = try Camera.decodeCameras(from: fixture())
        let garage = try XCTUnwrap(cameras.first { $0.name == "garage" })
        XCTAssertFalse(garage.enabled)
        XCTAssertNil(garage.width)
    }

    func testMainKeyIsCaseInsensitiveAndAlphabeticalFallback() throws {
        let json = """
        {"cameras":{"a":{"enabled":true,"live":{"streams":{"main":"a_hd","Sub":"a_sub"}}},
                    "b":{"enabled":true,"live":{"streams":{"Zoom":"b_z","Alpha":"b_a"}}}}}
        """.data(using: .utf8)!
        let cameras = try Camera.decodeCameras(from: json)
        XCTAssertEqual(cameras.first { $0.name == "a" }?.goStream, "a_hd")
        XCTAssertEqual(cameras.first { $0.name == "b" }?.goStream, "b_a")
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try Camera.decodeCameras(from: Data("nope".utf8)))
    }
}
