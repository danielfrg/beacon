import Foundation

enum FrigateError: Error, Equatable {
    case badStatus(Int)
    case unreachable
    case invalidResponse
    /// iOS App Transport Security refused a plain-HTTP connection (e.g. to a dotted hostname).
    case insecureConnectionBlocked
}

extension FrigateError {
    /// Plain-language description for showing to the user.
    static func userMessage(for error: Error) -> String {
        switch error as? FrigateError {
        case .unreachable: "Can't reach the server. Check the address and that you're on the same network."
        case .insecureConnectionBlocked:
            "iOS blocked this plain-HTTP address. Use an IP address or a .local name, or an https:// address."
        case .badStatus(let code): "The server answered with an error (\(code))."
        default: "The server's response couldn't be read. Is this a Frigate server?"
        }
    }
}

struct FrigateAPI {
    /// Seconds before a request gives up, so a wrong address fails fast instead of spinning for a minute.
    static let requestTimeout: TimeInterval = 10

    let baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Turns user input like " 192.0.2.10:5000/ " into `http://192.0.2.10:5000`.
    /// Keeps a path (reverse-proxy subpath) but drops any query or fragment, and lowercases the scheme.
    static func normalize(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var parts = URLComponents(string: text), let host = parts.host, !host.isEmpty else { return nil }
        parts.scheme = parts.scheme?.lowercased()
        parts.query = nil
        parts.fragment = nil
        var path = parts.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        parts.percentEncodedPath = path
        return parts.url
    }

    func snapshotURL(for camera: Camera, height: Int) -> URL {
        url(["api", camera.name, "latest.jpg"], query: [("h", String(height))])
    }

    func signalingURL(for camera: Camera) -> URL {
        var parts = URLComponents(url: url(["live", "webrtc", "api", "ws"], query: [("src", camera.goStream)]),
                                  resolvingAgainstBaseURL: false)!
        parts.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        return parts.url!
    }

    func fetchCameras() async throws -> [Camera] {
        let data = try await send(URLRequest(url: url(["api", "config"])))
        do {
            return try Camera.decodeCameras(from: data)
        } catch {
            throw FrigateError.invalidResponse
        }
    }

    /// Raw image bytes of the latest frame. Always bypasses the URL cache so tiles really refresh.
    func snapshotData(for camera: Camera, height: Int) async throws -> Data {
        var request = URLRequest(url: snapshotURL(for: camera, height: height))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try await send(request)
    }

    func setFeature(_ feature: String, on: Bool, camera: Camera) async throws {
        var request = URLRequest(url: url(["api", "camera", camera.name, "set", feature]))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["value": on ? "ON" : "OFF"])
        _ = try await send(request)
    }

    // MARK: private

    private static let segmentAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "/?#")
        return set
    }()

    private static let queryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+#")
        return set
    }()

    /// Appends encoded path segments (each one a single segment, so a "/" in a name can't split it)
    /// to the base URL's own path, then the encoded query.
    private func url(_ segments: [String], query: [(String, String)] = []) -> URL {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var base = parts.percentEncodedPath
        while base.hasSuffix("/") { base.removeLast() }
        let encoded = segments.map { $0.addingPercentEncoding(withAllowedCharacters: Self.segmentAllowed) ?? $0 }
        parts.percentEncodedPath = base + "/" + encoded.joined(separator: "/")
        parts.percentEncodedQuery = query.isEmpty ? nil : query
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: Self.queryValueAllowed) ?? $0.1)" }
            .joined(separator: "&")
        return parts.url!
    }

    private func send(_ original: URLRequest) async throws -> Data {
        var request = original
        request.timeoutInterval = Self.requestTimeout
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError() // we were cancelled, the server wasn't unreachable
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            throw FrigateError.insecureConnectionBlocked
        } catch {
            throw FrigateError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw FrigateError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FrigateError.badStatus(http.statusCode) }
        return data
    }
}
