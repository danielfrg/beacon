import XCTest
@testable import Beacon

private final class Gate: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var didEnter = false
}

@MainActor
final class CameraDetailModelTests: XCTestCase {
    private let base = URL(string: "http://example.com:5000")!
    private let camera = Camera(name: "front_door", enabled: true, detectEnabled: true, motionEnabled: true,
                                recordEnabled: false, snapshotsEnabled: true, width: 1280, height: 720, fps: 5,
                                goStream: "front_door")

    private func configJSON(detect: Bool, record: Bool) -> Data {
        Data(#"{"cameras":{"front_door":{"enabled":true,"detect":{"enabled":\#(detect)},"record":{"enabled":\#(record)}}}}"#.utf8)
    }

    private func makeModel(onChange: @escaping (Camera) -> Void = { _ in }) -> CameraDetailModel {
        CameraDetailModel(camera: camera,
                          api: FrigateAPI(baseURL: base, session: StubURLProtocol.session()),
                          onChange: onChange)
    }

    func testToggleOptimisticThenConfirmed() async throws {
        let gate = Gate()
        StubURLProtocol.handler = { [self] request in
            if request.httpMethod == "PUT" {
                gate.didEnter = true
                gate.entered.signal()
                gate.release.wait()
                return (200, Data(#"{"success":true}"#.utf8))
            }
            return (200, configJSON(detect: false, record: false))
        }
        let model = makeModel()
        let task = Task { await model.toggle(.detect, to: false) }
        await Task.detached { gate.entered.wait() }.value
        XCTAssertFalse(model.camera.detectEnabled, "flips immediately, before the server answers")
        XCTAssertTrue(model.busy.contains(.detect))
        gate.release.signal()
        await task.value
        XCTAssertFalse(model.camera.detectEnabled)
        XCTAssertTrue(model.busy.isEmpty)
        XCTAssertNil(model.error)
    }

    func testToggleFailureRevertsAndSetsError() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        let model = makeModel()
        await model.toggle(.detect, to: false)
        XCTAssertTrue(model.camera.detectEnabled, "reverted")
        XCTAssertNotNil(model.error)
    }

    func testRefreshesFromServerAfterSuccess() async {
        var reported: Camera?
        StubURLProtocol.handler = { [self] request in
            request.httpMethod == "PUT" ? (200, Data()) : (200, configJSON(detect: false, record: true))
        }
        let model = makeModel { reported = $0 }
        await model.toggle(.snapshots, to: false)
        XCTAssertTrue(model.camera.recordEnabled, "server truth wins over local guess")
        XCTAssertEqual(reported?.recordEnabled, true)
    }

    func testFeatureMapping() {
        XCTAssertEqual(CameraDetailModel.Feature.allCases.map(\.rawValue), ["detect", "motion", "recordings", "snapshots"])
        let model = makeModel()
        XCTAssertTrue(model.isOn(.detect))
        XCTAssertFalse(model.isOn(.recordings))
    }

    func testServerRefusalShowsError() async {
        // Frigate answers 200 but keeps detect on (e.g. a dependent setting refuses the change).
        StubURLProtocol.handler = { [self] request in
            request.httpMethod == "PUT" ? (200, Data(#"{"success":true}"#.utf8)) : (200, configJSON(detect: true, record: false))
        }
        let model = makeModel()
        await model.toggle(.detect, to: false)
        XCTAssertTrue(model.camera.detectEnabled, "shows the server's real state")
        XCTAssertNotNil(model.error, "tells the user the change wasn't applied")
    }

    func testFailedToggleOnlyRevertsItsOwnFeature() async throws {
        StubURLProtocol.delayForPathContaining = ["/set/detect": 0.3]
        defer { StubURLProtocol.delayForPathContaining = [:] }
        StubURLProtocol.handler = { request in
            if request.url?.path.hasSuffix("/set/detect") == true { return (500, Data()) } // slow and failing
            if request.httpMethod == "PUT" { return (200, Data()) }                          // snapshots: fine
            return (500, Data())                                                              // refetch fails, keeps local value
        }
        let model = makeModel()
        let slowFailure = Task { await model.toggle(.detect, to: false) }
        try await Task.sleep(nanoseconds: 60_000_000)
        await model.toggle(.snapshots, to: false)
        await slowFailure.value
        XCTAssertTrue(model.camera.detectEnabled, "the failed toggle reverted")
        XCTAssertFalse(model.camera.snapshotsEnabled, "the successful toggle must not be undone by the other's failure")
    }
}
