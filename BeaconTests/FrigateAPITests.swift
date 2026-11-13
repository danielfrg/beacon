import XCTest
@testable import Beacon

final class FrigateAPITests: XCTestCase {
    private let base = URL(string: "http://example.com:5000")!

    private func camera(_ name: String, stream: String? = nil) -> Camera {
        Camera(name: name, enabled: true, detectEnabled: true, motionEnabled: true,
               recordEnabled: true, snapshotsEnabled: true, width: nil, height: nil, fps: nil,
               goStream: stream ?? name)
    }

    // MARK: normalize

    func testNormalizeAddsSchemeAndTrimsSlash() {
        XCTAssertEqual(FrigateAPI.normalize("192.0.2.10:5000/")?.absoluteString, "http://192.0.2.10:5000")
    }

    func testNormalizeTrimsSpacesAndKeepsHostWithoutForcingPort() {
        XCTAssertEqual(FrigateAPI.normalize("  example.com ")?.absoluteString, "http://example.com")
    }

    func testNormalizeKeepsExplicitSchemeAndRejectsEmpty() {
        XCTAssertEqual(FrigateAPI.normalize("https://example.com/")?.absoluteString, "https://example.com")
        XCTAssertNil(FrigateAPI.normalize(""))
        XCTAssertNil(FrigateAPI.normalize("   "))
    }

    // MARK: URL building

    func testSnapshotURLEncodesName() {
        let url = FrigateAPI(baseURL: base).snapshotURL(for: camera("back yard"), height: 240)
        XCTAssertEqual(url.absoluteString, "http://example.com:5000/api/back%20yard/latest.jpg?h=240")
    }

    func testSignalingURLUsesWsAndStream() {
        let api = FrigateAPI(baseURL: base)
        XCTAssertEqual(api.signalingURL(for: camera("front_door")).absoluteString,
                       "ws://example.com:5000/live/webrtc/api/ws?src=front_door")
        let secure = FrigateAPI(baseURL: URL(string: "https://example.com")!)
        XCTAssertEqual(secure.signalingURL(for: camera("a b", stream: "a b")).absoluteString,
                       "wss://example.com/live/webrtc/api/ws?src=a%20b")
    }

    // MARK: network

    func testFetchCamerasDecodes() async throws {
        let json = #"{"cameras":{"front_door":{"enabled":true}}}"#
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let cameras = try await FrigateAPI(baseURL: base, session: StubURLProtocol.session()).fetchCameras()
        XCTAssertEqual(cameras.map(\.name), ["front_door"])
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/config")
    }

    func testSetFeatureSendsPutBody() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"success":true}"#.utf8)) }
        let api = FrigateAPI(baseURL: base, session: StubURLProtocol.session())
        try await api.setFeature("detect", on: false, camera: camera("front_door"))
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "PUT")
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/camera/front_door/set/detect")
        let body = try XCTUnwrap(StubURLProtocol.lastBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["value": "OFF"])
    }

    func testNon200ThrowsBadStatus() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        let api = FrigateAPI(baseURL: base, session: StubURLProtocol.session())
        do {
            _ = try await api.fetchCameras()
            XCTFail("expected throw")
        } catch let error as FrigateError {
            XCTAssertEqual(error, .badStatus(500))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testTransportFailureThrowsUnreachable() async {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let api = FrigateAPI(baseURL: base, session: StubURLProtocol.session())
        do {
            _ = try await api.fetchCameras()
            XCTFail("expected throw")
        } catch let error as FrigateError {
            XCTAssertEqual(error, .unreachable)
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}

final class FrigateAPISnapshotTests: XCTestCase {
    func testSnapshotDataReturnsBodyAndBypassesCache() async throws {
        StubURLProtocol.handler = { _ in (200, Data([1, 2, 3])) }
        let camera = Camera(name: "front_door", enabled: true, detectEnabled: false, motionEnabled: false,
                            recordEnabled: false, snapshotsEnabled: false, width: nil, height: nil, fps: nil,
                            goStream: "front_door")
        let api = FrigateAPI(baseURL: URL(string: "http://example.com:5000")!, session: StubURLProtocol.session())
        let data = try await api.snapshotData(for: camera, height: 360)
        XCTAssertEqual(data, Data([1, 2, 3]))
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.query, "h=360")
        XCTAssertEqual(StubURLProtocol.lastRequest?.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}

final class FrigateAPIErrorTests: XCTestCase {
    func testATSBlockIsReportedDistinctly() async {
        StubURLProtocol.handler = { _ in throw URLError(.appTransportSecurityRequiresSecureConnection) }
        let api = FrigateAPI(baseURL: URL(string: "http://nvr.example.com:5000")!, session: StubURLProtocol.session())
        do {
            _ = try await api.fetchCameras()
            XCTFail("expected throw")
        } catch let error as FrigateError {
            XCTAssertEqual(error, .insecureConnectionBlocked)
            XCTAssertTrue(FrigateError.userMessage(for: error).contains("https"))
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}
