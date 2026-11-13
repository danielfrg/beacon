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
    let baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Turns user input like " 192.0.2.10:5000/ " into `http://192.0.2.10:5000`.
    static func normalize(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    func snapshotURL(for camera: Camera, height: Int) -> URL {
        var parts = components(path: "/api/\(camera.name)/latest.jpg")
        parts.queryItems = [URLQueryItem(name: "h", value: String(height))]
        return parts.url!
    }

    func signalingURL(for camera: Camera) -> URL {
        var parts = components(path: "/live/webrtc/api/ws")
        parts.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        parts.queryItems = [URLQueryItem(name: "src", value: camera.goStream)]
        return parts.url!
    }

    func fetchCameras() async throws -> [Camera] {
        let data = try await send(URLRequest(url: components(path: "/api/config").url!))
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
        var request = URLRequest(url: components(path: "/api/camera/\(camera.name)/set/\(feature)").url!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["value": on ? "ON" : "OFF"])
        _ = try await send(request)
    }

    // MARK: private

    /// Builds components with the camera-name-safe percent-encoded path appended to the base.
    private func components(path: String) -> URLComponents {
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#"))
        parts.percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        return parts
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
