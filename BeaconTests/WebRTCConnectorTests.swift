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

    /// Callbacks are registered on the main thread but read on WebRTC's threads; run under Thread Sanitizer
    /// (`-enableThreadSanitizer YES`) this fails if the property isn't synchronized.
    func testCallbackRegistrationIsThreadSafe() {
        let connector = WebRTCConnector(signalingURL: URL(string: "ws://example.com:5000/live/webrtc/api/ws?src=x")!)
        DispatchQueue.concurrentPerform(iterations: 2000) { i in
            let handler: (@MainActor (RTCVideoTrack) -> Void)?
            if i.isMultiple(of: 2) { handler = { _ in } } else { handler = nil }
            connector.onVideoTrack = handler
            _ = connector.onVideoTrack
            connector.setFailureHandler { _ in }
        }
    }
}
