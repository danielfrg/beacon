import XCTest
@testable import Beacon

final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let server = URL(string: "http://example.com:5000")!

    override func setUp() {
        defaults = UserDefaults(suiteName: "PreferencesTests-\(UUID().uuidString)")!
    }

    private func cam(_ name: String) -> Camera {
        Camera(name: name, enabled: true, detectEnabled: false, motionEnabled: false,
               recordEnabled: false, snapshotsEnabled: false, width: nil, height: nil, fps: nil, goStream: name)
    }

    private var cameras: [Camera] { ["driveway", "front_door", "garage"].map(cam) }

    func testNewCamerasAppendedVisible() {
        var prefs = CameraPreferences(defaults: defaults, server: server)
        prefs.move(from: IndexSet(integer: 2), to: 0, in: cameras) // garage first
        let withNew = cameras + [cam("backyard")]
        XCTAssertEqual(prefs.arranged(withNew).map(\.name), ["garage", "driveway", "front_door", "backyard"])
    }

    func testRemovedCamerasIgnored() {
        var prefs = CameraPreferences(defaults: defaults, server: server)
        prefs.move(from: IndexSet(integer: 2), to: 0, in: cameras)
        let fewer = [cam("front_door"), cam("garage")]
        XCTAssertEqual(prefs.arranged(fewer).map(\.name), ["garage", "front_door"])
    }

    func testOrderPersistsPerServer() {
        var prefs = CameraPreferences(defaults: defaults, server: server)
        prefs.move(from: IndexSet(integer: 2), to: 0, in: cameras)
        let sameServer = CameraPreferences(defaults: defaults, server: server)
        XCTAssertEqual(sameServer.arranged(cameras).first?.name, "garage")
        let other = CameraPreferences(defaults: defaults, server: URL(string: "http://192.0.2.7:5000")!)
        XCTAssertEqual(other.arranged(cameras).map(\.name), ["driveway", "front_door", "garage"])
    }

    func testHiddenFilteredFromArranged() {
        var prefs = CameraPreferences(defaults: defaults, server: server)
        prefs.setHidden("driveway", true)
        XCTAssertEqual(prefs.arranged(cameras).map(\.name), ["front_door", "garage"])
        let all = prefs.allArranged(cameras)
        XCTAssertEqual(all.map(\.camera.name), ["driveway", "front_door", "garage"])
        XCTAssertEqual(all.map(\.hidden), [true, false, false])
        prefs.setHidden("driveway", false)
        XCTAssertEqual(prefs.arranged(cameras).count, 3)
    }

    func testBaseURLRoundTrips() {
        let settings = ServerSettings(defaults: defaults)
        XCTAssertNil(settings.baseURL)
        settings.baseURL = server
        XCTAssertEqual(ServerSettings(defaults: defaults).baseURL, server)
        settings.baseURL = nil
        XCTAssertNil(ServerSettings(defaults: defaults).baseURL)
    }
}
