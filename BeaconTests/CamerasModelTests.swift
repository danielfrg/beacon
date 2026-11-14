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

    func testUpdateReplacesCamera() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"cameras":{"a":{"enabled":true}}}"#.utf8)) }
        let m = model()
        await m.load(baseURL: base, session: StubURLProtocol.session())
        var changed = m.cameras[0]
        changed.detectEnabled = true
        m.update(changed)
        XCTAssertTrue(m.cameras[0].detectEnabled)
    }

    private let cameraJSON = Data(#"{"cameras":{"a":{"enabled":true},"b":{"enabled":true}}}"#.utf8)

    func testRefreshFailureKeepsCamerasAndReportsError() async {
        StubURLProtocol.handler = { [cameraJSON] _ in (200, cameraJSON) }
        let m = model()
        await m.load(baseURL: base, session: StubURLProtocol.session())
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertEqual(m.visible.count, 2, "keeps showing the last good list")
        XCTAssertEqual(m.state, .loaded)
        XCTAssertNotNil(m.refreshError)
    }

    func testSuccessfulRefreshClearsError() async {
        let m = model()
        StubURLProtocol.handler = { [cameraJSON] _ in (200, cameraJSON) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        StubURLProtocol.handler = { _ in (500, Data()) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertNotNil(m.refreshError)
        StubURLProtocol.handler = { [cameraJSON] _ in (200, cameraJSON) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertNil(m.refreshError)
    }

    func testCancelledLoadLeavesStateAlone() async {
        let m = model()
        StubURLProtocol.handler = { [cameraJSON] _ in (200, cameraJSON) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        StubURLProtocol.handler = { _ in throw URLError(.cancelled) }
        await m.load(baseURL: base, session: StubURLProtocol.session())
        XCTAssertEqual(m.state, .loaded)
        XCTAssertNil(m.refreshError)
        XCTAssertEqual(m.visible.count, 2)
    }

    func testStaleLoadDoesNotOverwriteNewerServer() async throws {
        StubURLProtocol.delayForHost = ["old.example.com": 0.3]
        defer { StubURLProtocol.delayForHost = [:] }
        StubURLProtocol.handler = { request in
            let name = request.url?.host == "old.example.com" ? "old_cam" : "new_cam"
            return (200, Data(#"{"cameras":{"\#(name)":{"enabled":true}}}"#.utf8))
        }
        let m = model()
        let slow = Task { await m.load(baseURL: URL(string: "http://old.example.com:5000")!, session: StubURLProtocol.session()) }
        try await Task.sleep(nanoseconds: 50_000_000) // the old request is in flight
        await m.load(baseURL: URL(string: "http://new.example.com:5000")!, session: StubURLProtocol.session())
        await slow.value
        XCTAssertEqual(m.cameras.map(\.name), ["new_cam"], "the older, slower load must not win")
    }
}
