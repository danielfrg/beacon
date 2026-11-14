import Foundation

enum ConnectionResult: Equatable {
    case ok(URL, cameraCount: Int)
    case invalid
    case failed(String)
}

/// Normalizes the typed address and confirms a Frigate server answers there.
func checkConnection(_ input: String, session: URLSession = .shared) async -> ConnectionResult {
    if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .invalid }
    guard let url = FrigateAPI.normalize(input) else {
        return .failed("That doesn't look like a valid address. Use something like 192.0.2.10:5000.")
    }
    do {
        let cameras = try await FrigateAPI(baseURL: url, session: session).fetchCameras()
        return .ok(url, cameraCount: cameras.count)
    } catch {
        return .failed(FrigateError.userMessage(for: error))
    }
}
