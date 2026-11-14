import XCTest
@testable import Beacon

final class ConnectionCheckTests: XCTestCase {
    func testValidServerReportsCameraCount() async {
        let json = #"{"cameras":{"a":{},"b":{},"c":{}}}"#
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let result = await checkConnection("192.0.2.10:5000/", session: StubURLProtocol.session())
        XCTAssertEqual(result, .ok(URL(string: "http://192.0.2.10:5000")!, cameraCount: 3))
    }

    func testEmptyInputIsInvalid() async {
        let result = await checkConnection("  ", session: StubURLProtocol.session())
        XCTAssertEqual(result, .invalid)
    }

    func testServerErrorFails() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        let result = await checkConnection("example.com", session: StubURLProtocol.session())
        guard case .failed(let message) = result else { return XCTFail("expected failed, got \(result)") }
        XCTAssertTrue(message.contains("500"))
    }

    func testUnreachableFails() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        let result = await checkConnection("example.com", session: StubURLProtocol.session())
        guard case .failed = result else { return XCTFail("expected failed") }
    }

    func testMalformedAddressSaysSo() async {
        let result = await checkConnection("192.0.2.10 :5000", session: StubURLProtocol.session())
        guard case .failed(let message) = result else { return XCTFail("expected failed, got \(result)") }
        XCTAssertTrue(message.contains("valid address"))
    }
}
