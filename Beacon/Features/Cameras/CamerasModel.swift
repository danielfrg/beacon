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

    func load(baseURL: URL?, session: URLSession = .shared) async {
        guard let baseURL else {
            api = nil; cameras = []; preferences = nil
            state = .noServer
            return
        }
        if api?.baseURL != baseURL { cameras = [] }
        let api = FrigateAPI(baseURL: baseURL, session: session)
        self.api = api
        preferences = CameraPreferences(defaults: defaults, server: baseURL)
        if cameras.isEmpty { state = .loading }
        do {
            cameras = try await api.fetchCameras()
            state = .loaded
        } catch {
            state = .failed(FrigateError.userMessage(for: error))
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
