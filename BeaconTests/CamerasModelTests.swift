import XCTest
@testable import Beacon

@MainActor
final class CamerasModelTests: XCTestCase {
    private let base = URL(string: "http://example.com:5000")!

    private func model() -> CamerasModel {
        CamerasModel(defaults: UserDefaults(suiteName: "CamerasModelTests-\(UUID().uuidString)")!)
    }

    func testNoServerState() async {
        let m = model()
        await m.load(baseURL: nil)
        XCTAssertEqual(m.state, .noServer)
    }

    func testFailureSetsFailedStateNotSpinner() async {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let m = model()
        await m.load(baseURL: base, session: StubURLProtocol.session())
        guard case .failed(let message) = m.state else { return XCTFail("expected failed, got \(m.state)") }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(m.visible.isEmpty)
    }

    func testLoadedAppliesPreferences() async {
        let json = #"{"cameras":{"a":{"enabled":true},"b":{"enabled":true},"c":{}}}"#
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let m = model()
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertEqual(m.state, .loaded)
        XCTAssertEqual(m.visible.map(\.name), ["a", "b", "c"])
        m.setHidden("b", true)
        XCTAssertEqual(m.visible.map(\.name), ["a", "c"])
        m.move(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(m.allArranged.map(\.camera.name), ["c", "a", "b"])
    }

    func testEmptyConfigIsLoadedWithNoCameras() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"cameras":{}}"#.utf8)) }
        let m = model()
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertEqual(m.state, .loaded)
        XCTAssertTrue(m.visible.isEmpty)
    }
}
