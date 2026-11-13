import Foundation
import OSLog
import WebRTC

enum WebRTCConnectorError: LocalizedError {
    case setupFailed
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .setupFailed: "Couldn't start live video."
        case .connectionFailed: "Couldn't establish a live video connection. Is the server's WebRTC port reachable?"
        }
    }
}

/// Receive-only WebRTC session negotiated through Frigate's go2rtc signaling WebSocket.
final class WebRTCConnector: NSObject, LiveConnector, @unchecked Sendable {
    private static let factory = RTCPeerConnectionFactory()
    private static let log = Logger(subsystem: "com.example.Beacon", category: "live")

    /// Called on the main actor when the remote video track arrives.
    var onVideoTrack: (@MainActor (RTCVideoTrack) -> Void)?

    private let signalingURL: URL
    private let lock = NSLock()
    private var peer: RTCPeerConnection?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pending: CheckedContinuation<Void, Error>?
    private var established = false
    /// Bumped by every connect() and disconnect(); lets a stale attempt notice it was superseded.
    private var generation = 0
    private var failureHandler: (@Sendable (String) -> Void)?

    init(signalingURL: URL) {
        self.signalingURL = signalingURL
    }

    func setFailureHandler(_ handler: @escaping @Sendable (String) -> Void) {
        lock.withLock { failureHandler = handler }
    }

    func connect() async throws {
        let attempt = lock.withLock { () -> Int in generation += 1; return generation }
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = []
        config.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let peer = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw WebRTCConnectorError.setupFailed
        }
        let transceiver = RTCRtpTransceiverInit()
        transceiver.direction = .recvOnly
        peer.addTransceiver(of: .video, init: transceiver)

        let socket = URLSession.shared.webSocketTask(with: signalingURL)
        lock.withLock {
            self.peer = peer
            self.socket = socket
            established = false
        }
        socket.resume()
        Self.log.info("signaling socket opened")
        receiveTask = Task { [weak self] in await self?.receiveLoop(socket: socket, peer: peer) }

        let offerConstraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": "true", "OfferToReceiveAudio": "false"],
            optionalConstraints: nil)
        let offer = try await peer.offer(for: offerConstraints)
        try await peer.setLocalDescription(offer)
        try await socket.send(.string(SignalMessage.offer(offer.sdp).encoded()))
        Self.log.info("offer sent")

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    if generation != attempt || Task.isCancelled {
                        continuation.resume(throwing: CancellationError()) // superseded or cancelled meanwhile
                    } else if established {
                        continuation.resume()
                    } else {
                        pending = continuation
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.resolve(.failure(CancellationError()))
        }
    }

    func disconnect() {
        let (peer, socket, task) = lock.withLock { () -> (RTCPeerConnection?, URLSessionWebSocketTask?, Task<Void, Never>?) in
            defer { self.peer = nil; self.socket = nil; self.receiveTask = nil; established = false; generation += 1 }
            return (self.peer, self.socket, self.receiveTask)
        }
        task?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        peer?.close()
        resolve(.failure(CancellationError()))
    }

    // MARK: private

    private func resolve(_ result: Result<Void, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            defer { pending = nil }
            return pending
        }
        continuation?.resume(with: result)
    }

    private func receiveLoop(socket: URLSessionWebSocketTask, peer: RTCPeerConnection) async {
        while !Task.isCancelled {
            guard let message = try? await socket.receive() else { return }
            guard case .string(let text) = message, let signal = SignalMessage.decode(text) else {
                if case .string(let text) = message { Self.log.error("ignored signaling message: \(text.prefix(200), privacy: .public)") }
                continue
            }
            switch signal {
            case .answer(let sdp):
                Self.log.info("answer received")
                try? await peer.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp))
            case .candidate(let value):
                try? await peer.add(RTCIceCandidate(sdp: value, sdpMLineIndex: 0, sdpMid: "0"))
            case .offer:
                break
            }
        }
    }

    private func isCurrent(_ peerConnection: RTCPeerConnection) -> Bool {
        lock.withLock { peer === peerConnection }
    }

    /// Safety net: hand the view the receive-only video track even if the delegate never announced it.
    private func deliverExistingVideoTrack(from peerConnection: RTCPeerConnection) {
        guard let track = peerConnection.transceivers.first(where: { $0.mediaType == .video })?.receiver.track as? RTCVideoTrack
        else {
            Self.log.error("connected but no video track on any transceiver")
            return
        }
        Self.log.info("video track from transceivers")
        let callback = onVideoTrack
        Task { @MainActor in callback?(track) }
    }

    private func sendCandidate(_ candidate: String) {
        let socket = lock.withLock { self.socket }
        socket?.send(.string(SignalMessage.candidate(candidate).encoded())) { _ in }
    }
}

extension WebRTCConnector: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Self.log.info("ice connection state: \(newState.rawValue, privacy: .public)")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard isCurrent(peerConnection) else { return }
        sendCandidate(candidate.sdp)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        guard isCurrent(peerConnection) else { return } // e.g. a closed peer from before a retry
        Self.log.info("connection state: \(newState.rawValue, privacy: .public)")
        switch newState {
        case .connected:
            deliverExistingVideoTrack(from: peerConnection)
            let waiting = lock.withLock { () -> CheckedContinuation<Void, Error>? in
                established = true
                defer { pending = nil }
                return pending
            }
            waiting?.resume()
        case .failed, .closed:
            let (wasEstablished, handler) = lock.withLock { (established, failureHandler) }
            if wasEstablished {
                lock.withLock { established = false }
                handler?("The live connection was lost.")
            } else {
                resolve(.failure(WebRTCConnectorError.connectionFailed))
            }
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        guard isCurrent(peerConnection),
              let track = transceiver.receiver.track as? RTCVideoTrack else { return }
        Self.log.info("video track from delegate")
        let callback = onVideoTrack
        Task { @MainActor in callback?(track) }
    }
}
