import Foundation

/// Messages exchanged with go2rtc over Frigate's WebRTC signaling WebSocket.
enum SignalMessage: Equatable {
    case offer(String)
    case answer(String)
    case candidate(String)
    /// go2rtc refusing the request (e.g. unknown stream name).
    case error(String)

    private static let offerType = "webrtc/offer"
    private static let answerType = "webrtc/answer"
    private static let candidateType = "webrtc/candidate"
    private static let errorType = "error"

    func encoded() -> String {
        let (type, value): (String, String) = switch self {
        case .offer(let sdp): (Self.offerType, sdp)
        case .answer(let sdp): (Self.answerType, sdp)
        case .candidate(let candidate): (Self.candidateType, candidate)
        case .error(let message): (Self.errorType, message)
        }
        let data = try! JSONSerialization.data(withJSONObject: ["type": type, "value": value])
        return String(decoding: data, as: UTF8.self)
    }

    /// Returns nil for malformed text and for message types we don't handle.
    static func decode(_ text: String) -> SignalMessage? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let type = object["type"] as? String,
              let value = object["value"] as? String else { return nil }
        switch type {
        case answerType: return .answer(value)
        case candidateType: return .candidate(value)
        case offerType: return .offer(value)
        case errorType: return .error(value)
        default: return nil
        }
    }
}
