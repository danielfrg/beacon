import Foundation
import Observation

/// Loads the camera list from the server and applies the user's order/visibility preferences.
@MainActor
@Observable
final class CamerasModel {
    enum State: Equatable {
        case idle, noServer, loading, loaded
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var cameras: [Camera] = []
    private(set) var api: FrigateAPI?
    private var preferences: CameraPreferences?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var visible: [Camera] { preferences?.arranged(cameras) ?? [] }
    var allArranged: [(camera: Camera, hidden: Bool)] { preferences?.allArranged(cameras) ?? [] }

    /// Set when a refresh fails while an earlier list is still showing.
    private(set) var refreshError: String?
    private var loadToken = 0

    func load(baseURL: URL?, session: URLSession = .shared) async {
        loadToken += 1
        let token = loadToken
        guard let baseURL else {
            api = nil; cameras = []; preferences = nil; refreshError = nil
            state = .noServer
            return
        }
        if api?.baseURL != baseURL { cameras = []; refreshError = nil }
        let api = FrigateAPI(baseURL: baseURL, session: session)
        self.api = api
        preferences = CameraPreferences(defaults: defaults, server: baseURL)
        if cameras.isEmpty { state = .loading }
        do {
            let fetched = try await api.fetchCameras()
            guard token == loadToken else { return } // a newer load took over
            cameras = fetched
            refreshError = nil
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard token == loadToken else { return }
            let message = FrigateError.userMessage(for: error)
            if cameras.isEmpty {
                state = .failed(message)
            } else {
                refreshError = message // keep showing the last good list
            }
        }
    }

    func update(_ camera: Camera) {
        if let index = cameras.firstIndex(where: { $0.name == camera.name }) { cameras[index] = camera }
    }

    func move(from source: IndexSet, to destination: Int) {
        preferences?.move(from: source, to: destination, in: cameras)
    }

    func setHidden(_ name: String, _ hidden: Bool) {
        preferences?.setHidden(name, hidden)
    }
}
