import XCTest
import WebRTC
@testable import Beacon

final class WebRTCConnectorTests: XCTestCase {
    /// Callbacks from a peer that isn't the connector's current one (e.g. left over from before a
    /// retry) must not reach the live view.
    func testCallbacksFromAForeignPeerAreIgnored() async throws {
        let factory = RTCPeerConnectionFactory()
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        let stray = try XCTUnwrap(factory.peerConnection(
            with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: nil))
        let transceiver = try XCTUnwrap(stray.addTransceiver(of: .video))

        let connector = WebRTCConnector(signalingURL: URL(string: "ws://example.com:5000/live/webrtc/api/ws?src=x")!)
        var delivered = false
        connector.onVideoTrack = { _ in delivered = true }
        connector.peerConnection(stray, didStartReceivingOn: transceiver)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(delivered)
    }
}
