import XCTest
@testable import Beacon

final class SignalingTests: XCTestCase {
    private func object(_ text: String) throws -> [String: String] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String])
    }

    func testOfferEncodesToWireFormat() throws {
        let json = try object(SignalMessage.offer("v=0\r\no=- 1 2 IN IP4 127.0.0.1").encoded())
        XCTAssertEqual(json, ["type": "webrtc/offer", "value": "v=0\r\no=- 1 2 IN IP4 127.0.0.1"])
    }

    func testCandidateEncodesToWireFormat() throws {
        let json = try object(SignalMessage.candidate("candidate:1 1 udp 1 192.0.2.5 8555 typ host").encoded())
        XCTAssertEqual(json["type"], "webrtc/candidate")
    }

    func testAnswerAndCandidateDecode() {
        XCTAssertEqual(SignalMessage.decode(#"{"type":"webrtc/answer","value":"v=0"}"#), .answer("v=0"))
        XCTAssertEqual(SignalMessage.decode(#"{"type":"webrtc/candidate","value":"candidate:1"}"#), .candidate("candidate:1"))
    }

    func testServerErrorDecodes() {
        XCTAssertEqual(SignalMessage.decode(#"{"type":"error","value":"streams: stream not found"}"#),
                       .error("streams: stream not found"))
    }

    func testUnknownOrMalformedIgnored() {
        XCTAssertNil(SignalMessage.decode(#"{"type":"something/else","value":"nope"}"#))
        XCTAssertNil(SignalMessage.decode("not json"))
        XCTAssertNil(SignalMessage.decode(#"{"type":"webrtc/answer"}"#))
    }
}
